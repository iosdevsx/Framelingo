import Combine
import ExportFeature
import Foundation
import Project
import ProjectFeature
import ProjectPreparation
import ProjectSession
import TranscriptionPipeline
import TranslationPipeline
import Settings
import Shorts
import Subtitles
import SubtitleEditorFeature
import Timeline
import VideoRendering
import VideoExport

@MainActor
final class ProjectViewModel: ObservableObject {
    var sessionSnapshot: ProjectSessionSnapshot { session.snapshot }
    var subtitleEditingPort: any ProjectSessionSubtitleEditing { session }
    var selectionPlaybackPort: any ProjectSessionSelectionPlaybackEditing { session }
    var timelineEditingPort: any ProjectSessionTimelineEditing { session }
    var shortsEditingPort: any ProjectSessionShortsEditing { session }
    var historyPort: any ProjectSessionHistoryControlling { session }
    var sessionObservingPort: any ProjectSessionObserving { session }
    var project: Project? { session.snapshot.project }
    @Published var autosaveErrorMessage: String?
    @Published var exportMessage: String?
    @Published var isTranscribing = false
    @Published var isTranslating = false
    @Published var isImportingSubtitles = false
    @Published var subtitleImportPreview: SubtitleImportPreview?
    @Published var subtitleImportErrorMessage: String?
    var selectedSegmentID: UUID? {
        get { session.snapshot.interaction.cueSelection.primaryCueID }
        set { session.selectCue(id: newValue, extending: false, toggling: false) }
    }
    var selectedCueIDs: Set<UUID> { session.snapshot.interaction.cueSelection.selectedCueIDs }
    var currentTimeMs: Int {
        get { session.snapshot.interaction.playback.playheadMs }
        set { session.seek(to: newValue) }
    }
    var activeSegmentID: UUID? { session.snapshot.interaction.playback.activeCueID }
    var editModeSelectedClipID: UUID? {
        get { session.snapshot.interaction.timeline.selectedClipID }
        set { session.setTimelineClipSelection(newValue) }
    }
    var editRangeStartMs: Int? {
        get { session.snapshot.interaction.timeline.rangeStartMs }
        set { session.setEditRange(startMs: newValue, endMs: editRangeEndMs) }
    }
    var editRangeEndMs: Int? {
        get { session.snapshot.interaction.timeline.rangeEndMs }
        set { session.setEditRange(startMs: editRangeStartMs, endMs: newValue) }
    }
    var isEditPlaybackEnabled: Bool { session.snapshot.interaction.timeline.isPlaybackEnabled }
    var shortsSelectedShortID: UUID? {
        get { session.snapshot.interaction.shorts.selectedShortID }
        set { session.selectShort(id: newValue) }
    }
    var pendingShortStartMs: Int? { session.snapshot.interaction.shorts.pendingRangeStartMs }
    var shortsSuggestions: [ShortSuggestion] { session.snapshot.interaction.shorts.suggestions }
    var shortsSuggestionMessage: String? {
        switch session.snapshot.interaction.shorts.suggestionStatus {
        case .empty: "No suggestions are available for the current subtitles."
        case .exhausted: "No more suggestions."
        case .idle, .available: nil
        }
    }
    /// Incremented when another workspace asks the UI to switch to Shorts mode
    /// (e.g. "Create short from cue" in the subtitle editor).
    @Published var shortsFocusRequest = 0
    @Published private(set) var waveformPeaks: [Double] = []
    @Published private(set) var isPreparingProject = false
    @Published private(set) var projectPreparationProgress = 0.0
    @Published private(set) var projectPreparationStatus = "Preparing project..."
    @Published private(set) var videoSourceInfo: VideoSourceInfo?
    var canUndo: Bool { session.snapshot.history.canUndo }
    var canRedo: Bool { session.snapshot.history.canRedo }

    let availableLanguages = ["English", "Russian", "Spanish", "French", "German", "Italian", "Portuguese", "Chinese", "Japanese", "Korean"]
    var settings: AppSettings { settingsAccess.snapshot.settings }

    private let projectRepository: any ProjectRepository
    private let projectCatalog: any ProjectCatalogManaging
    private let settingsAccess: SettingsAccess
    private let subtitleImportService: any SubtitleImporting
    private let subtitleExportService: any SubtitleExportService
    private let projectFileService: any ProjectFileServicing
    private let subtitleImportMergePolicy = SubtitleImportMergePolicy()
    private let projectPreparer: any ProjectPreparing
    private let projectPreparationConfiguration: ProjectPreparationConfigurationProvider
    private let projectTranscriber: any TranscribingProject
    private let transcriptionActivity: any TranscriptionActivityTracking
    private let projectTranslator: any TranslatingProject
    private let selection: ProjectSelectionAccess
    private let subtitleDocumentPicker: SubtitleDocumentPicker
    private let videoExportQueue: any VideoExportQueue
    private let session: any ProjectSessionWorkspace
    private var sessionSubscription: AnyCancellable?
    private var selectionSubscription: AnyCancellable?
    private var waveformTask: Task<Void, Never>?
    private var preparationOperationID: UUID?
    private var transcriptionOperationID: UUID?
    private var translationOperationID: UUID?
    private var preparedWaveformProjectID: UUID?

    init(dependencies: ProjectFeatureDependencies) {
        projectRepository = dependencies.data.projectRepository
        projectCatalog = dependencies.data.projectCatalog
        settingsAccess = dependencies.data.settingsAccess
        subtitleImportService = dependencies.editing.subtitleImporter
        subtitleExportService = dependencies.editing.subtitleExportService
        projectFileService = dependencies.editing.projectFileService
        projectPreparer = dependencies.processing.projectPreparer
        projectPreparationConfiguration = dependencies.processing.projectPreparationConfiguration
        projectTranscriber = dependencies.processing.projectTranscriber
        transcriptionActivity = dependencies.processing.transcriptionActivity
        projectTranslator = dependencies.processing.projectTranslator
        selection = dependencies.data.selection
        subtitleDocumentPicker = dependencies.editing.subtitleDocumentPicker
        videoExportQueue = dependencies.videoExportQueue
        session = dependencies.session
        if let project = dependencies.data.selection.current {
            session.open(project)
        }
        sessionSubscription = session.snapshots.dropFirst().sink { [weak self] snapshot in
            self?.objectWillChange.send()
            if case .failed = snapshot.persistence {
                self?.autosaveErrorMessage = "Autosave failed."
            } else if case .saved = snapshot.persistence {
                self?.autosaveErrorMessage = nil
                if let project = snapshot.project { self?.projectCatalog.register(project) }
            }
        }
        selectionSubscription = dependencies.data.selection.updates.sink { [weak self] selectedProject in
            guard let self, self.project != selectedProject else { return }
            if self.project?.id != selectedProject?.id {
                self.videoSourceInfo = nil
            }
            if let selectedProject { self.session.open(selectedProject) } else { self.session.close() }
        }
    }

    deinit {
        waveformTask?.cancel()
    }

    func loadSelectedProject() {
        if project?.id != selection.current?.id {
            videoSourceInfo = nil
        }
        if let selected = selection.current { session.open(selected) } else { session.close() }
    }

    func prepareProjectForEditing() {
        guard let project else {
            waveformTask?.cancel()
            preparationOperationID = nil
            preparedWaveformProjectID = nil
            waveformPeaks = []
            isPreparingProject = false
            projectPreparationProgress = 0
            return
        }

        if preparedWaveformProjectID == project.id, !waveformPeaks.isEmpty {
            preparationOperationID = nil
            isPreparingProject = false
            projectPreparationProgress = 1
            projectPreparationStatus = "Project ready"
            return
        }

        waveformTask?.cancel()
        let operationID = UUID()
        preparationOperationID = operationID
        waveformPeaks = []
        preparedWaveformProjectID = nil
        isPreparingProject = true
        projectPreparationProgress = 0.02
        projectPreparationStatus = "Preparing project..."

        waveformTask = Task { [weak self] in
            guard let self else { return }
            let projectID = project.id
            do {
                let output = try await projectPreparer.prepare(
                    ProjectPreparationRequest(
                        project: project,
                        configuration: projectPreparationConfiguration()
                    ),
                    events: { [weak self] event in
                        self?.handlePreparationEvent(
                            event,
                            projectID: projectID,
                            operationID: operationID
                        )
                    }
                )
                guard self.project?.id == projectID,
                      preparationOperationID == operationID else { return }
                applyProject(output.project)
                waveformPeaks = output.waveformPeaks
                videoSourceInfo = output.videoSourceInfo
                preparedWaveformProjectID = projectID
                projectPreparationProgress = 1
                projectPreparationStatus = ProjectPreparationPresentation.status(for: output.outcome)
                isPreparingProject = false
                preparationOperationID = nil
            } catch is CancellationError {
                return
            } catch {
                guard self.project?.id == projectID,
                      preparationOperationID == operationID else { return }
                waveformPeaks = []
                preparedWaveformProjectID = projectID
                projectPreparationProgress = 1
                projectPreparationStatus = "Project ready. Waveform unavailable."
                isPreparingProject = false
                preparationOperationID = nil
            }
        }
    }

    func undo() {
        session.undo()
    }

    func redo() {
        session.redo()
    }

    func beginSubtitleTextEdit(id: UUID) {
        session.beginInteraction(named: "subtitle-text")
    }

    func endSubtitleTextEdit() {
        session.endInteraction(named: "subtitle-text")
    }

    func updateSubtitle(_ segment: SubtitleSegment) {
        present(session.updateSubtitle(segment))
    }

    func updateSegmentTiming(id: UUID, startMs: Int, endMs: Int) {
        present(session.updateSegmentTiming(id: id, startMs: startMs, endMs: endMs))
    }

    func moveSegment(id: UUID, deltaMs: Int) {
        present(session.moveSegment(id: id, deltaMs: deltaMs))
    }

    func updateSubtitlesFromTimeline(_ subtitles: [SubtitleSegment]) {
        present(session.replaceSubtitlesFromTimeline(subtitles))
    }

    func updateTimelineTranslatedText(segmentID: UUID, text: String) {
        present(session.updateTranslatedText(segmentID: segmentID, text: text))
    }

    func updateSpeakerLabel(id: Int, displayName: String) {
        present(session.updateSpeakerLabel(id: id, displayName: displayName))
    }

    func selectSegment(
        id: UUID?,
        extendingSelection: Bool = false,
        togglingSelection: Bool = false
    ) {
        session.selectCue(id: id, extending: extendingSelection, toggling: togglingSelection)
    }

    func seekTo(ms: Int) {
        session.seek(to: ms)
    }

    func splitSegment(id: UUID) -> UUID? {
        let result = session.splitSegment(id: id)
        present(result)
        return result.selectedID
    }

    func mergeWithNextSegment(id: UUID) -> UUID? {
        let result = session.mergeWithNextSegment(id: id)
        present(result)
        return result.selectedID
    }

    func deleteSegment(id: UUID) -> UUID? {
        let result = session.deleteSegment(id: id)
        present(result)
        return result.selectedID
    }

    func addSegmentAfter(id: UUID) -> UUID? {
        let result = session.addSegmentAfter(id: id)
        present(result)
        return result.selectedID
    }

    func updateSourceLanguage(_ language: String) {
        present(session.updateSourceLanguage(language))
    }

    func updateTargetLanguage(_ language: String) {
        present(session.updateTargetLanguage(language))
    }

    func updateVideoExportSettings(_ settings: VideoExportSettings, registerUndo: Bool = true) {
        present(session.updateVideoExportSettings(settings, undoable: registerUndo))
    }

    func submitVideoExport(_ submission: VideoExportSubmission) {
        updateVideoExportSettings(submission.settings, registerUndo: false)
        videoExportQueue.enqueue(.fullProject(submission.request))
    }

    func updateSpeakerExportOptions(_ options: SubtitleExportOptions) {
        present(session.updateSpeakerExportOptions(options))
    }

    func ensureEditTimeline() {
        exportMessage = session.ensureTimeline().message
    }

    func resolvedEditTimeline(for project: Project) -> EditTimeline? {
        session.resolvedTimeline()
    }

    func setEditRangeStartFromCurrentTime() {
        session.setEditRangeStartFromPlayhead()
    }

    func setEditRangeEndFromCurrentTime() {
        session.setEditRangeEndFromPlayhead()
    }

    func clearEditRange() {
        session.clearEditRange()
    }

    func rippleDeleteSelectedRange() {
        exportMessage = session.rippleDeleteSelectedRange().message
    }

    func splitAtCurrentTime() {
        exportMessage = session.splitAtPlayhead().message
    }

    func deleteSelectedClip() {
        exportMessage = session.deleteSelectedClip().message
    }

    func timelineTimeToSourceTime(_ timelineMs: Int) -> Int? {
        session.sourceTime(forTimelineTime: timelineMs)
    }

    func editClip(atTimelineTime timelineMs: Int) -> TimelineClip? {
        session.clip(atTimelineTime: timelineMs)
    }

    func editPlaybackAdvance(sourceTimeMs: Int, currentClipID: UUID?) -> EditTimelinePlaybackAdvance? {
        session.playbackAdvance(sourceTimeMs: sourceTimeMs, currentClipID: currentClipID)
    }

    func seekTimeline(to ms: Int) {
        session.seekTimeline(to: ms)
    }

    func playTimeline() {
        session.setTimelinePlaybackEnabled(true)
    }

    func pauseTimeline() {
        session.setTimelinePlaybackEnabled(false)
    }

    func transcribe() async {
        guard let currentProject = project, !isTranscribing else {
            return
        }

        let operationID = UUID()
        transcriptionOperationID = operationID
        isTranscribing = true
        transcriptionActivity.start(projectName: currentProject.displayName)
        defer {
            if transcriptionOperationID == operationID {
                transcriptionOperationID = nil
                isTranscribing = false
            }
        }

        do {
            let projectID = currentProject.id
            let output = try await projectTranscriber.transcribe(
                TranscriptionPipelineRequest(
                    project: currentProject,
                    configuration: TranscriptionPipelinePresentation.configuration(from: settings)
                ),
                events: { [weak self] event in
                    self?.handleTranscriptionEvent(
                        event,
                        projectID: projectID,
                        operationID: operationID
                    )
                }
            )
            guard transcriptionOperationID == operationID else { return }
            guard project?.id == projectID else {
                transcriptionActivity.dismiss()
                return
            }
            applyProject(output.project)
            transcriptionActivity.finish(
                success: true,
                message: TranscriptionPipelinePresentation.completionMessage(for: output.warning)
            )
        } catch is CancellationError {
            guard transcriptionOperationID == operationID else { return }
            transcriptionActivity.dismiss()
        } catch {
            guard transcriptionOperationID == operationID else { return }
            guard project?.id == currentProject.id else {
                transcriptionActivity.dismiss()
                return
            }
            let localizedError = error as? LocalizedError
            let message = localizedError?.errorDescription ?? "Transcription failed."
            transcriptionActivity.finish(success: false, message: message)
            exportMessage = message
        }
    }

    func translate() async {
        guard let currentProject = project, !isTranslating else {
            return
        }

        guard !currentProject.subtitles.isEmpty else {
            exportMessage = TranslationPipelinePresentation.message(for: .noSubtitles)
            return
        }

        let operationID = UUID()
        translationOperationID = operationID
        isTranslating = true
        defer {
            if translationOperationID == operationID {
                translationOperationID = nil
                isTranslating = false
            }
        }
        let projectID = currentProject.id

        do {
            let output = try await projectTranslator.translate(
                TranslationPipelineRequest(project: currentProject),
                events: { [weak self] event in
                    self?.handleTranslationEvent(
                        event,
                        projectID: projectID,
                        operationID: operationID
                    )
                }
            )
            guard translationOperationID == operationID,
                  project?.id == projectID else { return }
            applyProject(output.project)
        } catch is CancellationError {
            return
        } catch {
            guard translationOperationID == operationID,
                  project?.id == projectID else { return }
            exportMessage = TranslationPipelinePresentation.message(for: error)
        }
    }

    private func handlePreparationEvent(
        _ event: ProjectPreparationEvent,
        projectID: UUID,
        operationID: UUID
    ) {
        guard project?.id == projectID,
              preparationOperationID == operationID else { return }
        switch event {
        case .projectChanged(let project):
            applyProject(project)
        case .progress(let progress):
            if let fractionCompleted = progress.fractionCompleted {
                projectPreparationProgress = fractionCompleted
            }
            projectPreparationStatus = ProjectPreparationPresentation.status(for: progress)
        }
    }

    private func handleTranscriptionEvent(
        _ event: TranscriptionPipelineEvent,
        projectID: UUID,
        operationID: UUID
    ) {
        guard project?.id == projectID,
              transcriptionOperationID == operationID else { return }
        switch event {
        case .projectChanged(let project):
            applyProject(project)
        case .progress(let progress):
            transcriptionActivity.update(
                statusText: TranscriptionPipelinePresentation.status(for: progress),
                progress: progress.fractionCompleted
            )
        }
    }

    private func handleTranslationEvent(
        _ event: TranslationPipelineEvent,
        projectID: UUID,
        operationID: UUID
    ) {
        guard project?.id == projectID,
              translationOperationID == operationID else { return }
        applyProject(event.project)
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
            try await subtitleExportService.export(
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
            let request = SubtitleDocumentPickerRequest(
                allowedFileExtensions: SubtitleFileFormat.allSupportedExtensions
            )
            switch await subtitleDocumentPicker.pick(request) {
            case .selected(let fileURL):
                await previewSubtitleImport(from: fileURL)
            case .cancelled:
                return
            case .failed(let failure):
                subtitleImportErrorMessage = failure.message
            }
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

        let result = session.replaceSubtitlesFromTimeline(currentProject.subtitles)
        if let firstID = currentProject.subtitles.first?.id {
            session.selectCue(id: firstID, extending: false, toggling: false)
        }
        autosaveErrorMessage = nil
        subtitleImportPreview = nil
        present(result)
    }

    func saveProject() async {
        guard let project else {
            exportMessage = "No project selected."
            return
        }

        await session.save()
        if case .saved = session.snapshot.persistence {
            projectCatalog.register(project)
            autosaveErrorMessage = nil
            exportMessage = "Project saved."
        } else {
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

    private func applyProject(_ project: Project) {
        guard let expectedID = self.project?.id else { return }
        _ = session.installEffectOutput(project, expectedProjectID: expectedID)
    }

    private func present(_ result: ProjectSessionEditResult) {
        autosaveErrorMessage = result.message
    }

    func timelineDurationMs(for project: Project) -> Int {
        session.timelineDurationMs()
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
        let result = session.addShort(startMs: startMs, endMs: endMs, title: title)
        present(result)
        return result.selectedID
    }

    func addShortAtPlayhead() {
        present(session.addShortAtPlayhead())
    }

    /// Creates a short spanning all selected cues and asks the UI to switch to
    /// Shorts mode. A normal single-row selection remains a one-cue range.
    func createShortFromSelectedCues() {
        let result = session.createShortFromSelectedCues()
        exportMessage = result.message
        if result.didChange { shortsFocusRequest += 1 }
    }

    func beginInteractiveShortEdit() {
        session.beginInteraction(named: "short-edit")
    }

    func endInteractiveShortEdit(undoActionName: String) {
        session.endInteraction(named: "short-edit")
    }

    func updateShort(
        id: UUID,
        undoActionName: String? = nil,
        mutate: (inout ShortDefinition) -> Void
    ) {
        guard var short = project?.shorts.first(where: { $0.id == id }) else { return }
        mutate(&short)
        present(session.replaceShort(short))
    }

    func updateShortRange(id: UUID, startMs: Int, endMs: Int) {
        present(session.updateShortRange(id: id, startMs: startMs, endMs: endMs))
    }

    func setSelectedShortStartToPlayhead() {
        exportMessage = session.setSelectedShortStartToPlayhead().message
    }

    func setSelectedShortEndToPlayhead() {
        exportMessage = session.setSelectedShortEndToPlayhead().message
    }

    /// In the selected range this edits its start. Outside the selected range
    /// (or without a selection) it marks the start of a new short, completed by
    /// the matching Set End command in the Shorts timeline toolbar.
    func setShortStartFromPlayhead() {
        exportMessage = session.setShortStartFromPlayhead().message
    }

    func setShortEndFromPlayhead() {
        exportMessage = session.setShortEndFromPlayhead().message
    }

    func clearPendingShortRange() {
        session.clearPendingShortRange()
    }

    func deleteSelectedShort() {
        guard let shortsSelectedShortID else {
            return
        }
        deleteShort(id: shortsSelectedShortID)
    }

    func addCropPointAtPlayhead(shortID: UUID) {
        exportMessage = session.addCropPointAtPlayhead(shortID: shortID).message
    }

    func updateShortCropOffset(
        id: UUID,
        timelineTimeMs: Int,
        offsetX: Double
    ) {
        present(session.updateShortCropOffset(id: id, timelineTimeMs: timelineTimeMs, offsetX: offsetX))
    }

    func deleteShortCropKeyframe(shortID: UUID, keyframeID: UUID) {
        present(session.deleteShortCropKeyframe(shortID: shortID, keyframeID: keyframeID))
    }

    func deleteShort(id: UUID) {
        present(session.deleteShort(id: id))
    }

    func updateShortsExportSettings(_ settings: ShortsExportSettings) {
        present(session.updateShortsExportSettings(settings))
    }

    func updateShortsSubtitleStyle(
        _ style: VideoExportSettings,
        registerUndo: Bool = true
    ) {
        present(session.updateShortsSubtitleStyle(style, undoable: registerUndo))
    }

    func beginInteractiveShortsSubtitleStyleEdit() {
        session.beginInteraction(named: "shorts-subtitle-style")
    }

    func endInteractiveShortsSubtitleStyleEdit(
        undoActionName: String = "Edit Shorts Subtitle Style"
    ) {
        session.endInteraction(named: "shorts-subtitle-style")
    }

    func generateShortsSuggestions() {
        session.generateShortsSuggestions()
    }

    func acceptShortSuggestion(_ suggestion: ShortSuggestion) {
        present(session.acceptShortSuggestion(id: suggestion.id))
    }

    func dismissShortSuggestion(_ suggestion: ShortSuggestion) {
        session.dismissShortSuggestion(id: suggestion.id)
    }

    func exportShorts(_ shorts: [ShortDefinition], to destinationDirectory: URL) {
        guard let project, !shorts.isEmpty else {
            return
        }

        let items = ShortsExportPlanner().plan(ShortsExportPlanningInput(
            projectName: project.displayName,
            shorts: shorts,
            settings: project.shortsExportSettings,
            encodingSettings: project.videoExportSettings,
            editTimeline: project.editTimeline,
            subtitles: project.subtitles,
            sourceInfo: videoSourceInfo,
            destinationDirectory: destinationDirectory
        ))
        videoExportQueue.enqueue(ShortsVideoExportBatchRequest(
            projectID: project.id,
            mediaURL: project.mediaFile.originalURL,
            speakerLabels: project.speakerLabels,
            speakerExportOptions: project.speakerExportOptions,
            items: items
        ))
    }

}
