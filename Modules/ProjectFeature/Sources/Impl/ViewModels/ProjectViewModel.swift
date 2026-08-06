import Combine
import Application
import ExportFeature
import Foundation
import Project
import Settings
import Shorts
import Subtitles
import Timeline
import VideoRendering

@MainActor
final class ProjectViewModel: ObservableObject {
    @Published var project: Project?
    @Published var autosaveErrorMessage: String?
    @Published var exportMessage: String?
    @Published var isTranscribing = false
    @Published var isTranslating = false
    @Published var isImportingSubtitles = false
    @Published var subtitleImportPreview: SubtitleImportPreview?
    @Published var subtitleImportErrorMessage: String?
    @Published var selectedSegmentID: UUID? {
        didSet {
            let updatedSelection = selectedSegmentID.map { Set([$0]) } ?? []
            if selectedCueIDs != updatedSelection {
                selectedCueIDs = updatedSelection
            }
            cueSelectionAnchorID = selectedSegmentID
        }
    }
    @Published private(set) var selectedCueIDs: Set<UUID> = []
    @Published var currentTimeMs = 0
    @Published var activeSegmentID: UUID?
    @Published var editModeSelectedClipID: UUID?
    @Published var editRangeStartMs: Int?
    @Published var editRangeEndMs: Int?
    @Published var isEditPlaybackEnabled = false
    @Published var shortsSelectedShortID: UUID?
    @Published var pendingShortStartMs: Int?
    @Published var shortsSuggestions: [ShortSuggestion] = []
    @Published var shortsSuggestionMessage: String?
    /// Incremented when another workspace asks the UI to switch to Shorts mode
    /// (e.g. "Create short from cue" in the subtitle editor).
    @Published var shortsFocusRequest = 0
    @Published private(set) var waveformPeaks: [Double] = []
    @Published private(set) var isPreparingProject = false
    @Published private(set) var projectPreparationProgress = 0.0
    @Published private(set) var projectPreparationStatus = "Preparing project..."
    @Published private(set) var videoSourceInfo: VideoSourceInfo?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    let availableLanguages = ["English", "Russian", "Spanish", "French", "German", "Italian", "Portuguese", "Chinese", "Japanese", "Korean"]
    var settings: AppSettings { settingsAccess.snapshot.settings }

    private let appState: AppState
    private let projectRepository: any ProjectRepository
    private let projectCatalog: any ProjectCatalogManaging
    private let settingsAccess: SettingsAccess
    private let subtitleImportService: any SubtitleImporting
    private let projectFileService: any ProjectFileServicing
    private let editTimelineService: any EditTimelineEditing
    private let subtitleTimelineMappingService = SubtitleTimelineMappingService()
    private let subtitleStructuralEditingPolicy = SubtitleStructuralEditingPolicy()
    private let subtitleImportMergePolicy = SubtitleImportMergePolicy()
    private let shortsEditingPolicy = ShortsEditingPolicy()
    private let projectPreparationWorkflow: any ProjectPreparationWorkflow
    private let projectTranscriptionWorkflow: any ProjectTranscriptionWorkflow
    private let projectTranslationWorkflow: any ProjectTranslationWorkflow
    private let pickSubtitleFile: @MainActor () async -> URL?
    private var autosaveTask: Task<Void, Never>?
    private var waveformTask: Task<Void, Never>?
    private var preparedWaveformProjectID: UUID?
    private var undoStack: [ProjectUndoSnapshot] = []
    private var redoStack: [ProjectUndoSnapshot] = []
    private var activeTextEditSegmentID: UUID?
    private var activeTextEditSnapshot: ProjectUndoSnapshot?
    private var interactiveShortEditSnapshot: ProjectUndoSnapshot?
    private var interactiveShortsSubtitleStyleSnapshot: ProjectUndoSnapshot?
    private var cueSelectionAnchorID: UUID?
    private let undoLimit = 200

    init(
        appState: AppState,
        dependencies: ProjectFeatureDependencies
    ) {
        self.appState = appState
        projectRepository = dependencies.projectRepository
        projectCatalog = dependencies.projectCatalog
        settingsAccess = dependencies.settingsAccess
        subtitleImportService = dependencies.subtitleImporter
        projectFileService = dependencies.projectFileService
        editTimelineService = dependencies.editTimelineService
        projectPreparationWorkflow = dependencies.projectPreparationWorkflow
        projectTranscriptionWorkflow = dependencies.projectTranscriptionWorkflow
        projectTranslationWorkflow = dependencies.projectTranslationWorkflow
        pickSubtitleFile = dependencies.pickSubtitleFile
        project = appState.selectedProject
    }

    deinit {
        autosaveTask?.cancel()
        waveformTask?.cancel()
    }

    func loadSelectedProject() {
        if project?.id != appState.selectedProject?.id {
            videoSourceInfo = nil
            pendingShortStartMs = nil
        }
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
            let projectID = project.id
            do {
                let output = try await projectPreparationWorkflow.prepare(
                    ProjectPreparationRequest(project: project, settings: settings),
                    events: { [weak self] event in
                        self?.handlePreparationEvent(event, projectID: projectID)
                    }
                )
                guard self.project?.id == projectID else { return }
                applyProject(output.project)
                waveformPeaks = output.waveformPeaks
                videoSourceInfo = output.videoSourceInfo
                preparedWaveformProjectID = projectID
                projectPreparationProgress = 1
                projectPreparationStatus = output.status
                isPreparingProject = false
            } catch is CancellationError {
                return
            } catch {
                guard self.project?.id == projectID else { return }
                waveformPeaks = []
                preparedWaveformProjectID = projectID
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

    func selectSegment(
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

    func mergeWithNextSegment(id: UUID) -> UUID? {
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

    func deleteSegment(id: UUID) -> UUID? {
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

    func addSegmentAfter(id: UUID) -> UUID? {
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

    func submitVideoExport(_ submission: VideoExportSubmission) {
        updateVideoExportSettings(submission.settings, registerUndo: false)
        appState.enqueueVideoExport(
            project: submission.project,
            settings: submission.settings,
            sourceInfo: submission.sourceInfo,
            outputURL: submission.outputURL
        )
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
        guard let currentProject = project, !isTranscribing else {
            return
        }

        isTranscribing = true
        appState.startTranscriptionActivity(projectName: currentProject.displayName)
        defer {
            isTranscribing = false
        }

        autosaveTask?.cancel()
        autosaveTask = nil

        do {
            let projectID = currentProject.id
            let output = try await projectTranscriptionWorkflow.transcribe(
                ProjectTranscriptionRequest(project: currentProject, settings: settings),
                events: { [weak self] event in
                    self?.handleTranscriptionEvent(event, projectID: projectID)
                }
            )
            guard project?.id == projectID else { return }
            applyProject(output.project)
            appState.finishTranscriptionActivity(
                success: true,
                message: output.completionMessage
            )
        } catch is CancellationError {
            appState.dismissTranscriptionActivity()
        } catch {
            let localizedError = error as? LocalizedError
            let message = localizedError?.errorDescription ?? "Transcription failed."
            appState.finishTranscriptionActivity(success: false, message: message)
            exportMessage = message
        }
    }

    func translate() async {
        guard let currentProject = project, !isTranslating else {
            return
        }

        guard !currentProject.subtitles.isEmpty else {
            exportMessage = ProjectTranslationError.noSubtitles.errorDescription
            return
        }

        isTranslating = true
        defer {
            isTranslating = false
        }
        autosaveTask?.cancel()
        autosaveTask = nil

        do {
            let projectID = currentProject.id
            let output = try await projectTranslationWorkflow.translate(
                ProjectTranslationRequest(project: currentProject),
                events: { [weak self] event in
                    self?.handleTranslationEvent(event, projectID: projectID)
                }
            )
            guard project?.id == projectID else { return }
            applyProject(output.project)
        } catch is CancellationError {
            return
        } catch {
            let localizedError = error as? LocalizedError
            exportMessage = localizedError?.errorDescription ?? "Translation failed."
        }
    }

    private func handlePreparationEvent(_ event: ProjectProcessingEvent, projectID: UUID) {
        guard project?.id == projectID else { return }
        switch event {
        case .projectChanged(let project):
            applyProject(project)
            scheduleAutosave(project)
        case .progress(let progress, let status):
            if let progress {
                projectPreparationProgress = progress
            }
            projectPreparationStatus = status
        }
    }

    private func handleTranscriptionEvent(_ event: ProjectProcessingEvent, projectID: UUID) {
        guard project?.id == projectID else { return }
        switch event {
        case .projectChanged(let project):
            applyProject(project)
        case .progress(let progress, let status):
            appState.updateTranscriptionActivity(statusText: status, progress: progress)
        }
    }

    private func handleTranslationEvent(_ event: ProjectProcessingEvent, projectID: UUID) {
        guard project?.id == projectID else { return }
        if case .projectChanged(let project) = event {
            applyProject(project)
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

    func exportSubtitles(kind: SubtitleExportKind, to destinationURL: URL) async {
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

    func importSubtitlesFromFile() {
        Task {
            guard let fileURL = await pickSubtitleFile() else { return }
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

    func saveProject() async {
        guard let project else {
            exportMessage = "No project selected."
            return
        }

        autosaveTask?.cancel()
        autosaveTask = nil

        do {
            try await projectRepository.saveProject(project)
            projectCatalog.register(project)
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
    }

    private func scheduleAutosave(_ project: Project) {
        autosaveTask?.cancel()
        let projectRepository = projectRepository
        let projectCatalog = projectCatalog
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
                try Task.checkCancellation()
                try await projectRepository.saveProject(project)
                projectCatalog.register(project)
                self?.autosaveErrorMessage = nil
            } catch is CancellationError {
                return
            } catch {
                self?.autosaveErrorMessage = "Autosave failed."
            }
        }
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
    var selectedShort: ShortDefinition? {
        guard let shortsSelectedShortID else {
            return nil
        }

        return project?.shorts.first { $0.id == shortsSelectedShortID }
    }

    @discardableResult
    func addShort(
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

    func addShortAtPlayhead() {
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
    func createShortFromSelectedCues() {
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

    func beginInteractiveShortEdit() {
        guard interactiveShortEditSnapshot == nil, let project else {
            return
        }

        interactiveShortEditSnapshot = ProjectUndoSnapshot(
            project: project,
            selectedSegmentID: selectedSegmentID,
            currentTimeMs: currentTimeMs
        )
    }

    func endInteractiveShortEdit(undoActionName: String) {
        guard let snapshot = interactiveShortEditSnapshot else {
            return
        }
        interactiveShortEditSnapshot = nil

        guard let project, project != snapshot.project else {
            return
        }

        pushUndoSnapshot(snapshot, actionName: undoActionName)
    }

    func updateShort(
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

    func updateShortRange(id: UUID, startMs: Int, endMs: Int) {
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

    func setSelectedShortStartToPlayhead() {
        guard let short = selectedShort else {
            return
        }
        guard currentTimeMs >= 0, currentTimeMs <= short.endMs - 1_000 else {
            exportMessage = "Move the playhead at least one second before the short end."
            return
        }

        updateShortRange(id: short.id, startMs: currentTimeMs, endMs: short.endMs)
    }

    func setSelectedShortEndToPlayhead() {
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
    func setShortStartFromPlayhead() {
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

    func setShortEndFromPlayhead() {
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

    func clearPendingShortRange() {
        pendingShortStartMs = nil
    }

    func deleteSelectedShort() {
        guard let shortsSelectedShortID else {
            return
        }
        deleteShort(id: shortsSelectedShortID)
    }

    func addCropPointAtPlayhead(shortID: UUID) {
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

    func updateShortCropOffset(
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

    func deleteShortCropKeyframe(shortID: UUID, keyframeID: UUID) {
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

    func deleteShort(id: UUID) {
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

    func updateShortsExportSettings(_ settings: ShortsExportSettings) {
        guard var currentProject = project,
              currentProject.shortsExportSettings != settings else {
            return
        }

        currentProject.shortsExportSettings = settings
        updateProject(currentProject)
    }

    func updateShortsSubtitleStyle(
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

    func beginInteractiveShortsSubtitleStyleEdit() {
        guard interactiveShortsSubtitleStyleSnapshot == nil, let project else {
            return
        }

        interactiveShortsSubtitleStyleSnapshot = ProjectUndoSnapshot(
            project: project,
            selectedSegmentID: selectedSegmentID,
            currentTimeMs: currentTimeMs
        )
    }

    func endInteractiveShortsSubtitleStyleEdit(
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

    func generateShortsSuggestions() {
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

    func acceptShortSuggestion(_ suggestion: ShortSuggestion) {
        addShort(
            startMs: suggestion.startMs,
            endMs: suggestion.endMs,
            undoActionName: "Add Suggested Short"
        )
        shortsSuggestions.removeAll { $0.id == suggestion.id }
        shortsSuggestionMessage = nil
    }

    func dismissShortSuggestion(_ suggestion: ShortSuggestion) {
        shortsSuggestions.removeAll { $0.id == suggestion.id }
        if shortsSuggestions.isEmpty {
            shortsSuggestionMessage = "No more suggestions."
        }
    }

    func exportShorts(_ shorts: [ShortDefinition], to destinationDirectory: URL) {
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

private struct ProjectUndoSnapshot {
    let project: Project
    let selectedSegmentID: UUID?
    let currentTimeMs: Int
}
