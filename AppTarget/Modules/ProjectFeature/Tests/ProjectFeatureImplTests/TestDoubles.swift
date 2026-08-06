import Application
import Combine
import ExportFeature
import Foundation
import Media
import PlayerFeature
import Project
import ProjectFeature
import ProjectPreparation
import TranscriptionPipeline
import TranslationPipeline
import Settings
import SpeakerAnalysis
import SpeechToText
import ShortsFeature
import Subtitles
import SubtitleEditorFeature
import SwiftUI
import Timeline
import TimelineFeature
import Translation
import VideoRendering
import VideoExport

@testable import ProjectFeatureImpl

enum TestDoubles {
    @MainActor
    private static var repositoriesByAppState: [ObjectIdentifier: Repository] = [:]
    @MainActor
    private static var catalogsByAppState: [ObjectIdentifier: Catalog] = [:]
    @MainActor
    private static var selectionsByAppState: [ObjectIdentifier: Selection] = [:]
    @MainActor
    private static var exportQueuesByAppState: [ObjectIdentifier: ExportQueue] = [:]

    @MainActor
    final class ExportQueue: VideoExportQueue {
        private let subject = CurrentValueSubject<[VideoExport.VideoExportJob], Never>([])
        private(set) var jobs: [VideoExport.VideoExportJob] = [] {
            didSet { subject.send(jobs) }
        }
        var jobSnapshots: AnyPublisher<[VideoExport.VideoExportJob], Never> {
            subject.eraseToAnyPublisher()
        }

        func enqueue(_ request: VideoExportRequest) {
            jobs.insert(VideoExport.VideoExportJob(
                id: request.id,
                projectName: request.projectName,
                outputURL: request.outputURL,
                status: .queued,
                statusText: "Queued",
                progress: nil
            ), at: 0)
        }

        func enqueue(_ batch: ShortsVideoExportBatchRequest) {
            for item in batch.items {
                let failure: VideoExportFailure?
                let status: VideoExport.VideoExportJobStatus
                switch item.outcome {
                case .valid:
                    failure = nil
                    status = .queued
                case .invalid(let error):
                    failure = VideoExportFailure(
                        code: .emptyTimeline,
                        message: error.errorDescription ?? "Invalid Short"
                    )
                    status = .failed
                }
                jobs.insert(VideoExport.VideoExportJob(
                    id: item.id,
                    projectName: item.displayName,
                    outputURL: item.outputURL,
                    status: status,
                    statusText: status == .failed ? "Export failed" : "Queued",
                    progress: nil,
                    failure: failure
                ), at: 0)
            }
        }

        func removeFinishedJob(id: UUID) {
            jobs.removeAll { $0.id == id && $0.isFinished }
        }
    }

    @MainActor
    private final class Selection {
        let subject: CurrentValueSubject<Project?, Never>

        init(project: Project?) {
            subject = CurrentValueSubject(project)
        }

        var access: ProjectSelectionAccess {
            ProjectSelectionAccess(
                current: { [weak self] in self?.subject.value },
                updates: { [weak self] in
                    self?.subject.eraseToAnyPublisher()
                        ?? Empty<Project?, Never>().eraseToAnyPublisher()
                },
                update: { [weak self] in self?.subject.send($0) },
                close: { [weak self] in self?.subject.send(nil) }
            )
        }
    }

    enum TestError: LocalizedError {
        case expected

        var errorDescription: String? { "Expected test failure." }
    }

    final class Repository: ProjectRepository {
        var projects: [UUID: Project] = [:]
        var savedProjects: [Project] = []

        func createProject(for mediaFile: MediaFile) async throws -> Project {
            throw TestError.expected
        }

        func saveProject(_ project: Project) async throws {
            projects[project.id] = project
            savedProjects.append(project)
        }

        func loadProject(id: UUID) async throws -> Project {
            guard let project = projects[id] else { throw TestError.expected }
            return project
        }

        func listProjects() async throws -> [Project] {
            Array(projects.values)
        }

        func deleteProject(id: UUID) async throws {
            projects[id] = nil
        }
    }

    final class Transcriber: TranscribingProject {
        var requests: [TranscriptionPipelineRequest] = []
        var events: [TranscriptionPipelineEvent] = []
        var output: TranscriptionPipelineOutput?
        var error: Error?

        init(
            output: TranscriptionPipelineOutput? = nil,
            error: Error? = nil,
            events: [TranscriptionPipelineEvent] = []
        ) {
            self.output = output
            self.error = error
            self.events = events
        }

        func transcribe(
            _ request: TranscriptionPipelineRequest,
            events handler: @escaping TranscriptionPipelineEventHandler
        ) async throws -> TranscriptionPipelineOutput {
            requests.append(request)
            for event in events {
                await handler(event)
            }
            if let error { throw error }
            if let output { return output }
            var project = request.project
            project.status = .ready
            await handler(.projectChanged(project))
            return TranscriptionPipelineOutput(project: project, warning: nil)
        }
    }

    @MainActor
    final class Catalog: ProjectCatalogManaging {
        private(set) var snapshot: ProjectCatalogSnapshot
        var snapshots: AnyPublisher<ProjectCatalogSnapshot, Never> {
            subject.eraseToAnyPublisher()
        }

        private let repository: any ProjectRepository
        private let subject: CurrentValueSubject<ProjectCatalogSnapshot, Never>
        private(set) var registeredProjects: [Project] = []

        init(repository: any ProjectRepository, projects: [Project] = []) {
            self.repository = repository
            snapshot = ProjectCatalogSnapshot(
                summaries: projects.map(ProjectSummary.init)
            )
            subject = CurrentValueSubject(snapshot)
        }

        func refresh() async {
            do {
                let projects = try await repository.listProjects()
                snapshot = ProjectCatalogSnapshot(
                    summaries: projects
                        .map(ProjectSummary.init)
                        .sorted { $0.updatedAt > $1.updatedAt }
                )
                subject.send(snapshot)
            } catch {
                snapshot = ProjectCatalogSnapshot(
                    summaries: snapshot.summaries,
                    failure: ProjectCatalogFailure(
                        operation: .refresh,
                        message: error.localizedDescription
                    )
                )
                subject.send(snapshot)
            }
        }

        func register(_ project: Project) {
            registeredProjects.append(project)
            var summaries = snapshot.summaries.filter { $0.id != project.id }
            summaries.append(ProjectSummary(project: project))
            snapshot = ProjectCatalogSnapshot(
                summaries: summaries.sorted { $0.updatedAt > $1.updatedAt }
            )
            subject.send(snapshot)
        }

        func open(id: UUID) async throws -> Project {
            try await repository.loadProject(id: id)
        }

        func delete(id: UUID) async throws -> UUID {
            try await repository.deleteProject(id: id)
            snapshot = ProjectCatalogSnapshot(
                summaries: snapshot.summaries.filter { $0.id != id }
            )
            subject.send(snapshot)
            return id
        }
    }

    struct TranslationService: TranslationOrchestrating {
        func translateSubtitles(
            _ input: SubtitleTranslationInput
        ) async throws -> SubtitleTranslationResult {
            SubtitleTranslationResult(segments: input.segments)
        }
    }

    struct Translator: TranslatingProject {
        func translate(
            _ request: TranslationPipelineRequest,
            events: @escaping TranslationPipelineEventHandler
        ) async throws -> TranslationPipelineOutput {
            var project = request.project
            project.status = .translating
            await events(.translating(project))
            project.status = .ready
            await events(.ready(project))
            return TranslationPipelineOutput(project: project)
        }
    }

    struct DiarizationEngine: SpeakerDiarizationEngine {
        func diarize(audioURL: URL) async throws -> [SpeakerSegment] { [] }
    }

    struct AlignmentEngine: SubtitleAlignmentEngine {
        func align(
            words: [WordTiming],
            existingCues: [SubtitleAlignmentCue],
            speakerSegments: [SpeakerSegment],
            options: SubtitleAlignmentOptions
        ) async throws -> [SubtitleAlignmentCue] {
            existingCues
        }

        func align(
            existingCues: [SubtitleAlignmentCue],
            speakerSegments: [SpeakerSegment],
            options: SubtitleAlignmentOptions
        ) async throws -> [SubtitleAlignmentCue] {
            existingCues
        }
    }

    final class AudioPreparation: AudioPreparationService {
        func preparedAudioURL(for sourceVideoURL: URL) async throws -> URL {
            sourceVideoURL.deletingPathExtension().appendingPathExtension("wav")
        }

        func removePreparedAudio(for sourceVideoURL: URL) throws {}
    }

    struct SubtitleExporter: SubtitleExportService {
        func export(
            request: SubtitleExportRequest,
            kind: SubtitleExportKind,
            destinationURL: URL
        ) async throws {}

        func exportSRT(
            request: SubtitleExportRequest,
            textMode: SubtitleTextMode,
            destinationURL: URL
        ) async throws {}
    }

    struct FFmpeg: FFmpegService {
        func checkAvailability() async throws -> FFmpegInfo {
            FFmpegInfo(executableURL: URL(fileURLWithPath: "/usr/bin/true"), version: "test")
        }

        func extractAudio(
            from videoURL: URL,
            to outputURL: URL,
            clips: [ExportClipRange]?
        ) async throws -> URL {
            outputURL
        }

        func burnSubtitles(
            videoURL: URL,
            subtitlesURL: URL,
            outputURL: URL,
            settings: VideoExportSettings,
            sourceInfo: VideoSourceInfo?,
            clips: [ExportClipRange]?,
            verticalReframe: VerticalReframePlan?,
            progressHandler: FFmpegProgressHandler?
        ) async throws -> URL {
            outputURL
        }
    }

    struct ScriptGenerator: SubtitleScriptGenerating {
        func generateASS(
            segments: [SubtitleSegment],
            settings: VideoExportSettings
        ) throws -> String { "" }

        func generateVerticalASS(_ request: VerticalSubtitleScriptRequest) -> String { "" }
    }

    struct SubtitleImporter: SubtitleImporting {
        func importSubtitles(from fileURL: URL) async throws -> SubtitleImportPreview {
            throw TestError.expected
        }
    }

    struct ProjectFileService: ProjectFileServicing {
        func exportProject(_ project: Project, to fileURL: URL) throws {}
        func importProject(from fileURL: URL) throws -> Project { throw TestError.expected }
    }

    struct EditTimelineService: EditTimelineEditing {
        func makeInitialTimeline(durationMs: Int) -> EditTimeline { fatalError("Unused") }
        func rippleDeleteRange(timeline: EditTimeline, range: VideoCutRange) throws -> EditTimeline { timeline }
        func splitAt(timeline: EditTimeline, timelineMs: Int) throws -> EditTimeline { timeline }
        func deleteClip(timeline: EditTimeline, clipID: UUID) throws -> EditTimeline { timeline }
        func sourceTime(forTimelineTime timelineMs: Int, in timeline: EditTimeline) -> Int? { nil }
        func clip(atTimelineTime timelineMs: Int, in timeline: EditTimeline) -> TimelineClip? { nil }
        func playbackAdvance(
            sourceTimeMs: Int,
            currentClipID: UUID?,
            lastKnownTimelineMs: Int,
            in timeline: EditTimeline,
            lookaheadMs: Int
        ) -> EditTimelinePlaybackAdvance { .paused }
        func recalculateTimelinePositions(clips: [TimelineClip]) -> EditTimeline { fatalError("Unused") }
    }

    struct SpeechProviderResolver: SpeechToTextProviderResolving {
        func resolve(
            configuration: SpeechToTextProviderConfiguration
        ) throws -> any SpeechToTextProvider {
            throw TestError.expected
        }
    }

    static func project(subtitles: [SubtitleSegment]? = nil) -> Project {
        let segment = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 0,
            endMs: 2_000,
            originalText: "Hello",
            translatedText: ""
        )
        return Project(
            id: UUID(),
            name: "Test",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            mediaFile: MediaFile(
                id: UUID(),
                originalURL: URL(fileURLWithPath: "/tmp/test.mp4"),
                fileName: "test.mp4",
                fileExtension: "mp4",
                sizeBytes: 1,
                durationMs: 10_000
            ),
            sourceLanguage: "English",
            targetLanguage: "Russian",
            subtitles: subtitles ?? [segment],
            status: .ready
        )
    }

    @MainActor
    static func projectFeatureComponents() -> ProjectFeatureComponents {
        ProjectFeatureComponents(
            player: PlayerFeatureFactory { _ in AnyView(EmptyView()) },
            timeline: TimelineFeatureFactory(
                makeSubtitleTimeline: { _ in AnyView(EmptyView()) },
                makeEditTimeline: { _ in AnyView(EmptyView()) }
            ),
            subtitleEditor: SubtitleEditorFeatureFactory(
                makeCueList: { _ in AnyView(EmptyView()) },
                makeEditorPane: { _ in AnyView(EmptyView()) },
                makeSubtitleEditor: { _ in AnyView(EmptyView()) },
                makeImportPreview: { _ in AnyView(EmptyView()) }
            ),
            shorts: ShortsFeatureFactory { _ in AnyView(EmptyView()) },
            export: ExportFeatureFactory(
                makeVideoSheet: { _ in AnyView(EmptyView()) },
                makeSubtitleOptionsSheet: { _ in AnyView(EmptyView()) }
            )
        )
    }

    @MainActor
    static func appState(
        project: Project,
        repository: Repository = Repository(),
        subtitleExportService: any SubtitleExportService = SubtitleExporter(),
        speakerDiarizationEngine: any SpeakerDiarizationEngine = DiarizationEngine(),
        audioPreparationService: any AudioPreparationService = AudioPreparation()
    ) -> AppState {
        let appState = AppState(
            subtitleExportService: subtitleExportService,
            translationService: TranslationService(),
            speakerDiarizationEngine: speakerDiarizationEngine,
            subtitleAlignmentEngine: AlignmentEngine(),
            audioPreparationService: audioPreparationService
        )
        repositoriesByAppState[ObjectIdentifier(appState)] = repository
        selectionsByAppState[ObjectIdentifier(appState)] = Selection(project: project)
        return appState
    }

    @MainActor
    static func projectFeatureDependencies(
        appState: AppState,
        editTimelineService: any EditTimelineEditing = EditTimelineService(),
        projectPreparer: (any ProjectPreparing)? = nil,
        projectPreparationConfiguration: ProjectPreparationConfigurationProvider? = nil,
        projectTranscriber: (any TranscribingProject)? = nil,
        projectTranslator: (any TranslatingProject)? = nil,
        subtitleDocumentPicker: SubtitleDocumentPicker? = nil,
        videoExportQueue: ExportQueue? = nil
    ) -> ProjectFeatureDependencies {
        let repository = repositoriesByAppState[ObjectIdentifier(appState)] ?? Repository()
        let selection = selectionsByAppState[ObjectIdentifier(appState)] ?? Selection(project: nil)
        let catalog = Catalog(
            repository: repository,
            projects: selection.subject.value.map { [$0] } ?? []
        )
        catalogsByAppState[ObjectIdentifier(appState)] = catalog
        let settingsSubject = CurrentValueSubject<SettingsSnapshot, Never>(
            SettingsSnapshot(settings: .default, persistenceState: .idle)
        )
        let settingsAccess = SettingsAccess(
            snapshot: { settingsSubject.value },
            snapshots: { settingsSubject.eraseToAnyPublisher() },
            reload: {},
            update: { settings in
                settingsSubject.send(SettingsSnapshot(
                    settings: settings,
                    persistenceState: .saved
                ))
            }
        )
        let preparer = projectPreparer ?? Preparer()
        let transcriber = projectTranscriber ?? Transcriber()
        let translator = projectTranslator ?? Translator()
        let exportQueue = videoExportQueue ?? ExportQueue()
        exportQueuesByAppState[ObjectIdentifier(appState)] = exportQueue

        return ProjectFeatureDependencies(
            projectRepository: repository,
            projectCatalog: catalog,
            settingsAccess: settingsAccess,
            subtitleImporter: SubtitleImporter(),
            projectFileService: ProjectFileService(),
            editTimelineService: editTimelineService,
            projectPreparer: preparer,
            projectPreparationConfiguration: projectPreparationConfiguration ?? {
                ProjectPreparationConfiguration(
                    ffmpegExecutablePath: settingsAccess.snapshot.settings.ffmpegPath
                )
            },
            projectTranscriber: transcriber,
            projectTranslator: translator,
            selection: selection.access,
            subtitleDocumentPicker: subtitleDocumentPicker ?? SubtitleDocumentPicker { _ in .cancelled },
            videoExportQueue: exportQueue
        )
    }

    @MainActor
    static func videoExportQueue(for appState: AppState) -> ExportQueue? {
        exportQueuesByAppState[ObjectIdentifier(appState)]
    }

    @MainActor
    static func catalog(for appState: AppState) -> Catalog? {
        catalogsByAppState[ObjectIdentifier(appState)]
    }

    @MainActor
    static func selectedProject(for appState: AppState) -> Project? {
        selectionsByAppState[ObjectIdentifier(appState)]?.subject.value
    }

    @MainActor
    static func select(_ project: Project?, for appState: AppState) {
        selectionsByAppState[ObjectIdentifier(appState)]?.subject.send(project)
    }

    @MainActor
    static func projectViewModel(
        appState: AppState,
        editTimelineService: any EditTimelineEditing = EditTimelineService(),
        projectPreparer: (any ProjectPreparing)? = nil,
        projectPreparationConfiguration: ProjectPreparationConfigurationProvider? = nil,
        projectTranscriber: (any TranscribingProject)? = nil,
        projectTranslator: (any TranslatingProject)? = nil,
        subtitleDocumentPicker: SubtitleDocumentPicker? = nil
    ) -> ProjectViewModel {
        ProjectViewModel(
            appState: appState,
            dependencies: projectFeatureDependencies(
                appState: appState,
                editTimelineService: editTimelineService,
                projectPreparer: projectPreparer,
                projectPreparationConfiguration: projectPreparationConfiguration,
                projectTranscriber: projectTranscriber,
                projectTranslator: projectTranslator,
                subtitleDocumentPicker: subtitleDocumentPicker
            )
        )
    }

    private struct Preparer: ProjectPreparing {
        func prepare(
            _ request: ProjectPreparationRequest,
            events: @escaping ProjectPreparationEventHandler
        ) async throws -> ProjectPreparationOutput {
            ProjectPreparationOutput(
                project: request.project,
                waveformPeaks: [0.2, 0.8],
                videoSourceInfo: nil,
                outcome: .ready
            )
        }
    }
}
