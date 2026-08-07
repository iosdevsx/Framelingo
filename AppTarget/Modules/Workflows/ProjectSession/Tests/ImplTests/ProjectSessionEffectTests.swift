import Combine
import Foundation
import Project
import ProjectPreparation
import ProjectSession
import ProjectSessionImpl
import Shorts
import SpeechToText
import Subtitles
import TranscriptionPipeline
import TranslationPipeline
import VideoExport
import VideoRendering
import XCTest

@MainActor
final class ProjectSessionEffectTests: XCTestCase {
    func testPreparationPublishesTypedProgressAndProjectScopedDerivedMedia() async {
        let sourceInfo = VideoSourceInfo(width: 1_920, height: 1_080, nominalFrameRate: 30)
        let preparer = EffectPreparer { request, events in
            await events(.progress(ProjectPreparationProgress(
                phase: .preparingWaveform,
                fractionCompleted: 0.5
            )))
            var project = request.project
            project.mediaFile.durationMs = 2_000
            return ProjectPreparationOutput(
                project: project,
                waveformPeaks: [0.2, 0.8],
                videoSourceInfo: sourceInfo,
                outcome: .ready
            )
        }
        let fixture = makeEffectFixture(preparer: preparer)
        fixture.session.open(fixture.project)

        await fixture.session.prepare()

        XCTAssertEqual(fixture.session.snapshot.project?.mediaFile.durationMs, 2_000)
        XCTAssertEqual(fixture.session.snapshot.effects.derivedMedia.projectID, fixture.project.id)
        XCTAssertEqual(fixture.session.snapshot.effects.derivedMedia.waveformPeaks, [0.2, 0.8])
        XCTAssertEqual(fixture.session.snapshot.effects.derivedMedia.videoSourceInfo, sourceInfo)
        XCTAssertEqual(fixture.session.snapshot.effects.preparation, .completed(.ready))
    }

    func testReplacementCancelsPreparationAndRejectsDelayedOutput() async throws {
        let preparer = ControlledPreparer()
        let fixture = makeEffectFixture(preparer: preparer)
        fixture.session.open(fixture.project)
        let preparation = Task { await fixture.session.prepare() }
        try await waitUntil("preparation start") { await preparer.hasStarted }

        let replacement = makeSessionProject(name: "Replacement")
        fixture.session.replace(with: replacement)
        var stale = fixture.project
        stale.name = "Stale output"
        await preparer.finish(ProjectPreparationOutput(
            project: stale,
            waveformPeaks: [1],
            videoSourceInfo: VideoSourceInfo(width: 10, height: 10, nominalFrameRate: 24),
            outcome: .ready
        ))
        await preparation.value

        XCTAssertEqual(fixture.session.snapshot.project?.id, replacement.id)
        XCTAssertEqual(fixture.session.snapshot.effects, .empty)
        XCTAssertFalse(fixture.session.snapshot.history.canUndo)
    }

    func testCloseRejectsDelayedEffectsAndDisposePreventsReopening() async throws {
        let preparer = ControlledPreparer()
        let fixture = makeEffectFixture(preparer: preparer)
        fixture.session.open(fixture.project)
        let preparation = Task { await fixture.session.prepare() }
        try await waitUntil("preparation start") { await preparer.hasStarted }

        fixture.session.close()
        var stale = fixture.project
        stale.name = "Late after close"
        await preparer.finish(ProjectPreparationOutput(
            project: stale,
            waveformPeaks: [1],
            videoSourceInfo: nil,
            outcome: .ready
        ))
        await preparation.value

        XCTAssertNil(fixture.session.snapshot.project)
        XCTAssertEqual(fixture.session.snapshot.effects, .empty)

        fixture.session.open(fixture.project)
        fixture.session.dispose()
        fixture.session.open(makeSessionProject(name: "Ignored after dispose"))
        XCTAssertNil(fixture.session.snapshot.project)
        XCTAssertEqual(fixture.session.snapshot.effects, .empty)
    }

    func testTranscriptionAndTranslationUseTypedStateAndCanonicalInstallation() async {
        let transcriber = EffectTranscriber { request, events in
            await events(.progress(TranscriptionPipelineProgress(
                phase: .transcribing,
                fractionCompleted: 0.4
            )))
            var project = request.project
            project.status = .ready
            project.subtitles = [SubtitleSegment(
                id: UUID(),
                index: 1,
                startMs: 0,
                endMs: 1_000,
                originalText: "Hello",
                translatedText: ""
            )]
            await events(.projectChanged(project))
            return TranscriptionPipelineOutput(project: project, warning: nil)
        }
        let translator = EffectTranslator { request, events in
            var project = request.project
            project.subtitles[0].translatedText = "Привет"
            await events(.ready(project))
            return TranslationPipelineOutput(project: project)
        }
        let fixture = makeEffectFixture(transcriber: transcriber, translator: translator)
        fixture.session.open(fixture.project)

        await fixture.session.transcribe()
        XCTAssertEqual(fixture.session.snapshot.effects.transcription, .completed(nil))
        XCTAssertEqual(fixture.session.snapshot.project?.subtitles.first?.originalText, "Hello")

        await fixture.session.translate()
        XCTAssertEqual(fixture.session.snapshot.effects.translation, .completed)
        XCTAssertEqual(fixture.session.snapshot.project?.subtitles.first?.translatedText, "Привет")

        let empty = makeEffectFixture()
        empty.session.open(empty.project)
        await empty.session.translate()
        XCTAssertEqual(
            empty.session.snapshot.effects.translation,
            .failed(ProjectSessionEffectFailure(kind: .translation, reason: .noSubtitles))
        )
    }

    func testImportAndExportsReadAndWriteOnlyCanonicalSessionProject() async throws {
        let imported = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 100,
            endMs: 900,
            originalText: "Imported",
            translatedText: ""
        )
        let preview = SubtitleImportPreview(
            fileURL: URL(fileURLWithPath: "/tmp/import.srt"),
            format: .srt,
            detectedEncodingName: "UTF-8",
            segments: [imported],
            warnings: []
        )
        let exporter = RecordingSubtitleExporter()
        let projectFiles = RecordingProjectFileService()
        let queue = RecordingVideoExportQueue()
        let fixture = makeEffectFixture(
            importer: EffectImporter(preview: preview),
            exporter: exporter,
            projectFiles: projectFiles,
            queue: queue
        )
        fixture.session.open(fixture.project)

        await fixture.session.previewSubtitleImport(from: preview.fileURL)
        XCTAssertEqual(fixture.session.snapshot.effects.subtitleImport, .preview(preview))
        let result = fixture.session.applySubtitleImport(
            preview,
            mode: .replaceExisting,
            destination: .original
        )
        XCTAssertTrue(result.didChange)
        XCTAssertEqual(fixture.session.snapshot.project?.subtitles, [imported])
        XCTAssertTrue(fixture.session.snapshot.history.canUndo)

        let subtitleURL = URL(fileURLWithPath: "/tmp/export.srt")
        await fixture.session.exportSubtitles(kind: .translatedSRT, to: subtitleURL)
        let requests = await exporter.requests
        XCTAssertEqual(requests.last?.segments, fixture.session.snapshot.project?.subtitles)
        XCTAssertEqual(fixture.session.snapshot.effects.export, .completed(.subtitleExport, subtitleURL))

        let projectURL = URL(fileURLWithPath: "/tmp/project.subtitleedit")
        await fixture.session.exportProject(to: projectURL)
        XCTAssertEqual(projectFiles.exportedProject?.subtitles, [imported])

        fixture.session.enqueueVideoExport(settings: VideoExportSettings(), outputURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        XCTAssertEqual(queue.fullProjectRequests.count, 1)
        XCTAssertEqual(queue.fullProjectRequests.first?.project.subtitles, [imported])
    }
}

private struct EffectFixture {
    let session: DefaultProjectSession
    let project: Project
}

@MainActor
private func makeEffectFixture(
    preparer: any ProjectPreparing = EffectPreparer(),
    transcriber: any TranscribingProject = EffectTranscriber(),
    translator: any TranslatingProject = EffectTranslator(),
    importer: any SubtitleImporting = EffectImporter(),
    exporter: any SubtitleExportService = RecordingSubtitleExporter(),
    projectFiles: any ProjectFileServicing = RecordingProjectFileService(),
    queue providedQueue: (any VideoExportQueue)? = nil
) -> EffectFixture {
    let project = makeSessionProject()
    let repository = RecordingProjectRepository()
    let queue = providedQueue ?? RecordingVideoExportQueue()
    let effects = ProjectSessionEffectDependencies(
        projectPreparer: preparer,
        preparationConfiguration: { ProjectPreparationConfiguration(ffmpegExecutablePath: "/usr/bin/ffmpeg") },
        projectTranscriber: transcriber,
        transcriptionConfiguration: {
            TranscriptionPipelineConfiguration(
                ffmpegExecutablePath: "/usr/bin/ffmpeg",
                speechToText: SpeechToTextProviderConfiguration(providerName: SpeechToTextProviderName.mock)
            )
        },
        projectTranslator: translator,
        subtitleImporter: importer,
        subtitleExporter: exporter,
        projectFileService: projectFiles,
        videoExportQueue: queue
    )
    let session = DefaultProjectSession(dependencies: ProjectSessionDependencies(
        repository: repository,
        effects: effects
    ))
    return EffectFixture(session: session, project: project)
}

private struct EffectPreparer: ProjectPreparing {
    let action: (ProjectPreparationRequest, @escaping ProjectPreparationEventHandler) async throws -> ProjectPreparationOutput

    init(action: @escaping (ProjectPreparationRequest, @escaping ProjectPreparationEventHandler) async throws -> ProjectPreparationOutput = { request, _ in
        ProjectPreparationOutput(project: request.project, waveformPeaks: [], videoSourceInfo: nil, outcome: .ready)
    }) {
        self.action = action
    }

    func prepare(_ request: ProjectPreparationRequest, events: @escaping ProjectPreparationEventHandler) async throws -> ProjectPreparationOutput {
        try await action(request, events)
    }
}

private actor ControlledPreparer: ProjectPreparing {
    private var continuation: CheckedContinuation<ProjectPreparationOutput, Error>?
    private(set) var hasStarted = false

    func prepare(_ request: ProjectPreparationRequest, events: @escaping ProjectPreparationEventHandler) async throws -> ProjectPreparationOutput {
        hasStarted = true
        await events(.progress(ProjectPreparationProgress(phase: .preparingWaveform, fractionCompleted: 0.1)))
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func finish(_ output: ProjectPreparationOutput) {
        continuation?.resume(returning: output)
        continuation = nil
    }
}

private struct EffectTranscriber: TranscribingProject {
    let action: (TranscriptionPipelineRequest, @escaping TranscriptionPipelineEventHandler) async throws -> TranscriptionPipelineOutput

    init(action: @escaping (TranscriptionPipelineRequest, @escaping TranscriptionPipelineEventHandler) async throws -> TranscriptionPipelineOutput = { request, _ in
        TranscriptionPipelineOutput(project: request.project, warning: nil)
    }) {
        self.action = action
    }

    func transcribe(_ request: TranscriptionPipelineRequest, events: @escaping TranscriptionPipelineEventHandler) async throws -> TranscriptionPipelineOutput {
        try await action(request, events)
    }
}

private struct EffectTranslator: TranslatingProject {
    let action: (TranslationPipelineRequest, @escaping TranslationPipelineEventHandler) async throws -> TranslationPipelineOutput

    init(action: @escaping (TranslationPipelineRequest, @escaping TranslationPipelineEventHandler) async throws -> TranslationPipelineOutput = { request, _ in
        TranslationPipelineOutput(project: request.project)
    }) {
        self.action = action
    }

    func translate(_ request: TranslationPipelineRequest, events: @escaping TranslationPipelineEventHandler) async throws -> TranslationPipelineOutput {
        try await action(request, events)
    }
}

private struct EffectImporter: SubtitleImporting {
    let preview: SubtitleImportPreview

    init(preview: SubtitleImportPreview = SubtitleImportPreview(
        fileURL: URL(fileURLWithPath: "/tmp/empty.srt"),
        format: .srt,
        detectedEncodingName: nil,
        segments: [],
        warnings: []
    )) {
        self.preview = preview
    }

    func importSubtitles(from fileURL: URL) async throws -> SubtitleImportPreview { preview }
}

private actor RecordingSubtitleExporter: SubtitleExportService {
    private(set) var requests: [SubtitleExportRequest] = []

    func export(request: SubtitleExportRequest, kind: SubtitleExportKind, destinationURL: URL) async throws {
        requests.append(request)
    }

    func exportSRT(request: SubtitleExportRequest, textMode: SubtitleTextMode, destinationURL: URL) async throws {
        requests.append(request)
    }
}

private final class RecordingProjectFileService: ProjectFileServicing {
    private(set) var exportedProject: Project?
    func exportProject(_ project: Project, to fileURL: URL) throws { exportedProject = project }
    func importProject(from fileURL: URL) throws -> Project {
        throw NSError(domain: "ProjectSessionEffectTests", code: 1)
    }
}

@MainActor
private final class RecordingVideoExportQueue: VideoExportQueue {
    private let subject = CurrentValueSubject<[VideoExportJob], Never>([])
    var jobs: [VideoExportJob] { subject.value }
    var jobSnapshots: AnyPublisher<[VideoExportJob], Never> { subject.eraseToAnyPublisher() }
    private(set) var fullProjectRequests: [FullProjectVideoExportRequest] = []

    func enqueue(_ request: VideoExportRequest) {
        if case .fullProject(let request) = request { fullProjectRequests.append(request) }
    }
    func enqueue(_ batch: ShortsVideoExportBatchRequest) {}
    func removeFinishedJob(id: UUID) {}
}
