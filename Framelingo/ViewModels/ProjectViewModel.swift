import AppKit
import Foundation
import Combine
import UniformTypeIdentifiers

@MainActor
final class ProjectViewModel: ObservableObject {
    @Published var project: Project?
    @Published var autosaveErrorMessage: String?
    @Published var exportMessage: String?
    @Published var mp4ExportResult: MP4ExportResult?
    @Published var isTranscribing = false
    @Published var isTranslating = false
    @Published var isExportingMP4 = false
    @Published var isImportingSubtitles = false
    @Published var subtitleImportPreview: SubtitleImportPreview?
    @Published var subtitleImportErrorMessage: String?
    @Published var selectedSegmentID: UUID?
    @Published var currentTimeMs = 0
    @Published var activeSegmentID: UUID?
    @Published var editModeSelectedClipID: UUID?
    @Published var editRangeStartMs: Int?
    @Published var editRangeEndMs: Int?
    @Published var isEditPlaybackEnabled = false
    @Published private(set) var waveformPeaks: [Double] = []
    @Published private(set) var isPreparingProject = false
    @Published private(set) var projectPreparationProgress = 0.0
    @Published private(set) var projectPreparationStatus = "Preparing project..."
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    let availableLanguages = ["English", "Russian", "Spanish", "French", "German", "Italian", "Portuguese", "Chinese", "Japanese", "Korean"]
    var settings: AppSettings { appState.settings }

    private let appState: AppState
    private let subtitleImportService = SubtitleImportService()
    private let projectFileService = ProjectFileService()
    private let editTimelineService = EditTimelineService()
    private let subtitleTimelineMappingService = SubtitleTimelineMappingService()
    private let mediaMetadataService = MediaMetadataService()
    private let waveformService = WaveformService()
    private var autosaveTask: Task<Void, Never>?
    private var waveformTask: Task<Void, Never>?
    private var preparedWaveformProjectID: UUID?
    private var undoStack: [ProjectUndoSnapshot] = []
    private var redoStack: [ProjectUndoSnapshot] = []
    private var activeTextEditSegmentID: UUID?
    private var activeTextEditSnapshot: ProjectUndoSnapshot?
    private let undoLimit = 200
    private static let diarizationWarningMessage = "Transcription complete. Speaker analysis failed; subtitle timings were not refined."

    init(appState: AppState) {
        self.appState = appState
        project = appState.selectedProject
    }

    deinit {
        autosaveTask?.cancel()
        waveformTask?.cancel()
    }

    func loadSelectedProject() {
        project = appState.selectedProject
    }

    func prepareProjectForEditing() {
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

                let peaks = try await waveformService.loadWaveform(
                    for: project,
                    ffmpegService: ffmpegService,
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

    func undo() {
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

    func redo() {
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

    func beginSubtitleTextEdit(id: UUID) {
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

    func endSubtitleTextEdit() {
        activeTextEditSegmentID = nil
        activeTextEditSnapshot = nil
    }

    func updateSubtitle(_ segment: SubtitleSegment) {
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
            currentProject.subtitles = SubtitleTimingValidator.updateSegmentTiming(
                segments: currentProject.subtitles,
                id: segment.id,
                startMs: segment.startMs,
                endMs: segment.endMs,
                durationMs: timelineDurationMs(for: currentProject)
            )

            if let clamped = currentProject.subtitles.first(where: { $0.id == segment.id }),
               clamped.startMs != segment.startMs || clamped.endMs != segment.endMs {
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

    func updateSegmentTiming(id: UUID, startMs: Int, endMs: Int) {
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

    func moveSegment(id: UUID, deltaMs: Int) {
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

    func updateSubtitlesFromTimeline(_ subtitles: [SubtitleSegment]) {
        guard var currentProject = project else {
            return
        }

        currentProject.subtitles = SubtitleTimingValidator.reindexed(subtitles)
        autosaveErrorMessage = nil
        updateProject(currentProject, undoActionName: "Edit Timeline")
    }

    func updateTimelineTranslatedText(segmentID: UUID, text: String) {
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

    func updateSpeakerLabel(id: Int, displayName: String) {
        guard var currentProject = project,
              let index = currentProject.speakerLabels.firstIndex(where: { $0.id == id }) else {
            return
        }

        currentProject.speakerLabels[index].displayName = displayName
        updateProject(currentProject, undoActionName: "Rename Speaker")
    }

    func selectSegment(id: UUID?) {
        selectedSegmentID = id
    }

    func seekTo(ms: Int) {
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

    func splitSegment(id: UUID) -> UUID? {
        guard var currentProject = project,
              let index = currentProject.subtitles.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let segment = currentProject.subtitles[index]
        let midpointMs = segment.startMs + max(1, segment.durationMs / 2)
        guard midpointMs > segment.startMs, midpointMs < segment.endMs else {
            autosaveErrorMessage = "Segment is too short to split."
            return nil
        }

        let originalParts = splitText(segment.originalText)
        let translatedParts = splitText(segment.translatedText)

        var firstSegment = segment
        firstSegment.endMs = midpointMs
        firstSegment.originalText = originalParts.first
        firstSegment.translatedText = translatedParts.first

        let secondSegment = SubtitleSegment(
            id: UUID(),
            index: segment.index + 1,
            startMs: midpointMs,
            endMs: segment.endMs,
            originalText: originalParts.second,
            translatedText: translatedParts.second,
            speaker: segment.speaker,
            speakerId: segment.speakerId,
            confidence: segment.confidence,
            warnings: segment.warnings
        )

        currentProject.subtitles[index] = firstSegment
        currentProject.subtitles.insert(secondSegment, at: index + 1)
        currentProject.subtitles = SubtitleTimingValidator.reindexed(currentProject.subtitles)
        updateProject(currentProject, undoActionName: "Split Subtitle")
        return secondSegment.id
    }

    func mergeWithNextSegment(id: UUID) -> UUID? {
        guard var currentProject = project,
              let index = currentProject.subtitles.firstIndex(where: { $0.id == id }),
              index + 1 < currentProject.subtitles.count else {
            autosaveErrorMessage = "No next segment to merge."
            return nil
        }

        let segment = currentProject.subtitles[index]
        let nextSegment = currentProject.subtitles[index + 1]

        var mergedSegment = segment
        mergedSegment.endMs = nextSegment.endMs
        mergedSegment.originalText = joinedText(segment.originalText, nextSegment.originalText)
        mergedSegment.translatedText = joinedText(segment.translatedText, nextSegment.translatedText)
        mergedSegment.confidence = minOptional(segment.confidence, nextSegment.confidence)

        currentProject.subtitles[index] = mergedSegment
        currentProject.subtitles.remove(at: index + 1)
        currentProject.subtitles = SubtitleTimingValidator.reindexed(currentProject.subtitles)
        updateProject(currentProject, undoActionName: "Merge Subtitles")
        return mergedSegment.id
    }

    func deleteSegment(id: UUID) -> UUID? {
        guard var currentProject = project,
              let index = currentProject.subtitles.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        currentProject.subtitles.remove(at: index)
        currentProject.subtitles = SubtitleTimingValidator.reindexed(currentProject.subtitles)
        updateProject(currentProject, undoActionName: "Delete Subtitle")

        if currentProject.subtitles.isEmpty {
            return nil
        }

        let nextIndex = min(index, currentProject.subtitles.count - 1)
        return currentProject.subtitles[nextIndex].id
    }

    func addSegmentAfter(id: UUID) -> UUID? {
        guard var currentProject = project,
              let index = currentProject.subtitles.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let segment = currentProject.subtitles[index]
        let newSegment = SubtitleSegment(
            id: UUID(),
            index: segment.index + 1,
            startMs: segment.endMs,
            endMs: segment.endMs + 2_000,
            originalText: "",
            translatedText: "",
            speaker: nil,
            confidence: nil
        )

        currentProject.subtitles.insert(newSegment, at: index + 1)
        currentProject.subtitles = SubtitleTimingValidator.reindexed(currentProject.subtitles)
        updateProject(currentProject, undoActionName: "Add Subtitle")
        return newSegment.id
    }

    func updateSourceLanguage(_ language: String) {
        guard var currentProject = project else {
            return
        }

        currentProject.sourceLanguage = language
        updateProject(currentProject, undoActionName: "Change Source Language")
    }

    func updateTargetLanguage(_ language: String) {
        guard var currentProject = project else {
            return
        }

        currentProject.targetLanguage = language
        updateProject(currentProject, undoActionName: "Change Target Language")
    }

    func updateVideoExportSettings(_ settings: VideoExportSettings, registerUndo: Bool = true) {
        guard var currentProject = project, currentProject.videoExportSettings != settings else {
            return
        }

        currentProject.videoExportSettings = settings
        updateProject(currentProject, undoActionName: registerUndo ? "Edit Subtitle Style" : nil)
    }

    func updateSpeakerExportOptions(_ options: SubtitleExportOptions) {
        guard var currentProject = project, currentProject.speakerExportOptions != options else {
            return
        }

        currentProject.speakerExportOptions = options
        updateProject(currentProject, undoActionName: "Edit Export Options")
    }

    func ensureEditTimeline() {
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

    func resolvedEditTimeline(for project: Project) -> EditTimeline? {
        if let timeline = project.editTimeline, !timeline.isEmpty {
            return timeline
        }

        guard let durationMs = sourceDurationMs(for: project), durationMs > 0 else {
            return nil
        }

        return editTimelineService.makeInitialTimeline(durationMs: durationMs)
    }

    func setEditRangeStartFromCurrentTime() {
        editRangeStartMs = currentTimeMs
    }

    func setEditRangeEndFromCurrentTime() {
        editRangeEndMs = currentTimeMs
    }

    func clearEditRange() {
        editRangeStartMs = nil
        editRangeEndMs = nil
    }

    func rippleDeleteSelectedRange() {
        guard var currentProject = project else {
            return
        }

        ensureEditTimeline()

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

    func splitAtCurrentTime() {
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

    func deleteSelectedClip() {
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

    func timelineTimeToSourceTime(_ timelineMs: Int) -> Int? {
        guard let project,
              let timeline = resolvedEditTimeline(for: project) else {
            return nil
        }

        return editTimelineService.sourceTime(forTimelineTime: timelineMs, in: timeline)
    }

    func editClip(atTimelineTime timelineMs: Int) -> TimelineClip? {
        guard let project,
              let timeline = resolvedEditTimeline(for: project) else {
            return nil
        }

        return editTimelineService.clip(atTimelineTime: timelineMs, in: timeline)
    }

    func editPlaybackAdvance(sourceTimeMs: Int, currentClipID: UUID?) -> EditTimelinePlaybackAdvance? {
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

    func seekTimeline(to ms: Int) {
        let durationMs = project.map(timelineDurationMs(for:)) ?? 0
        seekTo(ms: min(max(ms, 0), max(durationMs, 0)))
    }

    func playTimeline() {
        isEditPlaybackEnabled = true
    }

    func pauseTimeline() {
        isEditPlaybackEnabled = false
    }

    func transcribe() async {
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
            let extractedAudioURL = try await ffmpegService.extractAudio(
                from: currentProject.mediaFile.originalURL,
                to: audioURL
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
            let provider = try SpeechToTextProviderFactory.makeProvider(settings: appState.settings)
            let result = try await SpeechToTextService(provider: provider).transcribe(input)

            currentProject.subtitles = result.segments
            currentProject.wordTimings = result.words
            if let detectedLanguage = result.detectedLanguage {
                currentProject.sourceLanguage = detectedLanguage
            }
            if let durationMs = result.durationMs {
                currentProject.mediaFile.durationMs = durationMs
            }

            let diarizationOutcome = try await performDiarizationAndAlignment(for: currentProject)
            currentProject = diarizationOutcome.project

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

    func translate() async {
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


    func suggestedExportFileName(for kind: SubtitleExportKind) -> String {
        let baseName = project?.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        let safeBaseName = (baseName?.isEmpty == false ? baseName : "subtitles") ?? "subtitles"
        return "\(safeBaseName).\(kind.fileExtension)"
    }

    func suggestedMP4ExportFileName() -> String {
        let baseName = project?.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        let safeBaseName = (baseName?.isEmpty == false ? baseName : "subtitled-video") ?? "subtitled-video"
        return "\(safeBaseName).mp4"
    }

    func exportSubtitles(kind: SubtitleExportKind, to destinationURL: URL) async {
        guard let project else {
            exportMessage = "No project selected."
            return
        }

        do {
            try await appState.subtitleExportService.export(
                project: project,
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

    func exportMP4(to destinationURL: URL) async {
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

            let outputURL = try await ffmpegService.burnSubtitles(
                videoURL: currentProject.mediaFile.originalURL,
                subtitlesURL: subtitlesURL,
                outputURL: destinationURL,
                settings: settings
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

    func makeExportVideoViewModel(for project: Project) -> ExportVideoViewModel {
        ExportVideoViewModel(
            project: project,
            settings: project.videoExportSettings,
            ffmpegService: ffmpegService
        )
    }

    func importSubtitlesFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Subtitles"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = SubtitleFileFormat.allSupportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }

        guard panel.runModal() == .OK, let fileURL = panel.url else {
            return
        }

        Task {
            await previewSubtitleImport(from: fileURL)
        }
    }

    func previewSubtitleImport(from fileURL: URL) async {
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

    func applySubtitleImport(
        _ preview: SubtitleImportPreview,
        mode: SubtitleImportMode,
        destination: SubtitleImportDestination = .original
    ) {
        guard var currentProject = project else {
            subtitleImportErrorMessage = "No project selected."
            return
        }

        currentProject.subtitles = importedSubtitles(
            currentSubtitles: currentProject.subtitles,
            importedSubtitles: preview.segments,
            mode: mode,
            destination: destination
        )

        currentProject.subtitles = SubtitleTimingValidator.reindexed(currentProject.subtitles)
        selectedSegmentID = currentProject.subtitles.first?.id
        autosaveErrorMessage = nil
        subtitleImportPreview = nil
        updateProject(currentProject, undoActionName: "Import Subtitles")
    }

    private func importedSubtitles(
        currentSubtitles: [SubtitleSegment],
        importedSubtitles: [SubtitleSegment],
        mode: SubtitleImportMode,
        destination: SubtitleImportDestination
    ) -> [SubtitleSegment] {
        switch destination {
        case .original:
            switch mode {
            case .replaceExisting:
                return importedSubtitles
            case .appendToExisting:
                return currentSubtitles + importedSubtitles
            }

        case .translated:
            let translatedSubtitles = importedSubtitles.map { imported in
                var updated = imported
                updated.originalText = ""
                updated.translatedText = imported.originalText
                return updated
            }

            switch mode {
            case .appendToExisting:
                return currentSubtitles + translatedSubtitles

            case .replaceExisting:
                guard !currentSubtitles.isEmpty else {
                    return translatedSubtitles
                }

                var result = currentSubtitles
                let sharedCount = min(result.count, importedSubtitles.count)

                for index in 0..<sharedCount {
                    result[index].translatedText = importedSubtitles[index].originalText
                }

                if importedSubtitles.count > result.count {
                    result.append(contentsOf: translatedSubtitles.dropFirst(result.count))
                }

                return result
            }
        }
    }

    func saveProject() async {
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

    func exportProjectFile(to fileURL: URL) {
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

    private func performDiarizationAndAlignment(for project: Project) async throws -> (project: Project, failureMessage: String?) {
        do {
            appState.updateTranscriptionActivity(statusText: "Analyzing speakers...", progress: 0.95)
            let audioURL = try await appState.audioPreparationService.preparedAudioURL(
                for: project.mediaFile.originalURL
            )

            let speakerSegments = try await appState.speakerDiarizationEngine.diarize(audioURL: audioURL)

            appState.updateTranscriptionActivity(statusText: "Aligning subtitles...", progress: 0.99)
            let words = project.wordTimings.isEmpty
                ? syntheticWordTimings(from: project.subtitles)
                : project.wordTimings

            let alignedSubtitles = try await appState.subtitleAlignmentEngine.align(
                words: words,
                existingCues: project.subtitles,
                speakerSegments: speakerSegments,
                options: SubtitleAlignmentOptions()
            )

            var alignedProject = project
            alignedProject.speakerSegments = speakerSegments
            alignedProject.speakerLabels = speakerLabels(for: speakerSegments, existingLabels: project.speakerLabels)
            alignedProject.subtitles = SubtitleTimingValidator.reindexed(alignedSubtitles)
            return (alignedProject, nil)
        } catch let error as CancellationError {
            throw error
        } catch {
            return (project, diarizationFailureMessage(from: error))
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

    private var ffmpegService: FFmpegService {
        FFmpegServiceFactory.makeDefaultService(settings: appState.settings)
    }

    private func temporaryAudioURL(for project: Project) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .appendingPathComponent("audio-\(UUID().uuidString).wav")
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

        let content = try ASSSubtitleExportService().generateASS(
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

    private func reindexed(_ segments: [SubtitleSegment]) -> [SubtitleSegment] {
        SubtitleTimingValidator.reindexed(segments)
    }

    func timelineDurationMs(for project: Project) -> Int {
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

    private func splitText(_ text: String) -> (first: String, second: String) {
        let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard words.count > 1 else {
            return (text, "")
        }

        let midpoint = max(1, words.count / 2)
        return (
            words.prefix(midpoint).joined(separator: " "),
            words.dropFirst(midpoint).joined(separator: " ")
        )
    }

    private func joinedText(_ first: String, _ second: String) -> String {
        [first, second]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func minOptional(_ first: Double?, _ second: Double?) -> Double? {
        switch (first, second) {
        case let (.some(first), .some(second)):
            return min(first, second)
        case let (.some(first), .none):
            return first
        case let (.none, .some(second)):
            return second
        case (.none, .none):
            return nil
        }
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

private enum TranslationValidationError: LocalizedError {
    case segmentCountMismatch

    var errorDescription: String? {
        switch self {
        case .segmentCountMismatch:
            return "Translation provider returned a different number of subtitle segments."
        }
    }
}

private struct ProjectUndoSnapshot {
    let project: Project
    let selectedSegmentID: UUID?
    let currentTimeMs: Int
}

enum MP4ExportResult: Equatable, Identifiable {
    case success(String)
    case failure(message: String, debugOutput: String?)

    var id: String {
        switch self {
        case .success(let outputPath):
            "success-\(outputPath)"
        case .failure(let message, let debugOutput):
            "failure-\(message)-\(debugOutput ?? "")"
        }
    }

    var title: String {
        switch self {
        case .success:
            "MP4 Export Complete"
        case .failure:
            "MP4 Export Failed"
        }
    }
}
