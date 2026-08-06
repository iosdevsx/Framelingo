import Foundation
import Project
import SpeakerAnalysis
import SpeechToText
import Subtitles
import Timeline
import TranscriptionPipeline
import TranscriptionPipelineImpl
import VideoRendering
import XCTest

final class TranscriptionPipelineTests: XCTestCase {
    func testFullSourceSuccessPreservesOrderConfigurationAndSharedAudioURL() async throws {
        let repository = Repository()
        let ffmpeg = FFmpeg()
        let speech = Speech()
        let resolver = Resolver(provider: speech)
        let diarization = Diarization(result: [SpeakerSegment(speakerId: 2, start: 0, end: 1)])
        let alignment = Alignment()
        let files = Files()
        var events: [TranscriptionPipelineEvent] = []
        let pipeline = makePipeline(
            repository: repository,
            ffmpeg: ffmpeg,
            resolver: resolver,
            diarization: diarization,
            alignment: alignment,
            files: files
        )

        let output = try await pipeline.transcribe(request(project: project())) {
            events.append($0)
        }

        XCTAssertEqual(repository.saved.map(\.status), [.extractingAudio, .transcribing, .ready])
        XCTAssertEqual(projectStatuses(events), [.extractingAudio, .transcribing, .ready])
        XCTAssertEqual(output.project.status, .ready)
        XCTAssertEqual(output.project.sourceLanguage, "de")
        XCTAssertEqual(output.project.mediaFile.durationMs, 1_500)
        XCTAssertEqual(speech.input?.audioURL, ffmpeg.outputURL)
        XCTAssertEqual(diarization.audioURL, ffmpeg.outputURL)
        XCTAssertEqual(speech.input?.videoURL, project().mediaFile.originalURL)
        XCTAssertEqual(resolver.configuration?.providerName, "Whisper")
        XCTAssertEqual(resolver.configuration?.whisperModelName, "large-v3")
        XCTAssertEqual(files.removed, [try XCTUnwrap(ffmpeg.outputURL)])
        XCTAssertEqual(progressPhases(events), [
            .extractingAudio,
            .transcribing,
            .transcribing,
            .analyzingSpeakers,
            .aligningSubtitles,
        ])
    }

    func testEditedTimelineUsesClipPlanAndConstrainsEveryTimingCollection() async throws {
        var edited = project()
        edited.editTimeline = EditTimeline(
            clips: [
                TimelineClip(id: UUID(), sourceStartMs: 1_000, sourceEndMs: 3_000, timelineStartMs: 0, timelineEndMs: 2_000),
                TimelineClip(id: UUID(), sourceStartMs: 6_000, sourceEndMs: 8_000, timelineStartMs: 2_000, timelineEndMs: 4_000),
            ],
            totalDurationMs: 4_000
        )
        edited.speakerLabels = [SpeakerLabel(id: 1, displayName: "Host")]
        let speech = Speech(result: TranscriptionResult(
            segments: [
                subtitle(index: 7, start: 3_500, end: 4_500, text: "Edge"),
                subtitle(index: 8, start: 4_100, end: 5_000, text: "Outside"),
            ],
            words: [
                WordTiming(text: "Edge", start: 3.8, end: 4.2),
                WordTiming(text: "Outside", start: 4.1, end: 4.5),
            ],
            detectedLanguage: nil,
            durationMs: 5_000
        ))
        let diarization = Diarization(result: [
            SpeakerSegment(speakerId: 1, start: 3.9, end: 4.4),
            SpeakerSegment(speakerId: 3, start: 4.1, end: 4.5),
        ])
        let ffmpeg = FFmpeg()
        let pipeline = makePipeline(
            repository: Repository(),
            ffmpeg: ffmpeg,
            resolver: Resolver(provider: speech),
            diarization: diarization
        )

        let output = try await pipeline.transcribe(request(project: edited)) { _ in }

        XCTAssertEqual(ffmpeg.clips, [
            ExportClipRange(sourceStartMs: 1_000, sourceEndMs: 3_000),
            ExportClipRange(sourceStartMs: 6_000, sourceEndMs: 8_000),
        ])
        XCTAssertEqual(output.project.mediaFile.durationMs, 10_000)
        XCTAssertEqual(output.project.subtitles.map(\.index), [1])
        XCTAssertEqual(output.project.subtitles.first?.endMs, 4_000)
        XCTAssertEqual(output.project.wordTimings.map(\.end), [4.0])
        XCTAssertEqual(output.project.speakerSegments.map(\.end), [4.0])
        XCTAssertEqual(output.project.speakerLabels, [SpeakerLabel(id: 1, displayName: "Host"), SpeakerLabel(id: 3, displayName: "Speaker 4")])
    }

    func testEmptyTimelineAndRenderingFailuresAreTypedAndPersistFailedState() async {
        var empty = project()
        empty.editTimeline = EditTimeline(clips: [], totalDurationMs: 0)
        let emptyRepository = Repository()
        let emptyFFmpeg = FFmpeg()
        await assertError(
            .emptyEditTimeline,
            pipeline: makePipeline(
                repository: emptyRepository,
                ffmpeg: emptyFFmpeg,
                resolver: Resolver(provider: Speech())
            ),
            project: empty
        )
        XCTAssertNil(emptyFFmpeg.outputURL)
        XCTAssertEqual(emptyRepository.saved.map(\.status), [
            .extractingAudio,
            .failed(TranscriptionPipelineError.emptyEditTimeline.errorDescription!),
        ])

        let missingRepository = Repository()
        await assertError(
            .renderingServiceUnavailable,
            pipeline: makePipeline(
                repository: missingRepository,
                ffmpeg: FFmpeg(error: FFmpegServiceError.notFound),
                resolver: Resolver(provider: Speech())
            ),
            project: project()
        )
        XCTAssertEqual(missingRepository.saved.last?.status, .failed("FFmpeg is not installed or path is incorrect."))

        await assertError(
            .renderingFailed(message: "Rendering failed."),
            pipeline: makePipeline(
                repository: Repository(),
                ffmpeg: FFmpeg(error: Failure.rendering),
                resolver: Resolver(provider: Speech())
            ),
            project: project()
        )
    }

    func testProviderFailureWarningSyntheticWordsAndRetry() async throws {
        let repository = Repository()
        let retry = Speech(errorSequence: [Failure.provider, nil])
        let alignment = Alignment()
        let pipeline = makePipeline(
            repository: repository,
            ffmpeg: FFmpeg(),
            resolver: Resolver(provider: retry),
            diarization: Diarization(error: Failure.diarization),
            alignment: alignment
        )

        await assertError(.providerFailed(message: "Provider unavailable."), pipeline: pipeline, project: project())
        XCTAssertEqual(repository.saved.last?.status, .failed("Provider unavailable."))

        let failedProject = repository.saved.last!
        let output = try await pipeline.transcribe(request(project: failedProject)) { _ in }
        XCTAssertEqual(output.project.status, .ready)
        XCTAssertEqual(output.warning, .speakerAnalysisUnavailable(detail: "Speaker engine unavailable."))
        XCTAssertEqual(retry.callCount, 2)

        let syntheticAlignment = Alignment()
        _ = try await makePipeline(
            repository: Repository(),
            ffmpeg: FFmpeg(),
            resolver: Resolver(provider: Speech()),
            alignment: syntheticAlignment
        ).transcribe(request(project: project())) { _ in }
        XCTAssertEqual(syntheticAlignment.words.map(\.text), ["Hello", "world"])
    }

    func testCancellationDoesNotPersistFailureAndCleanupFailureIsTyped() async {
        let repository = Repository()
        let files = Files()
        let pipeline = makePipeline(
            repository: repository,
            ffmpeg: FFmpeg(),
            resolver: Resolver(provider: Speech(errorSequence: [CancellationError()])),
            files: files
        )
        do {
            _ = try await pipeline.transcribe(request(project: project())) { _ in }
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(repository.saved.map(\.status), [.extractingAudio, .transcribing])
            XCTAssertEqual(files.removed.count, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let cleanupFiles = Files(removeError: Failure.cleanup)
        do {
            _ = try await makePipeline(
                repository: Repository(),
                ffmpeg: FFmpeg(),
                resolver: Resolver(provider: Speech(errorSequence: [CancellationError()])),
                files: cleanupFiles
            ).transcribe(request(project: project())) { _ in }
            XCTFail("Expected cleanup failure")
        } catch let error as TranscriptionPipelineError {
            XCTAssertEqual(error, .cancellationAndCleanupFailed(message: "Cleanup failed."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let speakerRepository = Repository()
        do {
            _ = try await makePipeline(
                repository: speakerRepository,
                ffmpeg: FFmpeg(),
                resolver: Resolver(provider: Speech()),
                diarization: Diarization(error: CancellationError())
            ).transcribe(request(project: project())) { _ in }
            XCTFail("Expected speaker cancellation")
        } catch is CancellationError {
            XCTAssertEqual(speakerRepository.saved.map(\.status), [.extractingAudio, .transcribing])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSuccessAndOperationCleanupFailuresRemainDistinct() async {
        do {
            _ = try await makePipeline(
                repository: Repository(),
                ffmpeg: FFmpeg(),
                resolver: Resolver(provider: Speech()),
                files: Files(removeError: Failure.cleanup)
            ).transcribe(request(project: project())) { _ in }
            XCTFail("Expected post-success cleanup failure")
        } catch let error as TranscriptionPipelineError {
            XCTAssertEqual(error, .temporaryAudioCleanupFailed(message: "Cleanup failed."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await makePipeline(
                repository: Repository(),
                ffmpeg: FFmpeg(),
                resolver: Resolver(provider: Speech(errorSequence: [Failure.provider])),
                files: Files(removeError: Failure.cleanup)
            ).transcribe(request(project: project())) { _ in }
            XCTFail("Expected operation and cleanup failure")
        } catch let error as TranscriptionPipelineError {
            XCTAssertEqual(error, .operationAndCleanupFailed(
                operation: "Provider unavailable.",
                cleanup: "Cleanup failed."
            ))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOperationPersistenceAndCleanupDiagnosticsAreCombined() async {
        let repository = Repository(failFailedSave: true)
        let files = Files(removeError: Failure.cleanup)
        do {
            _ = try await makePipeline(
                repository: repository,
                ffmpeg: FFmpeg(),
                resolver: Resolver(provider: Speech(errorSequence: [Failure.provider])),
                files: files
            ).transcribe(request(project: project())) { _ in }
            XCTFail("Expected combined failure")
        } catch let error as TranscriptionPipelineError {
            XCTAssertEqual(error, .persistenceAndCleanupFailed(
                operation: "Provider unavailable.",
                persistence: "Repository unavailable.",
                cleanup: "Cleanup failed."
            ))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTemporaryAudioURLsAreUniqueAcrossAttempts() async throws {
        let ffmpeg = FFmpeg()
        let pipeline = makePipeline(
            repository: Repository(),
            ffmpeg: ffmpeg,
            resolver: Resolver(provider: Speech())
        )
        _ = try await pipeline.transcribe(request(project: project())) { _ in }
        _ = try await pipeline.transcribe(request(project: project())) { _ in }
        XCTAssertEqual(Set(ffmpeg.outputURLs).count, 2)
    }

    private func makePipeline(
        repository: Repository,
        ffmpeg: FFmpeg,
        resolver: Resolver,
        diarization: Diarization = Diarization(),
        alignment: Alignment = Alignment(),
        files: Files = Files()
    ) -> any TranscribingProject {
        TranscriptionPipelineAssembly.makeTranscriber(
            projectRepository: repository,
            speechToTextProviderResolver: resolver,
            speakerDiarizationEngine: diarization,
            subtitleAlignmentEngine: alignment,
            makeFFmpegService: { configuration in
                ffmpeg.configuration = configuration
                return ffmpeg
            },
            fileSystem: TranscriptionPipelineFileSystem(
                fileExists: { files.exists($0) },
                removeItem: { try files.remove($0) }
            ),
            temporaryDirectory: URL(fileURLWithPath: "/tmp/transcription-pipeline-tests")
        )
    }

    private func request(project: Project) -> TranscriptionPipelineRequest {
        TranscriptionPipelineRequest(
            project: project,
            configuration: TranscriptionPipelineConfiguration(
                ffmpegExecutablePath: "/usr/local/bin/ffmpeg",
                speechToText: SpeechToTextProviderConfiguration(
                    providerName: "Whisper",
                    whisperExecutableURL: URL(fileURLWithPath: "/tmp/whisper"),
                    whisperModelURL: URL(fileURLWithPath: "/tmp/model.bin"),
                    whisperModelName: "large-v3",
                    whisperVADEnabled: false,
                    whisperVADModelURL: URL(fileURLWithPath: "/tmp/vad.bin")
                )
            )
        )
    }

    private func projectStatuses(_ events: [TranscriptionPipelineEvent]) -> [ProcessingStatus] {
        events.compactMap {
            if case .projectChanged(let project) = $0 { return project.status }
            return nil
        }
    }

    private func progressPhases(_ events: [TranscriptionPipelineEvent]) -> [TranscriptionPipelinePhase] {
        events.compactMap {
            if case .progress(let progress) = $0 { return progress.phase }
            return nil
        }
    }

    private func assertError(
        _ expected: TranscriptionPipelineError,
        pipeline: any TranscribingProject,
        project: Project
    ) async {
        do {
            _ = try await pipeline.transcribe(request(project: project)) { _ in }
            XCTFail("Expected \(expected)")
        } catch let error as TranscriptionPipelineError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private enum Failure: LocalizedError {
    case provider
    case rendering
    case diarization
    case cleanup
    case repository

    var errorDescription: String? {
        switch self {
        case .provider: "Provider unavailable."
        case .rendering: "Rendering failed."
        case .diarization: "Speaker engine unavailable."
        case .cleanup: "Cleanup failed."
        case .repository: "Repository unavailable."
        }
    }
}

private final class Repository: ProjectRepository {
    let failFailedSave: Bool
    var saved: [Project] = []

    init(failFailedSave: Bool = false) {
        self.failFailedSave = failFailedSave
    }

    func createProject(for mediaFile: MediaFile) async throws -> Project { throw Failure.repository }
    func saveProject(_ project: Project) async throws {
        if failFailedSave, case .failed = project.status { throw Failure.repository }
        saved.append(project)
    }
    func loadProject(id: UUID) async throws -> Project { throw Failure.repository }
    func listProjects() async throws -> [Project] { [] }
    func deleteProject(id: UUID) async throws {}
}

private final class FFmpeg: FFmpegService {
    let error: Error?
    var configuration: TranscriptionPipelineConfiguration?
    var clips: [ExportClipRange]?
    var outputURL: URL?
    var outputURLs: [URL] = []

    init(error: Error? = nil) { self.error = error }
    func checkAvailability() async throws -> FFmpegInfo {
        FFmpegInfo(executableURL: URL(fileURLWithPath: "/usr/bin/true"), version: "test")
    }
    func extractAudio(from videoURL: URL, to outputURL: URL, clips: [ExportClipRange]?) async throws -> URL {
        if let error { throw error }
        self.clips = clips
        self.outputURL = outputURL
        outputURLs.append(outputURL)
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

private final class Speech: SpeechToTextProvider {
    let result: TranscriptionResult
    var errorSequence: [Error?]
    var callCount = 0
    var input: TranscriptionInput?

    init(
        result: TranscriptionResult = TranscriptionResult(
            segments: [subtitle(index: 1, start: 0, end: 1_000, text: "Hello world")],
            words: [],
            detectedLanguage: "de",
            durationMs: 1_500
        ),
        errorSequence: [Error?] = []
    ) {
        self.result = result
        self.errorSequence = errorSequence
    }

    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        self.input = input
        let index = callCount
        callCount += 1
        await input.progressHandler?(0.7, "Recognizing...")
        if errorSequence.indices.contains(index), let error = errorSequence[index] { throw error }
        return result
    }
}

private final class Resolver: SpeechToTextProviderResolving {
    let provider: any SpeechToTextProvider
    var configuration: SpeechToTextProviderConfiguration?
    init(provider: any SpeechToTextProvider) { self.provider = provider }
    func resolve(configuration: SpeechToTextProviderConfiguration) throws -> any SpeechToTextProvider {
        self.configuration = configuration
        return provider
    }
}

private final class Diarization: SpeakerDiarizationEngine {
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

private final class Alignment: SubtitleAlignmentEngine {
    var words: [WordTiming] = []
    func align(
        words: [WordTiming],
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue] {
        self.words = words
        return existingCues
    }
    func align(
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue] { existingCues }
}

private final class Files {
    let removeError: Error?
    var removed: [URL] = []
    init(removeError: Error? = nil) { self.removeError = removeError }
    func exists(_ url: URL) -> Bool { true }
    func remove(_ url: URL) throws {
        removed.append(url)
        if let removeError { throw removeError }
    }
}

private func project() -> Project {
    Project(
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
        subtitles: [subtitle(index: 1, start: 0, end: 1_000, text: "Old")],
        status: .ready
    )
}

private func subtitle(index: Int, start: Int, end: Int, text: String) -> SubtitleSegment {
    SubtitleSegment(
        id: UUID(),
        index: index,
        startMs: start,
        endMs: end,
        originalText: text,
        translatedText: ""
    )
}
