import Application
import ApplicationImpl
import Foundation
import Media
import Project
import Settings
import SpeakerAnalysis
import SpeechToText
import Subtitles
import Timeline
import Translation
import VideoRendering
import XCTest

final class ProjectProcessingWorkflowTests: XCTestCase {
    func testTranscriptionPublishesAndPersistsStatusOrder() async throws {
        let project = TestDoubles.project()
        let repository = TestDoubles.Repository()
        let ffmpeg = WorkflowFFmpeg()
        let speech = WorkflowSpeechProvider()
        let workflow = transcriptionWorkflow(
            repository: repository,
            ffmpeg: ffmpeg,
            speech: speech
        )
        var events: [ProjectProcessingEvent] = []

        let output = try await workflow.transcribe(
            ProjectTranscriptionRequest(project: project, settings: .default),
            events: { events.append($0) }
        )

        XCTAssertEqual(repository.savedProjects.map(\.status), [.extractingAudio, .transcribing, .ready])
        XCTAssertEqual(projectStatuses(in: events), [.extractingAudio, .transcribing, .ready])
        XCTAssertEqual(output.project.status, .ready)
        XCTAssertEqual(speech.audioURL, ffmpeg.outputURL)
    }

    func testTranscriptionUsesEditedClipPlanAndConstrainsOutput() async throws {
        var project = TestDoubles.project()
        project.editTimeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 2_000,
                    sourceEndMs: 6_000,
                    timelineStartMs: 0,
                    timelineEndMs: 4_000
                ),
            ],
            totalDurationMs: 4_000
        )
        let repository = TestDoubles.Repository()
        let ffmpeg = WorkflowFFmpeg()
        let speech = WorkflowSpeechProvider(
            result: TranscriptionResult(
                segments: [
                    SubtitleSegment(id: UUID(), index: 1, startMs: 3_500, endMs: 4_500, originalText: "Edge", translatedText: ""),
                    SubtitleSegment(id: UUID(), index: 2, startMs: 4_100, endMs: 5_000, originalText: "Outside", translatedText: ""),
                ],
                words: [WordTiming(text: "Edge", start: 3.8, end: 4.2)],
                detectedLanguage: "de",
                durationMs: 5_000
            )
        )
        let diarization = WorkflowDiarization(
            result: [SpeakerSegment(speakerId: 0, start: 3.9, end: 4.4)]
        )
        let workflow = transcriptionWorkflow(
            repository: repository,
            ffmpeg: ffmpeg,
            speech: speech,
            diarization: diarization
        )

        let output = try await workflow.transcribe(
            ProjectTranscriptionRequest(project: project, settings: .default),
            events: { _ in }
        )

        XCTAssertEqual(ffmpeg.clips, [ExportClipRange(sourceStartMs: 2_000, sourceEndMs: 6_000)])
        XCTAssertEqual(diarization.audioURL, ffmpeg.outputURL)
        XCTAssertEqual(output.project.sourceLanguage, "de")
        XCTAssertEqual(output.project.mediaFile.durationMs, 10_000)
        XCTAssertEqual(output.project.subtitles.count, 1)
        XCTAssertEqual(output.project.subtitles.first?.endMs, 4_000)
        XCTAssertEqual(output.project.wordTimings.first?.end, 4.0)
        XCTAssertEqual(output.project.speakerSegments.first?.end, 4.0)
    }

    func testTranscriptionMapsEmptyTimelineAndFFmpegFailure() async {
        var emptyProject = TestDoubles.project()
        emptyProject.editTimeline = EditTimeline(clips: [], totalDurationMs: 0)
        let emptyRepository = TestDoubles.Repository()
        let emptyWorkflow = transcriptionWorkflow(
            repository: emptyRepository,
            ffmpeg: WorkflowFFmpeg(),
            speech: WorkflowSpeechProvider()
        )

        await assertThrows(
            ProjectTranscriptionError.emptyEditTimeline,
            from: emptyWorkflow,
            project: emptyProject
        )
        XCTAssertEqual(emptyRepository.savedProjects.map(\.status), [.extractingAudio, .failed(ProjectTranscriptionError.emptyEditTimeline.errorDescription!)])

        let ffmpegRepository = TestDoubles.Repository()
        let ffmpegWorkflow = transcriptionWorkflow(
            repository: ffmpegRepository,
            ffmpeg: WorkflowFFmpeg(error: FFmpegServiceError.notFound),
            speech: WorkflowSpeechProvider()
        )
        await assertThrows(
            ProjectTranscriptionError.ffmpegNotFound,
            from: ffmpegWorkflow,
            project: TestDoubles.project()
        )
    }

    func testTranscriptionPreservesLocalizedProviderFailureAndDiarizationWarning() async throws {
        let failureRepository = TestDoubles.Repository()
        let failingWorkflow = transcriptionWorkflow(
            repository: failureRepository,
            ffmpeg: WorkflowFFmpeg(),
            speech: WorkflowSpeechProvider(error: WorkflowError.provider)
        )

        await assertThrows(
            ProjectTranscriptionError.failed("Provider unavailable."),
            from: failingWorkflow,
            project: TestDoubles.project()
        )
        XCTAssertEqual(failureRepository.savedProjects.last?.status, .failed("Provider unavailable."))

        let warningWorkflow = transcriptionWorkflow(
            repository: TestDoubles.Repository(),
            ffmpeg: WorkflowFFmpeg(),
            speech: WorkflowSpeechProvider(),
            diarization: WorkflowDiarization(error: WorkflowError.diarization)
        )
        let output = try await warningWorkflow.transcribe(
            ProjectTranscriptionRequest(project: TestDoubles.project(), settings: .default),
            events: { _ in }
        )
        XCTAssertEqual(output.project.status, .ready)
        XCTAssertEqual(
            output.completionMessage,
            "Transcription complete. Speaker analysis failed; subtitle timings were not refined. Speaker engine unavailable."
        )
    }

    func testTranscriptionCancellationDoesNotPersistFailedState() async {
        let repository = TestDoubles.Repository()
        let workflow = transcriptionWorkflow(
            repository: repository,
            ffmpeg: WorkflowFFmpeg(),
            speech: WorkflowSpeechProvider(error: CancellationError())
        )

        do {
            _ = try await workflow.transcribe(
                ProjectTranscriptionRequest(project: TestDoubles.project(), settings: .default),
                events: { _ in }
            )
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(repository.savedProjects.map(\.status), [.extractingAudio, .transcribing])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscriptionCanRetryAfterProviderFailure() async throws {
        let repository = TestDoubles.Repository()
        let speech = RetryOnceSpeechProvider()
        let workflow = ApplicationWorkflowAssembly.makeProjectTranscriptionWorkflow(
            projectRepository: repository,
            speechToTextProviderResolver: WorkflowSpeechResolver(provider: speech),
            speakerDiarizationEngine: WorkflowDiarization(),
            subtitleAlignmentEngine: WorkflowAlignment(),
            makeFFmpegService: { _ in WorkflowFFmpeg() }
        )

        do {
            _ = try await workflow.transcribe(
                ProjectTranscriptionRequest(project: TestDoubles.project(), settings: .default),
                events: { _ in }
            )
            XCTFail("Expected the first attempt to fail")
        } catch let error as ProjectTranscriptionError {
            XCTAssertEqual(error, .failed("Provider unavailable."))
        }

        let failedProject = try XCTUnwrap(repository.savedProjects.last)
        let output = try await workflow.transcribe(
            ProjectTranscriptionRequest(project: failedProject, settings: .default),
            events: { _ in }
        )

        XCTAssertEqual(output.project.status, .ready)
        XCTAssertEqual(speech.callCount, 2)
        XCTAssertEqual(repository.savedProjects.suffix(3).map(\.status), [.extractingAudio, .transcribing, .ready])
    }

    func testPreparationPublishesMetadataAndProgressAndHandlesWaveformFailure() async throws {
        var project = TestDoubles.project()
        project.mediaFile.durationMs = nil
        let ffmpeg = WorkflowFFmpeg()
        let waveform = WorkflowWaveform()
        let metadata = WorkflowMetadata()
        let workflow = ApplicationWorkflowAssembly.makeProjectPreparationWorkflow(
            mediaMetadataProvider: metadata,
            waveformLoader: waveform,
            makeFFmpegService: { _ in ffmpeg }
        )
        var events: [ProjectProcessingEvent] = []

        let output = try await workflow.prepare(
            ProjectPreparationRequest(project: project, settings: .default),
            events: { events.append($0) }
        )

        XCTAssertEqual(output.project.mediaFile.durationMs, 12_000)
        XCTAssertEqual(metadata.durationCallCount, 1)
        XCTAssertEqual(output.waveformPeaks, [0.2, 0.8])
        XCTAssertEqual(output.videoSourceInfo, VideoSourceInfo(width: 1920, height: 1080, nominalFrameRate: 30))
        XCTAssertEqual(ffmpeg.outputURL, waveform.audioURL)
        XCTAssertTrue(events.contains { event in
            if case .progress(_, "Loading waveform...") = event { return true }
            return false
        })

        let failing = ApplicationWorkflowAssembly.makeProjectPreparationWorkflow(
            mediaMetadataProvider: WorkflowMetadata(error: WorkflowError.metadata),
            waveformLoader: WorkflowWaveform(error: WorkflowError.waveform),
            makeFFmpegService: { _ in ffmpeg }
        )
        let fallback = try await failing.prepare(
            ProjectPreparationRequest(project: project, settings: .default),
            events: { _ in }
        )
        XCTAssertEqual(fallback.waveformPeaks, [])
        XCTAssertNil(fallback.videoSourceInfo)
        XCTAssertEqual(fallback.status, "Project ready. Waveform unavailable.")

        let cachedMetadata = WorkflowMetadata()
        _ = try await ApplicationWorkflowAssembly.makeProjectPreparationWorkflow(
            mediaMetadataProvider: cachedMetadata,
            waveformLoader: WorkflowWaveform(),
            makeFFmpegService: { _ in ffmpeg }
        ).prepare(
            ProjectPreparationRequest(project: TestDoubles.project(), settings: .default),
            events: { _ in }
        )
        XCTAssertEqual(cachedMetadata.durationCallCount, 0)
    }

    func testPreparationCancellationIsStructured() async {
        let workflow = ApplicationWorkflowAssembly.makeProjectPreparationWorkflow(
            mediaMetadataProvider: WorkflowMetadata(),
            waveformLoader: WorkflowWaveform(error: CancellationError()),
            makeFFmpegService: { _ in WorkflowFFmpeg() }
        )
        do {
            _ = try await workflow.prepare(
                ProjectPreparationRequest(project: TestDoubles.project(), settings: .default),
                events: { _ in }
            )
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testPreparationResultDoesNotOverwriteNewlySelectedProject() async throws {
        let original = TestDoubles.project()
        var replacement = TestDoubles.project()
        replacement.name = "Replacement"
        let appState = TestDoubles.appState(project: original)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectPreparationWorkflow: DelayedPreparationWorkflow()
        )

        viewModel.prepareProjectForEditing()
        appState.selectedProject = replacement
        appState.recentProjects.append(replacement)
        viewModel.loadSelectedProject()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(viewModel.project?.id, replacement.id)
        XCTAssertEqual(viewModel.project?.name, "Replacement")
    }

    func testTranslationSuccessAndStatusOrder() async throws {
        let repository = TestDoubles.Repository()
        let service = WorkflowTranslation()
        let workflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
            projectRepository: repository,
            translationService: service
        )

        let output = try await workflow.translate(
            ProjectTranslationRequest(project: TestDoubles.project()),
            events: { _ in }
        )

        XCTAssertEqual(output.project.subtitles.first?.translatedText, "Translated")
        XCTAssertEqual(repository.savedProjects.map(\.status), [.translating, .ready])
    }

    func testTranslationValidatesInputResultAndLocalizedFailure() async {
        let emptyWorkflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
            projectRepository: TestDoubles.Repository(),
            translationService: WorkflowTranslation()
        )
        var emptyProject = TestDoubles.project()
        emptyProject.subtitles = []
        await assertTranslationError(.noSubtitles, workflow: emptyWorkflow, project: emptyProject)

        let mismatchWorkflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
            projectRepository: TestDoubles.Repository(),
            translationService: WorkflowTranslation(result: SubtitleTranslationResult(segments: []))
        )
        await assertTranslationError(.segmentCountMismatch, workflow: mismatchWorkflow, project: TestDoubles.project())

        let failureWorkflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
            projectRepository: TestDoubles.Repository(),
            translationService: WorkflowTranslation(error: WorkflowError.translation)
        )
        await assertTranslationError(.failed("Translation provider unavailable."), workflow: failureWorkflow, project: TestDoubles.project())
    }

    func testTranslationCancellationDoesNotPersistFailedState() async {
        let repository = TestDoubles.Repository()
        let workflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
            projectRepository: repository,
            translationService: WorkflowTranslation(error: CancellationError())
        )
        do {
            _ = try await workflow.translate(
                ProjectTranslationRequest(project: TestDoubles.project()),
                events: { _ in }
            )
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(repository.savedProjects.map(\.status), [.translating])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testTranslationResultDoesNotOverwriteNewlySelectedProject() async throws {
        let original = TestDoubles.project()
        var replacement = TestDoubles.project()
        replacement.name = "Replacement"
        let appState = TestDoubles.appState(project: original)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranslationWorkflow: DelayedTranslationWorkflow()
        )

        let translationTask = Task { await viewModel.translate() }
        await Task.yield()
        appState.selectedProject = replacement
        appState.recentProjects.append(replacement)
        viewModel.loadSelectedProject()
        await translationTask.value

        XCTAssertEqual(viewModel.project?.id, replacement.id)
        XCTAssertEqual(viewModel.project?.name, "Replacement")
    }

    private func transcriptionWorkflow(
        repository: TestDoubles.Repository,
        ffmpeg: WorkflowFFmpeg,
        speech: WorkflowSpeechProvider,
        diarization: WorkflowDiarization = WorkflowDiarization()
    ) -> any ProjectTranscriptionWorkflow {
        ApplicationWorkflowAssembly.makeProjectTranscriptionWorkflow(
            projectRepository: repository,
            speechToTextProviderResolver: WorkflowSpeechResolver(provider: speech),
            speakerDiarizationEngine: diarization,
            subtitleAlignmentEngine: WorkflowAlignment(),
            makeFFmpegService: { _ in ffmpeg }
        )
    }

    private func projectStatuses(in events: [ProjectProcessingEvent]) -> [ProcessingStatus] {
        events.compactMap { event in
            if case .projectChanged(let project) = event { return project.status }
            return nil
        }
    }

    private func assertThrows(
        _ expected: ProjectTranscriptionError,
        from workflow: any ProjectTranscriptionWorkflow,
        project: Project
    ) async {
        do {
            _ = try await workflow.transcribe(
                ProjectTranscriptionRequest(project: project, settings: .default),
                events: { _ in }
            )
            XCTFail("Expected \(expected)")
        } catch let error as ProjectTranscriptionError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func assertTranslationError(
        _ expected: ProjectTranslationError,
        workflow: any ProjectTranslationWorkflow,
        project: Project
    ) async {
        do {
            _ = try await workflow.translate(ProjectTranslationRequest(project: project), events: { _ in })
            XCTFail("Expected \(expected)")
        } catch let error as ProjectTranslationError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private enum WorkflowError: LocalizedError {
    case provider
    case diarization
    case metadata
    case waveform
    case translation

    var errorDescription: String? {
        switch self {
        case .provider: "Provider unavailable."
        case .diarization: "Speaker engine unavailable."
        case .metadata: "Metadata unavailable."
        case .waveform: "Waveform unavailable."
        case .translation: "Translation provider unavailable."
        }
    }
}

private final class WorkflowFFmpeg: FFmpegService {
    let error: Error?
    var clips: [ExportClipRange]?
    var outputURL: URL?

    init(error: Error? = nil) { self.error = error }

    func checkAvailability() async throws -> FFmpegInfo {
        FFmpegInfo(executableURL: URL(fileURLWithPath: "/usr/bin/true"), version: "test")
    }

    func extractAudio(from videoURL: URL, to outputURL: URL, clips: [ExportClipRange]?) async throws -> URL {
        if let error { throw error }
        self.clips = clips
        self.outputURL = outputURL
        return outputURL
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
    ) async throws -> URL { outputURL }
}

private final class WorkflowSpeechProvider: SpeechToTextProvider {
    let result: TranscriptionResult
    let error: Error?
    var audioURL: URL?

    init(
        result: TranscriptionResult = TranscriptionResult(
            segments: [SubtitleSegment(id: UUID(), index: 1, startMs: 0, endMs: 1_000, originalText: "Hello", translatedText: "")],
            words: [],
            detectedLanguage: nil,
            durationMs: 1_000
        ),
        error: Error? = nil
    ) {
        self.result = result
        self.error = error
    }

    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        audioURL = input.audioURL
        if let error { throw error }
        return result
    }
}

private final class RetryOnceSpeechProvider: SpeechToTextProvider {
    var callCount = 0

    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        callCount += 1
        if callCount == 1 { throw WorkflowError.provider }
        return TranscriptionResult(
            segments: [SubtitleSegment(id: UUID(), index: 1, startMs: 0, endMs: 1_000, originalText: "Hello", translatedText: "")],
            words: [],
            detectedLanguage: nil,
            durationMs: 1_000
        )
    }
}

private struct WorkflowSpeechResolver: SpeechToTextProviderResolving {
    let provider: any SpeechToTextProvider
    func resolve(configuration: SpeechToTextProviderConfiguration) throws -> any SpeechToTextProvider { provider }
}

private final class WorkflowDiarization: SpeakerDiarizationEngine {
    let result: [SpeakerSegment]
    let error: Error?
    var audioURL: URL?

    init(result: [SpeakerSegment] = [], error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func diarize(audioURL: URL) async throws -> [SpeakerSegment] {
        self.audioURL = audioURL
        if let error { throw error }
        return result
    }
}

private struct WorkflowAlignment: SubtitleAlignmentEngine {
    func align(
        words: [WordTiming],
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue] { existingCues }

    func align(
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue] { existingCues }
}

private final class WorkflowMetadata: MediaMetadataProviding {
    let error: Error?
    var durationCallCount = 0
    init(error: Error? = nil) { self.error = error }

    func durationMs(for url: URL) async throws -> Int? {
        durationCallCount += 1
        if let error { throw error }
        return 12_000
    }

    func videoMetadata(for url: URL) async throws -> VideoMetadata {
        if let error { throw error }
        return VideoMetadata(width: 1920, height: 1080, nominalFrameRate: 30)
    }
}

private final class WorkflowWaveform: WaveformLoading {
    let error: Error?
    var audioURL: URL?
    init(error: Error? = nil) { self.error = error }

    func loadWaveform(
        for request: WaveformRequest,
        audioProvider: @escaping WaveformAudioProvider,
        progressHandler: WaveformProgressHandler?
    ) async throws -> [Double] {
        if let error { throw error }
        if let progressHandler { await progressHandler(0.5, "Loading waveform...") }
        audioURL = try await audioProvider()
        return [0.2, 0.8]
    }
}

private struct WorkflowTranslation: TranslationOrchestrating {
    let result: SubtitleTranslationResult?
    let error: Error?

    init(result: SubtitleTranslationResult? = nil, error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func translateSubtitles(_ input: SubtitleTranslationInput) async throws -> SubtitleTranslationResult {
        if let error { throw error }
        if let result { return result }
        return SubtitleTranslationResult(
            segments: input.segments.map { segment in
                var segment = segment
                segment.translatedText = "Translated"
                return segment
            }
        )
    }
}

private struct DelayedPreparationWorkflow: ProjectPreparationWorkflow {
    func prepare(
        _ request: ProjectPreparationRequest,
        events: @escaping ProjectProcessingEventHandler
    ) async throws -> ProjectPreparationOutput {
        try await Task.sleep(for: .milliseconds(40))
        await events(.projectChanged(request.project))
        return ProjectPreparationOutput(
            project: request.project,
            waveformPeaks: [1],
            videoSourceInfo: nil,
            status: "Project ready"
        )
    }
}

private struct DelayedTranslationWorkflow: ProjectTranslationWorkflow {
    func translate(
        _ request: ProjectTranslationRequest,
        events: @escaping ProjectProcessingEventHandler
    ) async throws -> ProjectTranslationOutput {
        try await Task.sleep(for: .milliseconds(40))
        await events(.projectChanged(request.project))
        return ProjectTranslationOutput(project: request.project)
    }
}
