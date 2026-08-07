import AVFoundation
import Combine
import Foundation
import HomeFeature
import Observation
import PlayerFeature
import Project
import ProjectSession
import SubtitleEditorFeature
import Subtitles
import UniformTypeIdentifiers

enum IOSDocumentImportKind {
    case project
    case media
}

struct IOSProcessingPresentationState: Equatable {
    let title: String
    let detail: String?
    let fractionCompleted: Double?
    let isRunning: Bool

    static let idle = IOSProcessingPresentationState(
        title: "Ready",
        detail: nil,
        fractionCompleted: nil,
        isRunning: false
    )
}

@MainActor
@Observable
final class IOSAppModel {
    private(set) var snapshot: ProjectSessionSnapshot
    private(set) var recentProjects: [Project] = []
    private(set) var pendingImportKind: IOSDocumentImportKind?
    var isDocumentPickerPresented = false
    private(set) var preparedShareURL: URL?
    private(set) var isBusy = false
    private(set) var player: AVPlayer?
    private(set) var isPlaying = false
    private(set) var currentTimeMs = 0
    var errorMessage: String?

    var projectOpening: HomeProjectOpening {
        HomeProjectOpening { [weak self] project in
            self?.open(project)
        }
    }

    var openedProject: Project? { snapshot.project }

    var playerRequest: ProjectVideoPreviewRequest? {
        guard let project = openedProject else { return nil }
        return ProjectVideoPreviewRequest(
            state: ProjectVideoPreviewState(
                project: project,
                player: player,
                isPlaying: isPlaying,
                currentTimeMs: currentTimeMs,
                showsControls: true,
                videoSourceInfo: snapshot.effects.derivedMedia.videoSourceInfo
            ),
            actions: ProjectVideoPreviewActions(
                togglePlayback: { [weak self] in self?.togglePlayback() },
                seek: { [weak self] milliseconds in self?.seek(to: milliseconds) },
                updateSettings: { [weak self] settings, undoable in
                    _ = self?.session.updateVideoExportSettings(settings, undoable: undoable)
                }
            )
        )
    }

    var subtitleEditorState: SubtitleEditorState {
        let project = openedProject
        return SubtitleEditorState(
            subtitles: project?.subtitles ?? [],
            speakers: project?.speakers ?? [],
            speakerLabels: project?.speakerLabels ?? [],
            selectedSegmentID: snapshot.interaction.cueSelection.primaryCueID,
            selectedCueIDs: snapshot.interaction.cueSelection.selectedCueIDs,
            activeSegmentID: activeSubtitle?.id,
            autosaveErrorMessage: persistenceErrorMessage
        )
    }

    var subtitleEditorActions: SubtitleEditorActions {
        SubtitleEditorActions(
            selectSegment: { [weak self] id, extending, toggling in
                self?.session.selectCue(id: id, extending: extending, toggling: toggling)
            },
            updateSubtitle: { [weak self] segment in
                self?.updateSubtitle(segment) ?? SubtitleEditorUpdateResult(
                    segment: nil,
                    errorMessage: "The project is no longer open."
                )
            },
            addSegmentAfter: { [weak self] id in self?.session.addSegmentAfter(id: id).selectedID },
            splitSegment: { [weak self] id in self?.session.splitSegment(id: id).selectedID },
            mergeWithNextSegment: { [weak self] id in self?.session.mergeWithNextSegment(id: id).selectedID },
            deleteSegment: { [weak self] id in self?.session.deleteSegment(id: id).selectedID },
            createShortFromSelectedCues: {},
            beginTextEdit: { [weak self] id in
                self?.session.beginInteraction(named: "Edit subtitle \(id.uuidString)")
            },
            endTextEdit: { [weak self] in
                self?.session.endInteraction(named: "Edit subtitle")
            },
            currentErrorMessage: { [weak self] in self?.errorMessage }
        )
    }

    var activeSubtitle: SubtitleSegment? {
        openedProject?.subtitles.first {
            currentTimeMs >= $0.startMs && currentTimeMs < $0.endMs
        }
    }

    var processingPresentation: IOSProcessingPresentationState {
        switch snapshot.effects.transcription {
        case .running(let progress):
            return .init(
                title: "Transcribing",
                detail: progress?.providerDetail,
                fractionCompleted: progress?.fractionCompleted,
                isRunning: true
            )
        case .failed(let failure):
            return failurePresentation(failure)
        case .idle, .completed:
            break
        }

        switch snapshot.effects.translation {
        case .running:
            return .init(
                title: "Translating",
                detail: "Controlled iOS translation",
                fractionCompleted: nil,
                isRunning: true
            )
        case .failed(let failure):
            return failurePresentation(failure)
        case .idle, .completed:
            break
        }

        switch snapshot.effects.preparation {
        case .running(let progress):
            return .init(
                title: "Preparing media",
                detail: progress?.providerDetail,
                fractionCompleted: progress?.fractionCompleted,
                isRunning: true
            )
        case .failed(let failure):
            return failurePresentation(failure)
        case .idle, .completed:
            return .idle
        }
    }

    var allowedDocumentTypes: [UTType] {
        switch pendingImportKind {
        case .project: [.json]
        case .media: [.movie]
        case nil: [.data]
        }
    }

    @ObservationIgnored private let repository: any ProjectRepository
    @ObservationIgnored private let session: any ProjectSessionWorkspace
    @ObservationIgnored private let documentImporter: any IOSDocumentImporting
    @ObservationIgnored private let sharePreparer: any IOSProjectSharePreparing
    @ObservationIgnored private var snapshotSubscription: AnyCancellable?
    @ObservationIgnored private var playerTimeObserver: Any?

    init(
        repository: any ProjectRepository,
        session: any ProjectSessionWorkspace,
        documentImporter: any IOSDocumentImporting,
        sharePreparer: any IOSProjectSharePreparing
    ) {
        self.repository = repository
        self.session = session
        self.documentImporter = documentImporter
        self.sharePreparer = sharePreparer
        snapshot = session.snapshot
        snapshotSubscription = session.snapshots.sink { [weak self] snapshot in
            self?.snapshot = snapshot
        }
    }

    func loadRecentProjects() async {
        do {
            recentProjects = try await repository.listProjects()
        } catch {
            errorMessage = "Could not load saved projects. \(error.localizedDescription)"
        }
    }

    func open(_ project: Project) {
        session.open(project)
        installPlayer(for: project)
        preparedShareURL = nil
        errorMessage = nil
    }

    func openRecentProject(id: UUID) async {
        do {
            open(try await repository.loadProject(id: id))
        } catch {
            errorMessage = "Could not open the project. \(error.localizedDescription)"
        }
    }

    func requestProjectImport() {
        pendingImportKind = .project
        isDocumentPickerPresented = true
    }

    func requestMediaImport() {
        pendingImportKind = .media
        isDocumentPickerPresented = true
    }

    func handleDocumentSelection(_ result: Result<[URL], any Error>) async {
        defer {
            pendingImportKind = nil
            isDocumentPickerPresented = false
            isBusy = false
        }

        switch IOSDocumentPickerAdapter.outcome(from: result) {
        case .cancelled:
            return
        case .failed(let error):
            errorMessage = "The document picker failed. \(error.localizedDescription)"
        case .selected(let url):
            guard let pendingImportKind else { return }
            isBusy = true
            do {
                let project: Project
                switch pendingImportKind {
                case .project:
                    project = try await documentImporter.importProject(from: url)
                    try await repository.saveProject(project)
                case .media:
                    let mediaFile = try await documentImporter.importMedia(from: url)
                    project = try await repository.createProject(for: mediaFile)
                }
                open(project)
                await loadRecentProjects()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func saveProject() async {
        await session.save()
        if case .failed = snapshot.persistence {
            errorMessage = "The project could not be saved."
        }
    }

    func prepareProjectShare() async {
        guard let project = openedProject else { return }
        do {
            preparedShareURL = try await sharePreparer.prepare(project)
        } catch {
            errorMessage = "The project could not be prepared for sharing. \(error.localizedDescription)"
        }
    }

    func prepareMedia() async {
        await session.prepare()
    }

    func transcribe() async {
        await session.transcribe()
    }

    func translate() async {
        await session.translate()
    }

    func closeWorkspace() async {
        removePlayer()
        session.close()
        preparedShareURL = nil
        await documentImporter.releaseAllResources()
    }

    func sceneDidClose() async {
        removePlayer()
        session.dispose()
        await documentImporter.releaseAllResources()
    }

    func togglePlayback() {
        guard let player else {
            errorMessage = "The project video is unavailable."
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func seek(to milliseconds: Int) {
        let duration = openedProject?.mediaFile.durationMs ?? Int.max
        let target = min(max(milliseconds, 0), max(duration, 0))
        currentTimeMs = target
        player?.seek(to: CMTime(value: CMTimeValue(target), timescale: 1_000))
        session.seek(to: target)
    }

    private var persistenceErrorMessage: String? {
        guard case .failed = snapshot.persistence else { return nil }
        return "Project changes could not be saved."
    }

    private func failurePresentation(
        _ failure: ProjectSessionEffectFailure
    ) -> IOSProcessingPresentationState {
        let detail: String
        switch failure.reason {
        case .capabilityUnavailable:
            detail = "This processing capability is unavailable in the current iOS composition."
        case .noActiveProject:
            detail = "Open a project before starting processing."
        case .noSubtitles:
            detail = "Transcribe or add subtitles before translating."
        case .invalidInput:
            detail = "The project does not contain valid input for this action."
        case .operationFailed:
            detail = failure.diagnostic ?? "The processing operation failed."
        }
        return .init(
            title: "Processing failed",
            detail: detail,
            fractionCompleted: nil,
            isRunning: false
        )
    }

    private func updateSubtitle(_ segment: SubtitleSegment) -> SubtitleEditorUpdateResult {
        let result = session.updateSubtitle(segment)
        if let message = result.message {
            errorMessage = message
        }
        let installed = snapshot.project?.subtitles.first(where: { $0.id == segment.id })
        return SubtitleEditorUpdateResult(segment: installed, errorMessage: result.message)
    }

    private func installPlayer(for project: Project) {
        removePlayer()
        let player = AVPlayer(url: project.mediaFile.originalURL)
        self.player = player
        let interval = CMTime(value: 1, timescale: 10)
        playerTimeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            // AVPlayer owns this callback; explicitly re-enter the UI actor.
            Task { @MainActor [weak self] in
                guard time.isNumeric else { return }
                let milliseconds = time.seconds * 1_000
                guard milliseconds.isFinite else { return }
                self?.currentTimeMs = max(0, Int(milliseconds.rounded()))
            }
        }
    }

    private func removePlayer() {
        if let playerTimeObserver, let player {
            player.removeTimeObserver(playerTimeObserver)
        }
        player?.pause()
        playerTimeObserver = nil
        player = nil
        isPlaying = false
        currentTimeMs = 0
    }
}
