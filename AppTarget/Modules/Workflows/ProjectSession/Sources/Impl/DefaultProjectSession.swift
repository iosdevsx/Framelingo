import Combine
import Foundation
import Project
import ProjectSession
import Timeline

enum ProjectSessionHistoryPolicy: Sendable {
    case none
    case undoable
}

enum ProjectSessionPersistencePolicy: Sendable {
    case none
    case autosave
}

struct ProjectSessionTransactionMetadata: Sendable {
    let history: ProjectSessionHistoryPolicy
    let persistence: ProjectSessionPersistencePolicy
    let eventKind: ProjectSessionDocumentChangeKind

    static let undoable = ProjectSessionTransactionMetadata(
        history: .undoable,
        persistence: .autosave,
        eventKind: .changed
    )
}

@MainActor
public final class DefaultProjectSession: ProjectSessionWorkspace {
    public private(set) var snapshot: ProjectSessionSnapshot {
        didSet { snapshotSubject.send(snapshot) }
    }

    public var snapshots: AnyPublisher<ProjectSessionSnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }

    public var activeProjectID: UUID? { project?.id }

    private(set) var project: Project?
    private(set) var interactionState: ProjectSessionInteractionState = .empty
    private(set) var effectsState: ProjectSessionEffectsState = .empty
    private var history: ProjectSessionHistory
    private var persistenceState: ProjectSessionPersistenceState = .idle
    private var generation: UInt = 0
    private var preparationGeneration: UInt = 0
    private var transcriptionGeneration: UInt = 0
    private var translationGeneration: UInt = 0
    private var importGeneration: UInt = 0
    private var exportGeneration: UInt = 0
    private var preparationTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?
    private var isDisposed = false
    private let documentChangeSink: ProjectSessionDocumentChangeSink
    private let now: @MainActor () -> Date
    private let autosave: ProjectAutosaveCoordinator
    private let snapshotSubject: CurrentValueSubject<ProjectSessionSnapshot, Never>
    let editTimelineService: (any EditTimelineEditing)?
    let effectDependencies: ProjectSessionEffectDependencies?

    public init(dependencies: ProjectSessionDependencies) {
        let initialSnapshot = ProjectSessionSnapshot(
            project: nil,
            history: .empty,
            persistence: .idle
        )
        snapshot = initialSnapshot
        snapshotSubject = CurrentValueSubject(initialSnapshot)
        history = ProjectSessionHistory(limit: dependencies.historyLimit)
        documentChangeSink = dependencies.documentChangeSink
        now = dependencies.now
        autosave = ProjectAutosaveCoordinator(
            repository: dependencies.repository,
            delay: dependencies.autosaveDelay,
            sleeper: dependencies.sleeper
        )
        editTimelineService = dependencies.editTimelineService
        effectDependencies = dependencies.effects
    }

    public func open(_ project: Project) {
        guard !isDisposed else { return }
        resetProjectScopedEffects()
        autosave.invalidate()
        history.reset()
        generation &+= 1
        self.project = project
        interactionState = .empty
        effectsState = .empty
        persistenceState = .idle
        publishSnapshot()
        sendDocumentEvent(kind: .opened)
    }

    public func close() {
        guard project != nil else { return }
        resetProjectScopedEffects()
        autosave.invalidate()
        history.reset()
        generation &+= 1
        project = nil
        interactionState = .empty
        effectsState = .empty
        persistenceState = .idle
        publishSnapshot()
        sendDocumentEvent(kind: .closed)
    }

    public func replace(with project: Project) {
        open(project)
    }

    public func dispose() {
        guard !isDisposed else { return }
        close()
        resetProjectScopedEffects()
        autosave.invalidate()
        isDisposed = true
    }

    public func undo() {
        guard let current = currentDocumentState,
              let previous = history.undo(current: current) else { return }

        _ = install(
            candidate: previous.project,
            interaction: previous.interaction,
            metadata: ProjectSessionTransactionMetadata(
                history: .none,
                persistence: .autosave,
                eventKind: .undo
            )
        )
    }

    public func redo() {
        guard let current = currentDocumentState,
              let next = history.redo(current: current) else { return }

        _ = install(
            candidate: next.project,
            interaction: next.interaction,
            metadata: ProjectSessionTransactionMetadata(
                history: .none,
                persistence: .autosave,
                eventKind: .redo
            )
        )
    }

    public func beginInteraction(named name: String) {
        guard let project else { return }
        history.beginInteraction(
            named: name,
            state: ProjectSessionHistory.DocumentState(
                project: project,
                interaction: interactionState
            )
        )
    }

    public func endInteraction(named name: String) {
        guard let project,
              history.endInteraction(
                named: name,
                currentState: ProjectSessionHistory.DocumentState(
                    project: project,
                    interaction: interactionState
                )
              ) else { return }
        publishSnapshot()
    }

    public func save() async {
        guard let project else { return }
        await autosave.saveNow(
            project: project,
            generation: generation,
            stateHandler: persistenceStateHandler
        )
    }

    @discardableResult
    func install(
        candidate: Project,
        interaction proposedInteraction: ProjectSessionInteractionState? = nil,
        metadata: ProjectSessionTransactionMetadata = .undoable,
        validate: (Project) -> Bool = { _ in true }
    ) -> Bool {
        guard let previous = project,
              candidate.id == previous.id,
              validate(candidate) else {
            return false
        }

        var installed = candidate
        installed.updatedAt = previous.updatedAt
        guard installed != previous else { return false }

        if case .undoable = metadata.history {
            history.record(previous: ProjectSessionHistory.DocumentState(
                project: previous,
                interaction: interactionState
            ))
        }

        installed.updatedAt = now()
        project = installed
        interactionState = reconciledInteraction(
            proposedInteraction ?? interactionState,
            for: installed
        )
        persistenceState = .idle
        publishSnapshot()
        sendDocumentEvent(kind: metadata.eventKind)

        if case .autosave = metadata.persistence {
            autosave.schedule(
                project: installed,
                generation: generation,
                stateHandler: persistenceStateHandler
            )
        }
        return true
    }

    @discardableResult
    func updateInteraction(_ candidate: ProjectSessionInteractionState) -> Bool {
        guard let project else { return false }
        let reconciled = reconciledInteraction(candidate, for: project)
        guard reconciled != interactionState else { return false }
        interactionState = reconciled
        publishSnapshot()
        return true
    }

    private var persistenceStateHandler: ProjectAutosaveCoordinator.StateHandler {
        { [weak self] token, state in
            guard let self,
                  self.project?.id == token.projectID,
                  self.generation == token.generation else { return }
            self.persistenceState = state
            self.publishSnapshot()
        }
    }

    private func publishSnapshot() {
        snapshot = ProjectSessionSnapshot(
            project: project,
            history: ProjectSessionHistoryState(
                canUndo: history.canUndo,
                canRedo: history.canRedo
            ),
            persistence: persistenceState,
            interaction: interactionState,
            effects: effectsState
        )
    }

    func publishEffects(_ state: ProjectSessionEffectsState) {
        effectsState = state
        publishSnapshot()
    }

    func updateEffects(
        preparation: ProjectSessionPreparationState? = nil,
        transcription: ProjectSessionTranscriptionState? = nil,
        translation: ProjectSessionTranslationState? = nil,
        subtitleImport: ProjectSessionImportState? = nil,
        export: ProjectSessionExportState? = nil,
        derivedMedia: ProjectSessionDerivedMediaState? = nil
    ) {
        publishEffects(ProjectSessionEffectsState(
            preparation: preparation ?? effectsState.preparation,
            transcription: transcription ?? effectsState.transcription,
            translation: translation ?? effectsState.translation,
            subtitleImport: subtitleImport ?? effectsState.subtitleImport,
            export: export ?? effectsState.export,
            derivedMedia: derivedMedia ?? effectsState.derivedMedia
        ))
    }

    func nextPreparationGeneration() -> UInt {
        preparationGeneration &+= 1
        preparationTask?.cancel()
        return preparationGeneration
    }

    func nextTranscriptionGeneration() -> UInt {
        transcriptionGeneration &+= 1
        transcriptionTask?.cancel()
        return transcriptionGeneration
    }

    func nextTranslationGeneration() -> UInt {
        translationGeneration &+= 1
        translationTask?.cancel()
        return translationGeneration
    }

    func nextImportGeneration() -> UInt {
        importGeneration &+= 1
        importTask?.cancel()
        return importGeneration
    }

    func nextExportGeneration() -> UInt {
        exportGeneration &+= 1
        exportTask?.cancel()
        return exportGeneration
    }

    func setPreparationTask(_ task: Task<Void, Never>?) { preparationTask = task }
    func setTranscriptionTask(_ task: Task<Void, Never>?) { transcriptionTask = task }
    func setTranslationTask(_ task: Task<Void, Never>?) { translationTask = task }
    func setImportTask(_ task: Task<Void, Never>?) { importTask = task }
    func setExportTask(_ task: Task<Void, Never>?) { exportTask = task }

    func matches(projectID: UUID, preparation token: UInt) -> Bool {
        project?.id == projectID && preparationGeneration == token && !isDisposed
    }

    func matches(projectID: UUID, transcription token: UInt) -> Bool {
        project?.id == projectID && transcriptionGeneration == token && !isDisposed
    }

    func matches(projectID: UUID, translation token: UInt) -> Bool {
        project?.id == projectID && translationGeneration == token && !isDisposed
    }

    func matches(projectID: UUID, importing token: UInt) -> Bool {
        project?.id == projectID && importGeneration == token && !isDisposed
    }

    func matches(projectID: UUID, exporting token: UInt) -> Bool {
        project?.id == projectID && exportGeneration == token && !isDisposed
    }

    func cancelPendingAutosaveForReplacingEffect() {
        autosave.invalidate()
    }

    private func resetProjectScopedEffects() {
        preparationGeneration &+= 1
        transcriptionGeneration &+= 1
        translationGeneration &+= 1
        importGeneration &+= 1
        exportGeneration &+= 1
        preparationTask?.cancel()
        transcriptionTask?.cancel()
        translationTask?.cancel()
        importTask?.cancel()
        exportTask?.cancel()
        preparationTask = nil
        transcriptionTask = nil
        translationTask = nil
        importTask = nil
        exportTask = nil
    }

    private var currentDocumentState: ProjectSessionHistory.DocumentState? {
        guard let project else { return nil }
        return ProjectSessionHistory.DocumentState(
            project: project,
            interaction: interactionState
        )
    }

    private func reconciledInteraction(
        _ state: ProjectSessionInteractionState,
        for project: Project
    ) -> ProjectSessionInteractionState {
        let cueIDs = Set(project.subtitles.map(\.id))
        var selectedCueIDs = state.cueSelection.selectedCueIDs.intersection(cueIDs)
        var primaryCueID = state.cueSelection.primaryCueID.flatMap {
            cueIDs.contains($0) ? $0 : nil
        }
        if let primaryCueID {
            selectedCueIDs.insert(primaryCueID)
        } else {
            primaryCueID = project.subtitles.first(where: { selectedCueIDs.contains($0.id) })?.id
        }
        let anchorCueID = state.cueSelection.anchorCueID.flatMap {
            cueIDs.contains($0) ? $0 : nil
        } ?? primaryCueID

        let playheadMs = max(state.playback.playheadMs, 0)
        let activeCueID = project.subtitles.first(where: {
            $0.startMs <= playheadMs && playheadMs < $0.endMs
        })?.id

        let clipIDs = Set(project.editTimeline?.clips.map(\.id) ?? [])
        let selectedClipID = state.timeline.selectedClipID.flatMap {
            clipIDs.contains($0) ? $0 : nil
        }

        let shortIDs = Set(project.shorts.map(\.id))
        let selectedShortID: UUID?
        if let requested = state.shorts.selectedShortID, shortIDs.contains(requested) {
            selectedShortID = requested
        } else if state.shorts.selectedShortID != nil {
            selectedShortID = project.shorts.first?.id
        } else {
            selectedShortID = nil
        }

        return ProjectSessionInteractionState(
            cueSelection: ProjectSessionCueSelectionState(
                primaryCueID: primaryCueID,
                selectedCueIDs: selectedCueIDs,
                anchorCueID: anchorCueID
            ),
            playback: ProjectSessionPlaybackState(
                playheadMs: playheadMs,
                activeCueID: activeCueID
            ),
            timeline: ProjectSessionTimelineInteractionState(
                selectedClipID: selectedClipID,
                rangeStartMs: state.timeline.rangeStartMs,
                rangeEndMs: state.timeline.rangeEndMs,
                isPlaybackEnabled: state.timeline.isPlaybackEnabled
            ),
            shorts: ProjectSessionShortsInteractionState(
                selectedShortID: selectedShortID,
                pendingRangeStartMs: state.shorts.pendingRangeStartMs,
                suggestions: state.shorts.suggestions,
                suggestionStatus: state.shorts.suggestionStatus
            )
        )
    }

    private func sendDocumentEvent(kind: ProjectSessionDocumentChangeKind) {
        documentChangeSink.send(ProjectSessionDocumentChangeEvent(
            kind: kind,
            projectID: project?.id,
            generation: generation
        ))
    }
}
