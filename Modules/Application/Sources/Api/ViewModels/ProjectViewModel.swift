import Combine
import Foundation
import Media
import Project
import Settings
import Shorts
import SpeakerAnalysis
import SpeechToText
import Subtitles
import Timeline
import Translation
import VideoRendering

@MainActor
public final class ProjectViewModel: ObservableObject {
    @Published public var project: Project?
    @Published public var autosaveErrorMessage: String?
    @Published public var exportMessage: String?
    @Published public var mp4ExportResult: MP4ExportResult?
    @Published public var isTranscribing = false
    @Published public var isTranslating = false
    @Published public var isExportingMP4 = false
    @Published public var isImportingSubtitles = false
    @Published public var subtitleImportPreview: SubtitleImportPreview?
    @Published public var subtitleImportErrorMessage: String?
    @Published public var selectedSegmentID: UUID? {
        didSet {
            let updatedSelection = selectedSegmentID.map { Set([$0]) } ?? []
            if selectedCueIDs != updatedSelection {
                selectedCueIDs = updatedSelection
            }
            cueSelectionAnchorID = selectedSegmentID
        }
    }
    @Published public private(set) var selectedCueIDs: Set<UUID> = []
    @Published public var currentTimeMs = 0
    @Published public var activeSegmentID: UUID?
    @Published public var editModeSelectedClipID: UUID?
    @Published public var editRangeStartMs: Int?
    @Published public var editRangeEndMs: Int?
    @Published public var isEditPlaybackEnabled = false
    @Published public var shortsSelectedShortID: UUID?
    @Published public var pendingShortStartMs: Int?
    @Published public var shortsSuggestions: [ShortSuggestion] = []
    @Published public var shortsSuggestionMessage: String?
    /// Incremented when another workspace asks the UI to switch to Shorts mode
    /// (e.g. "Create short from cue" in the subtitle editor).
    @Published public var shortsFocusRequest = 0
    @Published public private(set) var waveformPeaks: [Double] = []
    @Published public private(set) var isPreparingProject = false
    @Published public private(set) var projectPreparationProgress = 0.0
    @Published public private(set) var projectPreparationStatus = "Preparing project..."
    @Published public private(set) var videoSourceInfo: VideoSourceInfo?
    @Published public private(set) var canUndo = false
    @Published public private(set) var canRedo = false

    public let availableLanguages = ["English", "Russian", "Spanish", "French", "German", "Italian", "Portuguese", "Chinese", "Japanese", "Korean"]
    public var settings: AppSettings { appState.settings }

    private let appState: AppState
    private let subtitleImportService: any SubtitleImporting
    private let projectFileService: any ProjectFileServicing
    private let editTimelineService: any EditTimelineEditing
    private let subtitleTimelineMappingService = SubtitleTimelineMappingService()
    private let subtitleStructuralEditingPolicy = SubtitleStructuralEditingPolicy()
    private let subtitleImportMergePolicy = SubtitleImportMergePolicy()
    private let shortsEditingPolicy = ShortsEditingPolicy()
    private let mediaMetadataService: any MediaMetadataProviding
    private let waveformService: any WaveformLoading
    private let speechToTextProviderResolver: any SpeechToTextProviderResolving
    private let subtitleScriptGenerator: any SubtitleScriptGenerating
    private let makeFFmpegService: FFmpegServiceBuilder
    private let pickSubtitleFile: SubtitleFilePicker
    private var autosaveTask: Task<Void, Never>?
    private var waveformTask: Task<Void, Never>?
    private var preparedWaveformProjectID: UUID?
    private var videoSourceInfoProjectID: UUID?
    private var undoStack: [ProjectUndoSnapshot] = []
    private var redoStack: [ProjectUndoSnapshot] = []
    private var activeTextEditSegmentID: UUID?
    private var activeTextEditSnapshot: ProjectUndoSnapshot?
    private var interactiveShortEditSnapshot: ProjectUndoSnapshot?
    private var interactiveShortsSubtitleStyleSnapshot: ProjectUndoSnapshot?
    private var cueSelectionAnchorID: UUID?
    private let undoLimit = 200
    private static let diarizationWarningMessage = "Transcription complete. Speaker analysis failed; subtitle timings were not refined."

    public init(
        appState: AppState,
        dependencies: ProjectViewModelDependencies
    ) {
        self.appState = appState
        subtitleImportService = dependencies.subtitleImporter
        projectFileService = dependencies.projectFileService
        editTimelineService = dependencies.editTimelineService
        mediaMetadataService = dependencies.mediaMetadataProvider
        waveformService = dependencies.waveformLoader
        speechToTextProviderResolver = dependencies.speechToTextProviderResolver
        subtitleScriptGenerator = dependencies.subtitleScriptGenerator
        makeFFmpegService = dependencies.makeFFmpegService
        pickSubtitleFile = dependencies.pickSubtitleFile
        project = appState.selectedProject
    }

    deinit {
        autosaveTask?.cancel()
        waveformTask?.cancel()
    }

    public func loadSelectedProject() {
        if project?.id != appState.selectedProject?.id {
            videoSourceInfo = nil
            videoSourceInfoProjectID = nil
            pendingShortStartMs = nil
        }
        project = appState.selectedProject
    }

    public func loadVideoSourceInfo() async {
        guard let project else {
            videoSourceInfo = nil
            videoSourceInfoProjectID = nil
            return
        }

        guard videoSourceInfoProjectID != project.id else {
            return
        }

        let projectID = project.id
        videoSourceInfoProjectID = projectID
        videoSourceInfo = nil

        do {
            let metadata = try await mediaMetadataService.videoMetadata(
                for: project.mediaFile.originalURL
            )
            guard self.project?.id == projectID else {
                return
            }
            videoSourceInfo = VideoSourceInfo(
                width: metadata.width,
                height: metadata.height,
                nominalFrameRate: metadata.nominalFrameRate
            )
        } catch {
            guard self.project?.id == projectID else {
                return
            }
            videoSourceInfo = nil
        }
    }

    public func prepareProjectForEditing() {
        guard let project else {
            waveformTask?.cancel()
            preparedWaveformProjectID = nil
            waveformPeaks = []
            isPreparingProject = false
            projectPreparationProgress = 0
            return
        }

        if preparedWaveformProjectID == project.id, !waveformPeaks.isEmpty {
            isPreparingProject = false
            projectPreparationProgress = 1
            projectPreparationStatus = "Project ready"
            return
        }

        waveformTask?.cancel()
        waveformPeaks = []
        preparedWaveformProjectID = nil
        isPreparingProject = true
        projectPreparationProgress = 0.02
        projectPreparationStatus = "Preparing project..."

        waveformTask = Task { [weak self] in
            guard let self else { return }
            var project = project

            do {
                if project.mediaFile.durationMs == nil {
                    projectPreparationProgress = 0.06
                    projectPreparationStatus = "Reading video duration..."

                    do {
                        if let durationMs = try await mediaMetadataService.durationMs(for: project.mediaFile.originalURL) {
                            guard !Task.isCancelled else { return }
                            project.mediaFile.durationMs = durationMs
                            project.updatedAt = Date()
                            applyProject(project)
                            scheduleAutosave(project)
                        }
                    } catch {
                        projectPreparationStatus = "Preparing waveform..."
                    }
                }

                let waveformAudioURL = temporaryWaveformAudioURL(for: project)
                defer {
                    try? FileManager.default.removeItem(at: waveformAudioURL)
                }
                let peaks = try await waveformService.loadWaveform(
                    for: WaveformRequest(
                        projectID: project.id,
                        mediaURL: project.mediaFile.originalURL,
                        mediaSizeBytes: project.mediaFile.sizeBytes,
                        durationMs: project.mediaFile.durationMs,
                        fallbackContentEndMs: project.subtitles.map(\.endMs).max()
                    ),
                    audioProvider: {
                        try await self.ffmpegService.extractAudio(
                            from: project.mediaFile.originalURL,
                            to: waveformAudioURL
                        )
                    },
                    progressHandler: { progress, status in
                        await MainActor.run {
                            self.projectPreparationProgress = progress
                            self.projectPreparationStatus = status
                        }
                    }
                )

                guard !Task.isCancelled else { return }
                waveformPeaks = peaks
                preparedWaveformProjectID = project.id
                projectPreparationProgress = 1
                projectPreparationStatus = "Project ready"
                isPreparingProject = false
            } catch {
                guard !Task.isCancelled else { return }
                waveformPeaks = []
                preparedWaveformProjectID = project.id
                projectPreparationProgress = 1
                projectPreparationStatus = "Project ready. Waveform unavailable."
                isPreparingProject = false
            }
        }
    }

    public func undo() {
        guard let snapshot = undoStack.popLast(),
              let currentProject = project else {
            refreshUndoState()
            return
        }

        redoStack.append(ProjectUndoSnapshot(
            project: currentProject,
            selectedSegmentID: selectedSegmentID,
            currentTimeMs: currentTimeMs
        ))
        restoreSnapshot(snapshot)
        refreshUndoState()
    }

    public func redo() {
        guard let snapshot = redoStack.popLast(),
              let currentProject = project else {
            refreshUndoState()
            return
        }

        undoStack.append(ProjectUndoSnapshot(
            project: currentProject,
            selectedSegmentID: selectedSegmentID,
            currentTimeMs: currentTimeMs
        ))
        restoreSnapshot(snapshot)
        refreshUndoState()
    }

    public func beginSubtitleTextEdit(id: UUID) {
        guard activeTextEditSegmentID != id else {
            return
        }

        endSubtitleTextEdit()

        guard let project else {
            return
        }

        activeTextEditSegmentID = id
        activeTextEditSnapshot = ProjectUndoSnapshot(
            project: project,
            selectedSegmentID: selectedSegmentID,
            currentTimeMs: currentTimeMs
        )
    }

    public func endSubtitleTextEdit() {
        activeTextEditSegmentID = nil
        activeTextEditSnapshot = nil
    }

    public func updateSubtitle(_ segment: SubtitleSegment) {
        guard var currentProject = project,
              let index = currentProject.subtitles.firstIndex(where: { $0.id == segment.id }) else {
            return
        }

        guard segment.startMs >= 0 else {
            autosaveErrorMessage = "Start time must be greater than or equal to 00:00:00,000."
            return
        }

        guard segment.endMs > segment.startMs else {
            autosaveErrorMessage = "End time must be greater than start time."
            return
        }

        let previousSegment = currentProject.subtitles[index]
        let timingChanged = previousSegment.startMs != segment.startMs || previousSegment.endMs != segment.endMs
        let textOnlyChange = !timingChanged
            && (previousSegment.originalText != segment.originalText
                || previousSegment.translatedText != segment.translatedText
                || previousSegment.speaker != segment.speaker
                || previousSegment.speakerId != segment.speakerId
                || previousSegment.confidence != segment.confidence
                || previousSegment.warnings != segment.warnings)

        var timingAdjustmentMessage: String?

        if timingChanged {
            let timingResult = SubtitleTimingValidator.updateSegmentTimingResult(
                segments: currentProject.subtitles,
                id: segment.id,
                startMs: segment.startMs,
                endMs: segment.endMs,
                durationMs: timelineDurationMs(for: currentProject)
            )
            currentProject.subtitles = timingResult.segments

            if timingResult.adjustment == .adjustedToConstraints {
                timingAdjustmentMessage = "Timing adjusted to keep a minimum \(SubtitleTimingValidator.minimumDurationMs)ms duration and \(SubtitleTimingValidator.minimumGapMs)ms gap between subtitles."
            }
        }

        guard let updatedIndex = currentProject.subtitles.firstIndex(where: { $0.id == segment.id }) else {
            return
        }

        currentProject.subtitles[updatedIndex].originalText = segment.originalText
        currentProject.subtitles[updatedIndex].translatedText = segment.translatedText
        currentProject.subtitles[updatedIndex].speaker = segment.speaker
        currentProject.subtitles[updatedIndex].speakerId = segment.speakerId
        currentProject.subtitles[updatedIndex].confidence = segment.confidence
        currentProject.subtitles[updatedIndex].warnings = segment.warnings
        currentProject.subtitles = SubtitleTimingValidator.reindexed(currentProject.subtitles)
        autosaveErrorMessage = timingAdjustmentMessage

        if textOnlyChange, activeTextEditSegmentID == segment.id {
            pushActiveTextEditUndoSnapshot()
            updateProject(currentProject)
        } else {
            updateProject(currentProject, undoActionName: timingChanged ? "Edit Timing" : "Edit Subtitle")
        }
    }

    public func updateSegmentTiming(id: UUID, startMs: Int, endMs: Int) {
        guard var currentProject = project else {
            return
        }

        currentProject.subtitles = SubtitleTimingValidator.updateSegmentTiming(
            segments: currentProject.subtitles,
            id: id,
            startMs: startMs,
            endMs: endMs,
            durationMs: timelineDurationMs(for: currentProject)
        )
        autosaveErrorMessage = nil
        updateProject(currentProject, undoActionName: "Edit Timing")
    }

    public func moveSegment(id: UUID, deltaMs: Int) {
        guard var currentProject = project else {
            return
        }

        currentProject.subtitles = SubtitleTimingValidator.moveSegment(
            segments: currentProject.subtitles,
            id: id,
            deltaMs: deltaMs,
            durationMs: timelineDurationMs(for: currentProject)
        )
        autosaveErrorMessage = nil
        updateProject(currentProject, undoActionName: "Move Subtitle")
    }

    public func updateSubtitlesFromTimeline(_ subtitles: [SubtitleSegment]) {
        guard var currentProject = project else {
            return
        }

        currentProject.subtitles = SubtitleTimingValidator.reindexed(subtitles)
        autosaveErrorMessage = nil
        updateProject(currentProject, undoActionName: "Edit Timeline")
    }

    public func updateTimelineTranslatedText(segmentID: UUID, text: String) {
        guard var currentProject = project,
              let index = currentProject.subtitles.firstIndex(where: { $0.id == segmentID }),
              currentProject.subtitles[index].translatedText != text else {
            return
        }

        currentProject.subtitles[index].translatedText = text
        autosaveErrorMessage = nil

        if activeTextEditSegmentID == segmentID {
            pushActiveTextEditUndoSnapshot()
            updateProject(currentProject)
        } else {
            updateProject(currentProject, undoActionName: "Edit Subtitle")
        }
    }

    public func updateSpeakerLabel(id: Int, displayName: String) {
        guard var currentProject = project,
              let index = currentProject.speakerLabels.firstIndex(where: { $0.id == id }) else {
            return
        }

        currentProject.speakerLabels[index].displayName = displayName
        updateProject(currentProject, undoActionName: "Rename Speaker")
    }

    public func selectSegment(
        id: UUID?,
        extendingSelection: Bool = false,
        togglingSelection: Bool = false
    ) {
        guard let id else {
            selectedSegmentID = nil
            return
        }

        if extendingSelection,
           let project,
           let anchorID = cueSelectionAnchorID ?? selectedSegmentID,
           let anchorIndex = project.subtitles.firstIndex(where: { $0.id == anchorID }),
           let targetIndex = project.subtitles.firstIndex(where: { $0.id == id }) {
            let lowerBound = min(anchorIndex, targetIndex)
            let upperBound = max(anchorIndex, targetIndex)
            selectedSegmentID = id
            selectedCueIDs = Set(project.subtitles[lowerBound...upperBound].map(\.id))
            cueSelectionAnchorID = anchorID
            return
        }

        if togglingSelection {
            var updatedSelection = selectedCueIDs
            if updatedSelection.contains(id) {
                updatedSelection.remove(id)
            } else {
                updatedSelection.insert(id)
            }

            let primaryID: UUID?
            if updatedSelection.contains(id) {
                primaryID = id
            } else {
                primaryID = project?.subtitles.first(where: { updatedSelection.contains($0.id) })?.id
            }
            selectedSegmentID = primaryID
            selectedCueIDs = updatedSelection
            cueSelectionAnchorID = primaryID
            return
        }

        selectedSegmentID = id
    }

    public func seekTo(ms: Int) {
        let updatedTimeMs = max(0, ms)
        let updatedActiveSegmentID = project.map {
            TimelinePerformance.activeSegmentID(at: updatedTimeMs, in: $0.subtitles)
        } ?? nil

        if currentTimeMs != updatedTimeMs {
            currentTimeMs = updatedTimeMs
        }

        if activeSegmentID != updatedActiveSegmentID {
            activeSegmentID = updatedActiveSegmentID
        }

        if let updatedActiveSegmentID, selectedSegmentID != updatedActiveSegmentID {
            selectedSegmentID = updatedActiveSegmentID
        }
    }

    public func splitSegment(id: UUID) -> UUID? {
        guard var currentProject = project else {
            return nil
        }

        do {
            let result = try subtitleStructuralEditingPolicy.split(
                segments: currentProject.subtitles,
                id: id
            )
            currentProject.subtitles = result.segments
            updateProject(currentProject, undoActionName: "Split Subtitle")
            return result.selectedSegmentID
        } catch SubtitleStructuralEditError.segmentTooShort {
            autosaveErrorMessage = "Segment is too short to split."
            return nil
        } catch {
            return nil
        }
    }

    public func mergeWithNextSegment(id: UUID) -> UUID? {
        guard var currentProject = project else {
            return nil
        }

        do {
            let result = try subtitleStructuralEditingPolicy.mergeWithNext(
                segments: currentProject.subtitles,
                id: id
            )
            currentProject.subtitles = result.segments
            updateProject(currentProject, undoActionName: "Merge Subtitles")
            return result.selectedSegmentID
        } catch {
            autosaveErrorMessage = "No next segment to merge."
            return nil
        }
    }

    public func deleteSegment(id: UUID) -> UUID? {
        guard var currentProject = project else {
            return nil
        }

        do {
            let result = try subtitleStructuralEditingPolicy.delete(
                segments: currentProject.subtitles,
                id: id
            )
            currentProject.subtitles = result.segments
            updateProject(currentProject, undoActionName: "Delete Subtitle")
            return result.selectedSegmentID
        } catch SubtitleStructuralEditError.segmentNotFound {
            return nil
        } catch {
            assertionFailure("Unexpected subtitle delete error: \(error)")
            return nil
        }
    }

    public func addSegmentAfter(id: UUID) -> UUID? {
        guard var currentProject = project else {
            return nil
        }

        do {
            let result = try subtitleStructuralEditingPolicy.addAfter(
                segments: currentProject.subtitles,
                id: id
            )
            currentProject.subtitles = result.segments
            updateProject(currentProject, undoActionName: "Add Subtitle")
            return result.selectedSegmentID
        } catch SubtitleStructuralEditError.segmentNotFound {
            return nil
        } catch {
            assertionFailure("Unexpected subtitle add error: \(error)")
            return nil
        }
    }

    public func updateSourceLanguage(_ language: String) {
        guard var currentProject = project else {
            return
        }

        currentProject.sourceLanguage = language
        updateProject(currentProject, undoActionName: "Change Source Language")
    }

    public func updateTargetLanguage(_ language: String) {
        guard var currentProject = project else {
            return
        }

        currentProject.targetLanguage = language
        updateProject(currentProject, undoActionName: "Change Target Language")
    }

    public func updateVideoExportSettings(_ settings: VideoExportSettings, registerUndo: Bool = true) {
        guard var currentProject = project, currentProject.videoExportSettings != settings else {
            return
        }

        currentProject.videoExportSettings = settings
        updateProject(currentProject, undoActionName: registerUndo ? "Edit Subtitle Style" : nil)
    }

    public func updateSpeakerExportOptions(_ options: SubtitleExportOptions) {
        guard var currentProject = project, currentProject.speakerExportOptions != options else {
            return
        }

        currentProject.speakerExportOptions = options
        updateProject(currentProject, undoActionName: "Edit Export Options")
    }

    public func ensureEditTimeline() {
        guard var currentProject = project else {
            return
        }

        if currentProject.editTimeline?.isEmpty == false {
            return
        }

        guard let durationMs = sourceDurationMs(for: currentProject), durationMs > 0 else {
            exportMessage = EditTimelineError.invalidDuration.errorDescription
            return
        }

        currentProject.editTimeline = editTimelineService.makeInitialTimeline(durationMs: durationMs)
        updateProject(currentProject)
    }

    public func resolvedEditTimeline(for project: Project) -> EditTimeline? {
        if let timeline = project.editTimeline, !timeline.isEmpty {
            return timeline
        }

        guard let durationMs = sourceDurationMs(for: project), durationMs > 0 else {
            return nil
        }

        return editTimelineService.makeInitialTimeline(durationMs: durationMs)
    }

    public func setEditRangeStartFromCurrentTime() {
        editRangeStartMs = currentTimeMs
    }

    public func setEditRangeEndFromCurrentTime() {
        editRangeEndMs = currentTimeMs
    }

    public func clearEditRange() {
        editRangeStartMs = nil
        editRangeEndMs = nil
    }

    public func rippleDeleteSelectedRange() {
        guard var currentProject = project else {
            return
        }

        guard let timeline = resolvedEditTimeline(for: currentProject) else {
            exportMessage = EditTimelineError.invalidDuration.errorDescription
            return
        }

        guard let editRangeStartMs, let editRangeEndMs else {
            exportMessage = "Set In and Out points first."
            return
        }

        let range = VideoCutRange(startMs: editRangeStartMs, endMs: editRangeEndMs).normalized

        do {
            currentProject.editTimeline = try editTimelineService.rippleDeleteRange(
                timeline: timeline,
                range: range
            )
            currentProject.subtitles = subtitleTimelineMappingService.rippleDeleteSubtitles(
                segments: currentProject.subtitles,
                range: range
            )
            currentProject.shorts = subtitleTimelineMappingService.rippleDeleteShorts(
                shorts: currentProject.shorts,
                range: range
            )
            editModeSelectedClipID = nil
            clearEditRange()
            seekTo(ms: min(range.startMs, currentProject.editTimeline?.totalDurationMs ?? 0))
            updateProject(currentProject, undoActionName: "Ripple Delete")
        } catch let error as LocalizedError {
            exportMessage = error.errorDescription ?? "Ripple delete failed."
        } catch {
            exportMessage = "Ripple delete failed."
        }
    }

    public func splitAtCurrentTime() {
        guard var currentProject = project,
              let timeline = resolvedEditTimeline(for: currentProject) else {
            exportMessage = EditTimelineError.invalidDuration.errorDescription
            return
        }

        do {
            currentProject.editTimeline = try editTimelineService.splitAt(
                timeline: timeline,
                timelineMs: currentTimeMs
            )
            editModeSelectedClipID = editTimelineService
                .clip(atTimelineTime: currentTimeMs, in: currentProject.editTimeline ?? timeline)?
                .id
            updateProject(currentProject, undoActionName: "Split Video Clip")
        } catch let error as LocalizedError {
            exportMessage = error.errorDescription ?? "Split failed."
        } catch {
            exportMessage = "Split failed."
        }
    }

    public func deleteSelectedClip() {
        guard var currentProject = project,
              let selectedClipID = editModeSelectedClipID,
              let timeline = resolvedEditTimeline(for: currentProject),
              let selectedClip = timeline.clips.first(where: { $0.id == selectedClipID }) else {
            exportMessage = "Select a clip first."
            return
        }

        let range = VideoCutRange(
            startMs: selectedClip.timelineStartMs,
            endMs: selectedClip.timelineEndMs
        )

        do {
            currentProject.editTimeline = try editTimelineService.deleteClip(
                timeline: timeline,
                clipID: selectedClipID
            )
            currentProject.subtitles = subtitleTimelineMappingService.rippleDeleteSubtitles(
                segments: currentProject.subtitles,
                range: range
            )
            currentProject.shorts = subtitleTimelineMappingService.rippleDeleteShorts(
                shorts: currentProject.shorts,
                range: range
            )
            editModeSelectedClipID = nil
            clearEditRange()
            seekTo(ms: min(range.startMs, currentProject.editTimeline?.totalDurationMs ?? 0))
            updateProject(currentProject, undoActionName: "Delete Video Clip")
        } catch let error as LocalizedError {
            exportMessage = error.errorDescription ?? "Delete clip failed."
        } catch {
            exportMessage = "Delete clip failed."
        }
    }

    public func timelineTimeToSourceTime(_ timelineMs: Int) -> Int? {
        guard let project,
              let timeline = resolvedEditTimeline(for: project) else {
            return nil
        }

        return editTimelineService.sourceTime(forTimelineTime: timelineMs, in: timeline)
    }

    public func editClip(atTimelineTime timelineMs: Int) -> TimelineClip? {
        guard let project,
              let timeline = resolvedEditTimeline(for: project) else {
            return nil
        }

        return editTimelineService.clip(atTimelineTime: timelineMs, in: timeline)
    }

    public func editPlaybackAdvance(sourceTimeMs: Int, currentClipID: UUID?) -> EditTimelinePlaybackAdvance? {
        guard let project, let timeline = resolvedEditTimeline(for: project) else {
            return nil
        }

        return editTimelineService.playbackAdvance(
            sourceTimeMs: sourceTimeMs,
            currentClipID: currentClipID,
            lastKnownTimelineMs: currentTimeMs,
            in: timeline
        )
    }

    public func seekTimeline(to ms: Int) {
        let durationMs = project.map(timelineDurationMs(for:)) ?? 0
        seekTo(ms: min(max(ms, 0), max(durationMs, 0)))
    }

    public func playTimeline() {
        isEditPlaybackEnabled = true
    }

    public func pauseTimeline() {
        isEditPlaybackEnabled = false
    }

    public func transcribe() async {
        guard var currentProject = project, !isTranscribing else {
            return
        }

        isTranscribing = true
        appState.startTranscriptionActivity(projectName: currentProject.displayName)
        defer {
            isTranscribing = false
        }

        autosaveTask?.cancel()
        autosaveTask = nil

        currentProject.status = .extractingAudio
        applyProject(currentProject)

        do {
            try await appState.projectRepository.saveProject(currentProject)

            let audioURL = temporaryAudioURL(for: currentProject)
            // STT and diarization must share this exact edit-timeline audio so
            // every returned timestamp remains in the player's time domain.
            let transcriptionClips = try transcriptionClips(for: currentProject)
            let extractedAudioURL = try await ffmpegService.extractAudio(
                from: currentProject.mediaFile.originalURL,
                to: audioURL,
                clips: transcriptionClips
            )
            appState.updateTranscriptionActivity(statusText: "Transcribing audio...", progress: 0.15)

            currentProject.status = .transcribing
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            try await appState.projectRepository.saveProject(currentProject)

            let appState = appState
            let input = TranscriptionInput(
                audioURL: extractedAudioURL,
                videoURL: currentProject.mediaFile.originalURL,
                sourceLanguage: currentProject.sourceLanguage,
                progressHandler: { progress, status in
                    await appState.updateTranscriptionActivity(statusText: status, progress: progress)
                }
            )
            let provider = try speechToTextProviderResolver.resolve(
                configuration: speechToTextConfiguration(from: appState.settings)
            )
            let result = try await provider.transcribe(input)

            currentProject.subtitles = result.segments
            currentProject.wordTimings = result.words
            if let detectedLanguage = result.detectedLanguage {
                currentProject.sourceLanguage = detectedLanguage
            }
            if transcriptionClips == nil, let durationMs = result.durationMs {
                currentProject.mediaFile.durationMs = durationMs
            }

            let diarizationOutcome = try await performDiarizationAndAlignment(
                for: currentProject,
                audioURL: extractedAudioURL
            )
            currentProject = diarizationOutcome.project
            if let transcriptionDurationMs = transcriptionClips.map({ clips in
                clips.reduce(0) { $0 + $1.durationMs }
            }) {
                currentProject = projectByConstrainingTranscription(
                    currentProject,
                    to: transcriptionDurationMs
                )
            }

            currentProject.status = .ready
            currentProject.updatedAt = Date()
            appState.finishTranscriptionActivity(
                success: true,
                message: transcriptionCompletionMessage(diarizationFailureMessage: diarizationOutcome.failureMessage)
            )

            applyProject(currentProject)
            try await appState.projectRepository.saveProject(currentProject)
        } catch FFmpegServiceError.notFound {
            let message = "FFmpeg is not installed or path is incorrect."
            currentProject.status = .failed(message)
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            appState.finishTranscriptionActivity(success: false, message: message)
            exportMessage = message
            try? await appState.projectRepository.saveProject(currentProject)
        } catch let error as LocalizedError {
            let message = error.errorDescription ?? "Transcription failed."
            currentProject.status = .failed(message)
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            appState.finishTranscriptionActivity(success: false, message: message)
            exportMessage = message
            try? await appState.projectRepository.saveProject(currentProject)
        } catch {
            let message = "Transcription failed."
            currentProject.status = .failed(message)
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            appState.finishTranscriptionActivity(success: false, message: message)
            exportMessage = message
            try? await appState.projectRepository.saveProject(currentProject)
        }
    }

    public func translate() async {
        guard var currentProject = project, !isTranslating else {
            return
        }

        guard !currentProject.subtitles.isEmpty else {
            exportMessage = "No subtitles to translate."
            return
        }

        isTranslating = true
        autosaveTask?.cancel()
        autosaveTask = nil

        currentProject.status = .translating
        applyProject(currentProject)

        do {
            try await appState.projectRepository.saveProject(currentProject)

            let input = SubtitleTranslationInput(
                segments: currentProject.subtitles,
                sourceLanguage: currentProject.sourceLanguage,
                targetLanguage: currentProject.targetLanguage,
                style: .natural
            )
            let result = try await appState.translationService.translateSubtitles(input)

            guard result.segments.count == currentProject.subtitles.count else {
                throw TranslationValidationError.segmentCountMismatch
            }

            currentProject.subtitles = currentProject.subtitles.enumerated().map { index, segment in
                var updatedSegment = segment
                updatedSegment.translatedText = result.segments[index].translatedText
                return updatedSegment
            }
            currentProject.status = .ready
            currentProject.updatedAt = Date()

            applyProject(currentProject)
            try await appState.projectRepository.saveProject(currentProject)
            isTranslating = false
        } catch let error as LocalizedError {
            currentProject.status = .failed(error.errorDescription ?? "Translation failed.")
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            exportMessage = error.errorDescription ?? "Translation failed."
            try? await appState.projectRepository.saveProject(currentProject)
            isTranslating = false
        } catch {
            currentProject.status = .failed("Translation failed.")
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            exportMessage = "Translation failed."
            try? await appState.projectRepository.saveProject(currentProject)
            isTranslating = false
        }
    }


    public func suggestedExportFileName(for kind: SubtitleExportKind) -> String {
        let baseName = project?.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        let safeBaseName = (baseName?.isEmpty == false ? baseName : "subtitles") ?? "subtitles"
        return "\(safeBaseName).\(kind.fileExtension)"
    }

    public func suggestedMP4ExportFileName() -> String {
        let baseName = project?.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        let safeBaseName = (baseName?.isEmpty == false ? baseName : "subtitled-video") ?? "subtitled-video"
        return "\(safeBaseName).mp4"
    }

    public func exportSubtitles(kind: SubtitleExportKind, to destinationURL: URL) async {
        guard let project else {
            exportMessage = "No project selected."
            return
        }

        do {
            try await appState.subtitleExportService.export(
                request: SubtitleExportRequest(
                    segments: project.subtitles,
                    speakerLabels: project.speakerLabels,
                    options: project.speakerExportOptions
                ),
                kind: kind,
                destinationURL: destinationURL
            )
            exportMessage = "Subtitles exported successfully."
        } catch let error as LocalizedError {
            exportMessage = error.errorDescription ?? "Export failed."
        } catch {
            exportMessage = "Export failed."
        }
    }

    public func exportMP4(to destinationURL: URL) async {
        guard var currentProject = project, !isExportingMP4 else {
            exportMessage = project == nil ? "No project selected." : nil
            return
        }

        guard !currentProject.subtitles.isEmpty else {
            exportMessage = "There are no subtitles to export."
            return
        }

        isExportingMP4 = true
        autosaveTask?.cancel()
        autosaveTask = nil

        currentProject.status = .exporting
        currentProject.updatedAt = Date()
        applyProject(currentProject)

        do {
            try await appState.projectRepository.saveProject(currentProject)

            let settings = currentProject.videoExportSettings
            let subtitlesURL = temporaryTranslatedASSURL(for: currentProject)
            try writeASS(for: currentProject, settings: settings, to: subtitlesURL)

            let sourceInfo: VideoSourceInfo?
            do {
                let metadata = try await mediaMetadataService.videoMetadata(
                    for: currentProject.mediaFile.originalURL
                )
                sourceInfo = VideoSourceInfo(
                    width: metadata.width,
                    height: metadata.height,
                    nominalFrameRate: metadata.nominalFrameRate
                )
            } catch {
                sourceInfo = nil
            }

            let outputURL = try await ffmpegService.burnSubtitles(
                videoURL: currentProject.mediaFile.originalURL,
                subtitlesURL: subtitlesURL,
                outputURL: destinationURL,
                settings: settings,
                sourceInfo: sourceInfo
            )

            currentProject.status = .ready
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            try await appState.projectRepository.saveProject(currentProject)

            mp4ExportResult = .success(outputURL.path)
            isExportingMP4 = false
        } catch FFmpegServiceError.notFound {
            let message = "FFmpeg was not found. Install FFmpeg or set the correct path in Settings."
            currentProject.status = .failed(message)
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            mp4ExportResult = .failure(message: message, debugOutput: nil)
            try? await appState.projectRepository.saveProject(currentProject)
            isExportingMP4 = false
        } catch FFmpegServiceError.processFailed(_, _, let standardError) {
            let message = "MP4 export failed."
            currentProject.status = .failed(message)
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            mp4ExportResult = .failure(
                message: message,
                debugOutput: standardError.isEmpty ? "FFmpeg did not return stderr output." : standardError
            )
            try? await appState.projectRepository.saveProject(currentProject)
            isExportingMP4 = false
        } catch let error as LocalizedError {
            let message = error.errorDescription ?? "MP4 export failed."
            currentProject.status = .failed(message)
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            mp4ExportResult = .failure(message: message, debugOutput: nil)
            try? await appState.projectRepository.saveProject(currentProject)
            isExportingMP4 = false
        } catch {
            let message = "MP4 export failed."
            currentProject.status = .failed(message)
            currentProject.updatedAt = Date()
            applyProject(currentProject)
            mp4ExportResult = .failure(message: message, debugOutput: nil)
            try? await appState.projectRepository.saveProject(currentProject)
            isExportingMP4 = false
        }
    }

    public func importSubtitlesFromFile() {
        Task {
            guard let fileURL = await pickSubtitleFile() else { return }
            await previewSubtitleImport(from: fileURL)
        }
    }

    public func previewSubtitleImport(from fileURL: URL) async {
        guard !isImportingSubtitles else {
            return
        }

        isImportingSubtitles = true
        subtitleImportErrorMessage = nil
        defer {
            isImportingSubtitles = false
        }

        do {
            subtitleImportPreview = try await subtitleImportService.importSubtitles(from: fileURL)
        } catch let error as SubtitleImportError {
            subtitleImportErrorMessage = error.errorDescription ?? "Subtitle import failed."
        } catch let error as LocalizedError {
            subtitleImportErrorMessage = error.errorDescription ?? "Subtitle import failed."
        } catch {
            subtitleImportErrorMessage = "Subtitle import failed."
        }
    }

    public func applySubtitleImport(
        _ preview: SubtitleImportPreview,
        mode: SubtitleImportMode,
        destination: SubtitleImportDestination = .original
    ) {
        guard var currentProject = project else {
            subtitleImportErrorMessage = "No project selected."
            return
        }

        currentProject.subtitles = subtitleImportMergePolicy.merge(
            current: currentProject.subtitles,
            imported: preview.segments,
            mode: mode,
            destination: destination
        )

        selectedSegmentID = currentProject.subtitles.first?.id
        autosaveErrorMessage = nil
        subtitleImportPreview = nil
        updateProject(currentProject, undoActionName: "Import Subtitles")
    }

    public func saveProject() async {
        guard let project else {
            exportMessage = "No project selected."
            return
        }

        autosaveTask?.cancel()
        autosaveTask = nil

        do {
            try await appState.projectRepository.saveProject(project)
            autosaveErrorMessage = nil
            exportMessage = "Project saved."
        } catch {
            autosaveErrorMessage = "Project save failed."
        }
    }

    public func exportProjectFile(to fileURL: URL) {
        guard let project else {
            exportMessage = "No project selected."
            return
        }

        do {
            try projectFileService.exportProject(project, to: fileURL)
            exportMessage = "Project saved to:\n\(fileURL.path)"
        } catch {
            exportMessage = "Project file export failed."
        }
    }

    private func performDiarizationAndAlignment(
        for project: Project,
        audioURL: URL
    ) async throws -> (project: Project, failureMessage: String?) {
        do {
            appState.updateTranscriptionActivity(statusText: "Analyzing speakers...", progress: 0.95)
            let speakerSegments = try await appState.speakerDiarizationEngine.diarize(audioURL: audioURL)

            appState.updateTranscriptionActivity(statusText: "Aligning subtitles...", progress: 0.99)
            let words = project.wordTimings.isEmpty
                ? syntheticWordTimings(from: project.subtitles)
                : project.wordTimings

            let alignedSubtitles = try await appState.subtitleAlignmentEngine.align(
                words: words,
                existingCues: project.subtitles.map(subtitleAlignmentCue(from:)),
                speakerSegments: speakerSegments,
                options: SubtitleAlignmentOptions()
            )

            var alignedProject = project
            alignedProject.speakerSegments = speakerSegments
            alignedProject.speakerLabels = speakerLabels(for: speakerSegments, existingLabels: project.speakerLabels)
            alignedProject.subtitles = SubtitleTimingValidator.reindexed(
                alignedSubtitles.map(subtitleSegment(from:))
            )
            return (alignedProject, nil)
        } catch let error as CancellationError {
            throw error
        } catch {
            return (project, diarizationFailureMessage(from: error))
        }
    }

    private func transcriptionClips(for project: Project) throws -> [ExportClipRange]? {
        do {
            return try ExportClipPlanResolver.clips(for: project)
        } catch ExportClipPlanError.emptyPlan {
            throw TranscriptionValidationError.editTimelineEmpty
        }
    }

    private func transcriptionCompletionMessage(diarizationFailureMessage: String?) -> String? {
        guard let diarizationFailureMessage else {
            return nil
        }

        let detail = diarizationFailureMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else {
            return Self.diarizationWarningMessage
        }

        return "\(Self.diarizationWarningMessage) \(detail)"
    }

    private func projectByConstrainingTranscription(
        _ project: Project,
        to durationMs: Int
    ) -> Project {
        let durationSeconds = Double(durationMs) / 1_000
        var constrainedProject = project

        constrainedProject.subtitles = SubtitleTimingValidator.reindexed(
            project.subtitles.compactMap { segment in
                let startMs = max(0, segment.startMs)
                let endMs = min(durationMs, segment.endMs)
                guard startMs < durationMs, endMs > startMs else { return nil }

                var constrainedSegment = segment
                constrainedSegment.startMs = startMs
                constrainedSegment.endMs = endMs
                return constrainedSegment
            }
        )
        constrainedProject.wordTimings = project.wordTimings.compactMap { word in
            let start = max(0, word.start)
            let end = min(durationSeconds, word.end)
            guard start < durationSeconds, end > start else { return nil }

            var constrainedWord = word
            constrainedWord.start = start
            constrainedWord.end = end
            return constrainedWord
        }
        constrainedProject.speakerSegments = project.speakerSegments.compactMap { segment in
            let start = max(0, segment.start)
            let end = min(durationSeconds, segment.end)
            guard start < durationSeconds, end > start else { return nil }

            var constrainedSegment = segment
            constrainedSegment.start = start
            constrainedSegment.end = end
            return constrainedSegment
        }

        return constrainedProject
    }

    private func subtitleAlignmentCue(from segment: SubtitleSegment) -> SubtitleAlignmentCue {
        SubtitleAlignmentCue(
            id: segment.id,
            index: segment.index,
            startMs: segment.startMs,
            endMs: segment.endMs,
            originalText: segment.originalText,
            translatedText: segment.translatedText,
            speakerId: segment.speakerId,
            confidence: segment.confidence,
            warnings: segment.warnings
        )
    }

    private func subtitleSegment(from cue: SubtitleAlignmentCue) -> SubtitleSegment {
        SubtitleSegment(
            id: cue.id,
            index: cue.index,
            startMs: cue.startMs,
            endMs: cue.endMs,
            originalText: cue.originalText,
            translatedText: cue.translatedText,
            speakerId: cue.speakerId,
            confidence: cue.confidence,
            warnings: cue.warnings
        )
    }

    private func speechToTextConfiguration(
        from settings: AppSettings
    ) -> SpeechToTextProviderConfiguration {
        SpeechToTextProviderConfiguration(
            providerName: settings.speechToTextProviderName,
            whisperExecutableURL: fileURL(from: settings.whisperExecutablePath),
            whisperModelURL: fileURL(from: settings.whisperModelPath),
            whisperModelName: settings.whisperModelName,
            whisperVADEnabled: settings.whisperVADEnabled,
            whisperVADModelURL: fileURL(from: settings.whisperVADModelPath)
        )
    }

    private func fileURL(from path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed)
    }

    private func diarizationFailureMessage(from error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? "Speaker analysis failed." : description
    }

    private func syntheticWordTimings(from subtitles: [SubtitleSegment]) -> [WordTiming] {
        subtitles.flatMap { segment in
            let words = segment.originalText
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            guard !words.isEmpty else { return [WordTiming]() }
            let startSec = Double(segment.startMs) / 1000.0
            let endSec = Double(segment.endMs) / 1000.0
            let wordDuration = max(endSec - startSec, 0) / Double(words.count)
            return words.enumerated().map { i, word in
                WordTiming(
                    text: word,
                    start: startSec + Double(i) * wordDuration,
                    end: startSec + Double(i + 1) * wordDuration,
                    confidence: segment.confidence
                )
            }
        }
    }

    private func updateProject(_ project: Project, undoActionName: String? = nil) {
        if let undoActionName, let previousProject = self.project {
            pushUndoSnapshot(
                ProjectUndoSnapshot(
                    project: previousProject,
                    selectedSegmentID: selectedSegmentID,
                    currentTimeMs: currentTimeMs
                ),
                actionName: undoActionName
            )
        }

        var updatedProject = project
        updatedProject.updatedAt = Date()
        applyProject(updatedProject)
        scheduleAutosave(updatedProject)
    }

    private func restoreSnapshot(_ snapshot: ProjectUndoSnapshot) {
        var restoredProject = snapshot.project
        restoredProject.updatedAt = Date()
        selectedSegmentID = snapshot.selectedSegmentID.flatMap { id in
            restoredProject.subtitles.contains(where: { $0.id == id }) ? id : restoredProject.subtitles.first?.id
        }
        currentTimeMs = snapshot.currentTimeMs
        applyProject(restoredProject)
        scheduleAutosave(restoredProject)
    }

    private func pushUndoSnapshot(_ snapshot: ProjectUndoSnapshot, actionName _: String) {
        undoStack.append(snapshot)
        if undoStack.count > undoLimit {
            undoStack.removeFirst(undoStack.count - undoLimit)
        }

        redoStack.removeAll()
        refreshUndoState()
    }

    private func pushActiveTextEditUndoSnapshot() {
        guard let snapshot = activeTextEditSnapshot else {
            return
        }

        pushUndoSnapshot(snapshot, actionName: "Edit Subtitle Text")
        activeTextEditSnapshot = nil
    }

    private func refreshUndoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func applyProject(_ project: Project) {
        self.project = project
        appState.selectedProject = project
        updateRecentProject(project)
    }

    private var ffmpegService: any FFmpegService {
        makeFFmpegService(appState.settings)
    }

    private func temporaryAudioURL(for project: Project) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .appendingPathComponent("audio-\(UUID().uuidString).wav")
    }

    private func temporaryWaveformAudioURL(for project: Project) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .appendingPathComponent("waveform-\(UUID().uuidString).wav")
    }

    private func temporaryTranslatedASSURL(for project: Project) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .appendingPathComponent("subtitles.ass")
    }

    private func writeASS(for project: Project, settings: VideoExportSettings, to subtitlesURL: URL) throws {
        let directoryURL = subtitlesURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let content = try subtitleScriptGenerator.generateASS(
            segments: project.subtitles,
            settings: settings
        )
        try Data(content.utf8).write(to: subtitlesURL, options: .atomic)
    }

    private func updateRecentProject(_ project: Project) {
        guard let index = appState.recentProjects.firstIndex(where: { $0.id == project.id }) else {
            return
        }

        appState.recentProjects[index] = project
    }

    private func speakerLabels(
        for speakerSegments: [SpeakerSegment],
        existingLabels: [SpeakerLabel]
    ) -> [SpeakerLabel] {
        let existingLabelsByID = Dictionary(uniqueKeysWithValues: existingLabels.map { ($0.id, $0.displayName) })
        let speakerIDs = Set(speakerSegments.map(\.speakerId)).sorted()

        return speakerIDs.map { speakerID in
            SpeakerLabel(
                id: speakerID,
                displayName: existingLabelsByID[speakerID] ?? "Speaker \(speakerID + 1)"
            )
        }
    }

    private func scheduleAutosave(_ project: Project) {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
                try Task.checkCancellation()
                try await self?.appState.projectRepository.saveProject(project)
                await MainActor.run {
                    self?.autosaveErrorMessage = nil
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self?.autosaveErrorMessage = "Autosave failed."
                }
            }
        }
    }

    public func timelineDurationMs(for project: Project) -> Int {
        if let timelineDurationMs = project.editTimeline?.totalDurationMs, timelineDurationMs > 0 {
            return timelineDurationMs
        }

        return sourceDurationMs(for: project) ?? 0
    }

    private func sourceDurationMs(for project: Project) -> Int? {
        if let durationMs = project.mediaFile.durationMs, durationMs > 0 {
            return durationMs
        }

        let subtitleDurationMs = project.subtitles.map(\.endMs).max() ?? 0
        return subtitleDurationMs > 0 ? subtitleDurationMs : nil
    }

    private func hasOverlappingSegments(_ segments: [SubtitleSegment]) -> Bool {
        let sortedSegments = segments.sorted { $0.startMs < $1.startMs }

        for index in sortedSegments.indices.dropFirst() {
            if sortedSegments[index].startMs < sortedSegments[index - 1].endMs {
                return true
            }
        }

        return false
    }
}

// MARK: - Shorts

extension ProjectViewModel {
    public var selectedShort: ShortDefinition? {
        guard let shortsSelectedShortID else {
            return nil
        }

        return project?.shorts.first { $0.id == shortsSelectedShortID }
    }

    @discardableResult
    public func addShort(
        startMs: Int,
        endMs: Int,
        title: String? = nil,
        undoActionName: String = "Add Short"
    ) -> UUID? {
        guard var currentProject = project else {
            return nil
        }

        do {
            let result = try shortsEditingPolicy.add(
                shorts: currentProject.shorts,
                title: title ?? defaultShortTitle(for: currentProject),
                startMs: startMs,
                endMs: endMs
            )
            currentProject.shorts = result.shorts
            updateProject(currentProject, undoActionName: undoActionName)
            shortsSelectedShortID = result.editedShortID
            return result.editedShortID
        } catch ShortsEditError.invalidRange {
            return nil
        } catch {
            assertionFailure("Unexpected add short error: \(error)")
            return nil
        }
    }

    public func addShortAtPlayhead() {
        guard let project else {
            return
        }

        let durationMs = timelineDurationMs(for: project)
        let defaultLengthMs = 30_000
        let startMs = min(max(0, currentTimeMs), max(0, durationMs - 1_000))
        let endMs = min(startMs + defaultLengthMs, max(startMs + 1_000, durationMs))
        pendingShortStartMs = nil
        addShort(startMs: startMs, endMs: endMs)
    }

    /// Creates a short spanning all selected cues and asks the UI to switch to
    /// Shorts mode. A normal single-row selection remains a one-cue range.
    public func createShortFromSelectedCues() {
        guard let project else {
            return
        }

        let selectedIDs = selectedCueIDs.isEmpty
            ? selectedSegmentID.map { Set([$0]) } ?? []
            : selectedCueIDs
        let selectedCues = project.subtitles.filter { selectedIDs.contains($0.id) }
        guard let startMs = selectedCues.map(\.startMs).min(),
              let endMs = selectedCues.map(\.endMs).max() else {
            exportMessage = "Select one or more subtitle cues first."
            return
        }

        addShort(
            startMs: startMs,
            endMs: endMs,
            undoActionName: "Create Short from Selection"
        )
        shortsFocusRequest += 1
    }

    public func beginInteractiveShortEdit() {
        guard interactiveShortEditSnapshot == nil, let project else {
            return
        }

        interactiveShortEditSnapshot = ProjectUndoSnapshot(
            project: project,
            selectedSegmentID: selectedSegmentID,
            currentTimeMs: currentTimeMs
        )
    }

    public func endInteractiveShortEdit(undoActionName: String) {
        guard let snapshot = interactiveShortEditSnapshot else {
            return
        }
        interactiveShortEditSnapshot = nil

        guard let project, project != snapshot.project else {
            return
        }

        pushUndoSnapshot(snapshot, actionName: undoActionName)
    }

    public func updateShort(
        id: UUID,
        undoActionName: String? = nil,
        mutate: (inout ShortDefinition) -> Void
    ) {
        guard var currentProject = project else {
            return
        }

        do {
            let result = try shortsEditingPolicy.update(
                shorts: currentProject.shorts,
                id: id,
                mutate: mutate
            )
            guard result.didChange else {
                return
            }
            currentProject.shorts = result.shorts
            updateProject(currentProject, undoActionName: undoActionName)
        } catch ShortsEditError.shortNotFound {
            return
        } catch {
            assertionFailure("Unexpected update short error: \(error)")
        }
    }

    public func updateShortRange(id: UUID, startMs: Int, endMs: Int) {
        guard var currentProject = project else {
            return
        }

        do {
            let result = try shortsEditingPolicy.updateRange(
                shorts: currentProject.shorts,
                id: id,
                startMs: startMs,
                endMs: endMs
            )
            guard result.didChange else {
                return
            }
            currentProject.shorts = result.shorts
            updateProject(currentProject, undoActionName: "Edit Short Range")
        } catch ShortsEditError.invalidRange {
            return
        } catch ShortsEditError.shortNotFound {
            return
        } catch {
            assertionFailure("Unexpected short range error: \(error)")
        }
    }

    public func setSelectedShortStartToPlayhead() {
        guard let short = selectedShort else {
            return
        }
        guard currentTimeMs >= 0, currentTimeMs <= short.endMs - 1_000 else {
            exportMessage = "Move the playhead at least one second before the short end."
            return
        }

        updateShortRange(id: short.id, startMs: currentTimeMs, endMs: short.endMs)
    }

    public func setSelectedShortEndToPlayhead() {
        guard let short = selectedShort else {
            return
        }
        guard currentTimeMs >= short.startMs + 1_000 else {
            exportMessage = "Move the playhead at least one second after the short start."
            return
        }

        updateShortRange(id: short.id, startMs: short.startMs, endMs: currentTimeMs)
    }

    /// In the selected range this edits its start. Outside the selected range
    /// (or without a selection) it marks the start of a new short, completed by
    /// the matching Set End command in the Shorts timeline toolbar.
    public func setShortStartFromPlayhead() {
        if pendingShortStartMs != nil {
            pendingShortStartMs = max(0, currentTimeMs)
            return
        }

        if let short = selectedShort,
           currentTimeMs >= short.startMs,
           currentTimeMs <= short.endMs - 1_000 {
            updateShortRange(id: short.id, startMs: currentTimeMs, endMs: short.endMs)
            return
        }

        pendingShortStartMs = max(0, currentTimeMs)
    }

    public func setShortEndFromPlayhead() {
        if let pendingShortStartMs {
            guard currentTimeMs >= pendingShortStartMs + 1_000 else {
                exportMessage = "Move the playhead at least one second after the new short start."
                return
            }

            self.pendingShortStartMs = nil
            addShort(
                startMs: pendingShortStartMs,
                endMs: currentTimeMs,
                undoActionName: "Create Short from Playhead Range"
            )
            return
        }

        setSelectedShortEndToPlayhead()
    }

    public func clearPendingShortRange() {
        pendingShortStartMs = nil
    }

    public func deleteSelectedShort() {
        guard let shortsSelectedShortID else {
            return
        }
        deleteShort(id: shortsSelectedShortID)
    }

    public func addCropPointAtPlayhead(shortID: UUID) {
        guard let short = project?.shorts.first(where: { $0.id == shortID }),
              currentTimeMs >= short.startMs,
              currentTimeMs <= short.endMs else {
            exportMessage = "Move the playhead inside the selected short first."
            return
        }

        let offsetX = short.cropOffset(atTimelineTimeMs: currentTimeMs)
        guard var currentProject = project else {
            return
        }
        do {
            let result = try shortsEditingPolicy.upsertCropKeyframe(
                shorts: currentProject.shorts,
                id: shortID,
                timelineTimeMs: currentTimeMs,
                offsetX: offsetX
            )
            guard result.didChange else { return }
            currentProject.shorts = result.shorts
            updateProject(currentProject, undoActionName: "Add Crop Point")
        } catch ShortsEditError.shortNotFound {
            return
        } catch {
            assertionFailure("Unexpected crop point error: \(error)")
        }
    }

    public func updateShortCropOffset(
        id: UUID,
        timelineTimeMs: Int,
        offsetX: Double
    ) {
        guard var currentProject = project else {
            return
        }
        do {
            let result = try shortsEditingPolicy.upsertCropKeyframe(
                shorts: currentProject.shorts,
                id: id,
                timelineTimeMs: timelineTimeMs,
                offsetX: offsetX
            )
            guard result.didChange else { return }
            currentProject.shorts = result.shorts
            updateProject(currentProject)
        } catch ShortsEditError.shortNotFound {
            return
        } catch {
            assertionFailure("Unexpected crop offset error: \(error)")
        }
    }

    public func deleteShortCropKeyframe(shortID: UUID, keyframeID: UUID) {
        guard var currentProject = project else {
            return
        }
        do {
            let result = try shortsEditingPolicy.deleteCropKeyframe(
                shorts: currentProject.shorts,
                shortID: shortID,
                keyframeID: keyframeID
            )
            guard result.didChange else { return }
            currentProject.shorts = result.shorts
            updateProject(currentProject, undoActionName: "Delete Crop Point")
        } catch ShortsEditError.shortNotFound {
            return
        } catch {
            assertionFailure("Unexpected crop point deletion error: \(error)")
        }
    }

    public func deleteShort(id: UUID) {
        guard var currentProject = project else {
            return
        }

        do {
            let result = try shortsEditingPolicy.delete(shorts: currentProject.shorts, id: id)
            currentProject.shorts = result.shorts
            updateProject(currentProject, undoActionName: "Delete Short")
            if shortsSelectedShortID == id {
                shortsSelectedShortID = result.shorts.first?.id
            }
        } catch ShortsEditError.shortNotFound {
            return
        } catch {
            assertionFailure("Unexpected delete short error: \(error)")
        }
    }

    public func updateShortsExportSettings(_ settings: ShortsExportSettings) {
        guard var currentProject = project,
              currentProject.shortsExportSettings != settings else {
            return
        }

        currentProject.shortsExportSettings = settings
        updateProject(currentProject)
    }

    public func updateShortsSubtitleStyle(
        _ style: VideoExportSettings,
        registerUndo: Bool = true
    ) {
        guard var currentProject = project,
              currentProject.shortsExportSettings.subtitleStyle != style else {
            return
        }

        currentProject.shortsExportSettings.subtitleStyle = style
        updateProject(
            currentProject,
            undoActionName: registerUndo ? "Edit Shorts Subtitle Style" : nil
        )
    }

    public func beginInteractiveShortsSubtitleStyleEdit() {
        guard interactiveShortsSubtitleStyleSnapshot == nil, let project else {
            return
        }

        interactiveShortsSubtitleStyleSnapshot = ProjectUndoSnapshot(
            project: project,
            selectedSegmentID: selectedSegmentID,
            currentTimeMs: currentTimeMs
        )
    }

    public func endInteractiveShortsSubtitleStyleEdit(
        undoActionName: String = "Edit Shorts Subtitle Style"
    ) {
        guard let snapshot = interactiveShortsSubtitleStyleSnapshot else {
            return
        }
        interactiveShortsSubtitleStyleSnapshot = nil

        guard let project, project != snapshot.project else {
            return
        }

        pushUndoSnapshot(snapshot, actionName: undoActionName)
    }

    public func generateShortsSuggestions() {
        guard let project else {
            return
        }

        shortsSuggestions = ShortsSuggestionService().suggestions(
            cues: project.subtitles,
            platform: project.shortsExportSettings.platform,
            existingShorts: project.shorts
        )
        shortsSuggestionMessage = shortsSuggestions.isEmpty
            ? "No suggestions are available for the current subtitles."
            : nil
    }

    public func acceptShortSuggestion(_ suggestion: ShortSuggestion) {
        addShort(
            startMs: suggestion.startMs,
            endMs: suggestion.endMs,
            undoActionName: "Add Suggested Short"
        )
        shortsSuggestions.removeAll { $0.id == suggestion.id }
        shortsSuggestionMessage = nil
    }

    public func dismissShortSuggestion(_ suggestion: ShortSuggestion) {
        shortsSuggestions.removeAll { $0.id == suggestion.id }
        if shortsSuggestions.isEmpty {
            shortsSuggestionMessage = "No more suggestions."
        }
    }

    public func exportShorts(_ shorts: [ShortDefinition], to destinationDirectory: URL) {
        guard let project, !shorts.isEmpty else {
            return
        }

        appState.enqueueShortsExport(
            project: project,
            shorts: shorts,
            sourceInfo: videoSourceInfo,
            destinationDirectory: destinationDirectory
        )
    }

    private func defaultShortTitle(for project: Project) -> String {
        "Short \(project.shorts.count + 1)"
    }
}

private enum TranslationValidationError: LocalizedError {
    case segmentCountMismatch

    public var errorDescription: String? {
        switch self {
        case .segmentCountMismatch:
            return "Translation provider returned a different number of subtitle segments."
        }
    }
}

private enum TranscriptionValidationError: LocalizedError {
    case editTimelineEmpty

    var errorDescription: String? {
        switch self {
        case .editTimelineEmpty:
            return "The edit timeline has no video to transcribe. Review your cuts in Edit mode."
        }
    }
}

private struct ProjectUndoSnapshot {
    let project: Project
    let selectedSegmentID: UUID?
    let currentTimeMs: Int
}

public enum MP4ExportResult: Equatable, Identifiable {
    case success(String)
    case failure(message: String, debugOutput: String?)

    public var id: String {
        switch self {
        case .success(let outputPath):
            "success-\(outputPath)"
        case .failure(let message, let debugOutput):
            "failure-\(message)-\(debugOutput ?? "")"
        }
    }

    public var title: String {
        switch self {
        case .success:
            "MP4 Export Complete"
        case .failure:
            "MP4 Export Failed"
        }
    }
}
