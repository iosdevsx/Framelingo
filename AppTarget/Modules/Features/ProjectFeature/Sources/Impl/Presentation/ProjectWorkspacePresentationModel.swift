import Combine
import ExportFeature
import Foundation
import Project
import ProjectFeature
import ProjectPreparation
import ProjectSession
import Shorts
import Subtitles
import SubtitleEditorFeature
import Timeline
import VideoExport
import VideoRendering

/// macOS presentation state for a project workspace. Document ownership,
/// history, processing, import, export, and persistence stay in ProjectSession.
@MainActor
final class ProjectWorkspacePresentationModel: ObservableObject {
    var sessionSnapshot: ProjectSessionSnapshot { session.snapshot }
    var subtitleEditingPort: any ProjectSessionSubtitleEditing { session }
    var selectionPlaybackPort: any ProjectSessionSelectionPlaybackEditing { session }
    var timelineEditingPort: any ProjectSessionTimelineEditing { session }
    var shortsEditingPort: any ProjectSessionShortsEditing { session }
    var historyPort: any ProjectSessionHistoryControlling { session }
    var sessionObservingPort: any ProjectSessionObserving { session }
    var project: Project? { session.snapshot.project }

    @Published var exportMessage: String?
    @Published var subtitleImportPreview: SubtitleImportPreview?
    @Published var subtitleImportErrorMessage: String?
    @Published var shortsFocusRequest = 0

    var autosaveErrorMessage: String? {
        if case .failed = session.snapshot.persistence { "Autosave failed." } else { nil }
    }
    var isTranscribing: Bool {
        if case .running = session.snapshot.effects.transcription { true } else { false }
    }
    var isTranslating: Bool {
        if case .running = session.snapshot.effects.translation { true } else { false }
    }
    var isImportingSubtitles: Bool {
        if case .loading = session.snapshot.effects.subtitleImport { true } else { false }
    }
    var waveformPeaks: [Double] { session.snapshot.effects.derivedMedia.waveformPeaks }
    var videoSourceInfo: VideoSourceInfo? { session.snapshot.effects.derivedMedia.videoSourceInfo }
    var isPreparingProject: Bool {
        if case .running = session.snapshot.effects.preparation { true } else { false }
    }
    var projectPreparationProgress: Double {
        switch session.snapshot.effects.preparation {
        case .idle: 0
        case .running(let progress): progress?.fractionCompleted ?? 0.02
        case .completed, .failed: 1
        }
    }
    var projectPreparationStatus: String {
        switch session.snapshot.effects.preparation {
        case .idle: "Preparing project..."
        case .running(let progress):
            progress.map(ProjectPreparationPresentation.status(for:)) ?? "Preparing project..."
        case .completed(let outcome): ProjectPreparationPresentation.status(for: outcome)
        case .failed: "Project ready. Waveform unavailable."
        }
    }

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
    var editRangeStartMs: Int? { session.snapshot.interaction.timeline.rangeStartMs }
    var editRangeEndMs: Int? { session.snapshot.interaction.timeline.rangeEndMs }
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
    var selectedShort: ShortDefinition? {
        guard let id = shortsSelectedShortID else { return nil }
        return project?.shorts.first(where: { $0.id == id })
    }
    var canUndo: Bool { session.snapshot.history.canUndo }
    var canRedo: Bool { session.snapshot.history.canRedo }

    private let session: any ProjectSessionWorkspace
    private let subtitleDocumentPicker: SubtitleDocumentPicker
    private var sessionSubscription: AnyCancellable?
    private var lastEffects: ProjectSessionEffectsState = .empty

    init(dependencies: ProjectFeatureDependencies) {
        session = dependencies.session
        subtitleDocumentPicker = dependencies.subtitleDocumentPicker
        lastEffects = session.snapshot.effects
        synchronizePresentation(with: session.snapshot.effects)
        sessionSubscription = session.snapshots.dropFirst().sink { [weak self] snapshot in
            guard let self else { return }
            self.objectWillChange.send()
            self.synchronizePresentation(with: snapshot.effects)
        }
    }

    func loadSelectedProject() {}

    func prepareProjectForEditing() {
        Task { await session.prepare() }
    }

    func transcribe() async { await session.transcribe() }
    func translate() async { await session.translate() }
    func undo() { session.undo() }
    func redo() { session.redo() }
    func beginSubtitleTextEdit(id: UUID) { session.beginInteraction(named: "subtitle-text") }
    func endSubtitleTextEdit() { session.endInteraction(named: "subtitle-text") }
    func updateSpeakerLabel(id: Int, displayName: String) {
        present(session.updateSpeakerLabel(id: id, displayName: displayName))
    }
    func selectSegment(id: UUID?) {
        session.selectCue(id: id, extending: false, toggling: false)
    }
    func seekTo(ms: Int) { session.seek(to: ms) }
    func ensureEditTimeline() { present(session.ensureTimeline()) }
    func resolvedEditTimeline(for project: Project) -> EditTimeline? { session.resolvedTimeline() }
    func deleteSelectedClip() { present(session.deleteSelectedClip()) }
    func timelineTimeToSourceTime(_ timelineMs: Int) -> Int? {
        session.sourceTime(forTimelineTime: timelineMs)
    }
    func editClip(atTimelineTime timelineMs: Int) -> TimelineClip? {
        session.clip(atTimelineTime: timelineMs)
    }
    func editPlaybackAdvance(
        sourceTimeMs: Int,
        currentClipID: UUID?
    ) -> EditTimelinePlaybackAdvance? {
        session.playbackAdvance(sourceTimeMs: sourceTimeMs, currentClipID: currentClipID)
    }
    func seekTimeline(to ms: Int) { session.seekTimeline(to: ms) }
    func playTimeline() { session.setTimelinePlaybackEnabled(true) }
    func pauseTimeline() { session.setTimelinePlaybackEnabled(false) }
    func timelineDurationMs(for project: Project) -> Int { session.timelineDurationMs() }

    func suggestedExportFileName(for kind: SubtitleExportKind) -> String {
        let baseName = project?.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        let safeBaseName = (baseName?.isEmpty == false ? baseName : "subtitles") ?? "subtitles"
        return "\(safeBaseName).\(kind.fileExtension)"
    }

    func importSubtitlesFromFile() {
        Task {
            switch await subtitleDocumentPicker.pick(SubtitleDocumentPickerRequest(
                allowedFileExtensions: SubtitleFileFormat.allSupportedExtensions
            )) {
            case .selected(let url): await session.previewSubtitleImport(from: url)
            case .cancelled: return
            case .failed(let failure): subtitleImportErrorMessage = failure.message
            }
        }
    }

    func applySubtitleImport(
        _ preview: SubtitleImportPreview,
        mode: SubtitleImportMode,
        destination: SubtitleImportDestination = .original
    ) {
        present(session.applySubtitleImport(
            preview,
            mode: mode,
            destination: destination
        ))
    }

    func saveProject() async {
        await session.save()
        exportMessage = if case .saved = session.snapshot.persistence {
            "Project saved."
        } else {
            "Project save failed."
        }
    }

    func exportSubtitles(kind: SubtitleExportKind, to url: URL) async {
        await session.exportSubtitles(kind: kind, to: url)
    }

    func exportProjectFile(to url: URL) {
        Task { await session.exportProject(to: url) }
    }

    func submitVideoExport(_ submission: VideoExportSubmission) {
        session.enqueueVideoExport(
            settings: submission.settings,
            outputURL: submission.outputURL
        )
    }

    func exportShorts(_ shorts: [ShortDefinition], to directoryURL: URL) {
        session.enqueueShortsExport(shortIDs: shorts.map(\.id), to: directoryURL)
    }

    private func synchronizePresentation(with effects: ProjectSessionEffectsState) {
        defer { lastEffects = effects }
        guard effects != lastEffects else { return }

        if effects.preparation != lastEffects.preparation,
           case .failed(let failure) = effects.preparation {
            exportMessage = message(for: failure)
        }
        if effects.transcription != lastEffects.transcription,
           case .failed(let failure) = effects.transcription {
            exportMessage = message(for: failure)
        }
        if effects.translation != lastEffects.translation,
           case .failed(let failure) = effects.translation {
            exportMessage = message(for: failure)
        }

        switch effects.subtitleImport {
        case .preview(let preview):
            subtitleImportPreview = preview
            subtitleImportErrorMessage = nil
        case .failed(let failure):
            subtitleImportPreview = nil
            subtitleImportErrorMessage = message(for: failure)
        case .idle:
            subtitleImportPreview = nil
        case .loading:
            subtitleImportErrorMessage = nil
        }

        guard effects.export != lastEffects.export else { return }
        switch effects.export {
        case .completed(.subtitleExport, _):
            exportMessage = "Subtitles exported successfully."
        case .completed(.projectExport, let url):
            exportMessage = "Project saved to:\n\(url.path)"
        case .failed(let failure):
            exportMessage = message(for: failure)
        case .idle, .running, .queued, .completed:
            break
        }
    }

    private func present(_ result: ProjectSessionEditResult) {
        if let message = result.message { exportMessage = message }
    }

    private func message(for failure: ProjectSessionEffectFailure) -> String {
        if let diagnostic = failure.diagnostic, !diagnostic.isEmpty { return diagnostic }
        return switch (failure.kind, failure.reason) {
        case (_, .noActiveProject): "No project selected."
        case (.translation, .noSubtitles): "No subtitles to translate."
        case (.subtitleImport, _): "Subtitle import failed."
        case (.subtitleExport, _): "Export failed."
        case (.projectExport, _): "Project file export failed."
        case (.transcription, _): "Transcription failed."
        case (.translation, _): "Translation failed."
        case (.preparation, _): "Project preparation failed."
        case (.videoExport, _), (.shortsExport, _): "Video export failed."
        }
    }
}
