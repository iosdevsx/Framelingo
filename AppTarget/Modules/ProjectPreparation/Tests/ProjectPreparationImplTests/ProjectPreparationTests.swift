import Foundation
import Media
import Project
import ProjectPreparation
import ProjectPreparationImpl
import Subtitles
import VideoRendering
import XCTest

final class ProjectPreparationTests: XCTestCase {
    func testConfigurationCarriesOnlyCurrentFFmpegSelectionInput() {
        let configuration = ProjectPreparationConfiguration(ffmpegExecutablePath: "/Applications/Tools/ffmpeg")

        XCTAssertEqual(configuration.ffmpegExecutablePath, "/Applications/Tools/ffmpeg")
    }

    func testMetadataDurationWaveformAndEventOrder() async throws {
        var project = makeProject()
        project.mediaFile.durationMs = nil
        let metadata = Metadata()
        let waveform = Waveform()
        let ffmpeg = FFmpeg()
        var receivedConfiguration: ProjectPreparationConfiguration?
        var events: [ProjectPreparationEvent] = []
        let preparer = makePreparer(
            metadata: metadata,
            waveform: waveform,
            makeFFmpeg: {
                receivedConfiguration = $0
                return ffmpeg
            }
        )

        let output = try await preparer.prepare(
            ProjectPreparationRequest(
                project: project,
                configuration: ProjectPreparationConfiguration(ffmpegExecutablePath: "/custom/ffmpeg")
            ),
            events: { events.append($0) }
        )

        XCTAssertEqual(output.project.mediaFile.durationMs, 12_000)
        XCTAssertEqual(output.videoSourceInfo, VideoSourceInfo(width: 1920, height: 1080, nominalFrameRate: 30))
        XCTAssertEqual(output.waveformPeaks, [0.2, 0.8])
        XCTAssertEqual(output.outcome, .ready)
        XCTAssertEqual(receivedConfiguration?.ffmpegExecutablePath, "/custom/ffmpeg")
        XCTAssertEqual(ffmpeg.outputURL, waveform.audioURL)
        XCTAssertEqual(waveform.request?.projectID, project.id)
        XCTAssertEqual(waveform.request?.mediaURL, project.mediaFile.originalURL)
        XCTAssertEqual(waveform.request?.mediaSizeBytes, project.mediaFile.sizeBytes)
        XCTAssertEqual(waveform.request?.durationMs, 12_000)
        XCTAssertEqual(waveform.request?.fallbackContentEndMs, 2_000)
        XCTAssertEqual(phases(in: events), [.readingSourceMetadata, .readingDuration, .preparingWaveform])
        XCTAssertTrue(events.contains { event in
            guard case .projectChanged(let updated) = event else { return false }
            return updated.mediaFile.durationMs == 12_000
        })
    }

    func testExistingDurationSkipsDurationLookupAndCachedWaveformSkipsAudioExtraction() async throws {
        let metadata = Metadata()
        let waveform = Waveform(usesAudioProvider: false)
        let ffmpeg = FFmpeg()
        let output = try await makePreparer(metadata: metadata, waveform: waveform, ffmpeg: ffmpeg).prepare(
            request(),
            events: { _ in }
        )

        XCTAssertEqual(metadata.durationCallCount, 0)
        XCTAssertNil(ffmpeg.outputURL)
        XCTAssertEqual(output.outcome, .ready)
    }

    func testMetadataAndDurationFailuresAreRecoverable() async throws {
        var project = makeProject()
        project.mediaFile.durationMs = nil
        let output = try await makePreparer(
            metadata: Metadata(metadataError: Failure.metadata, durationError: Failure.duration),
            waveform: Waveform(),
            ffmpeg: FFmpeg()
        ).prepare(
            ProjectPreparationRequest(project: project, configuration: configuration()),
            events: { _ in }
        )

        XCTAssertNil(output.videoSourceInfo)
        XCTAssertNil(output.project.mediaFile.durationMs)
        XCTAssertEqual(output.outcome, .ready)
    }

    func testWaveformFailureReturnsTypedDegradationAndCleansTemporaryAudio() async throws {
        var removedURLs: [URL] = []
        let output = try await makePreparer(
            metadata: Metadata(),
            waveform: Waveform(errorAfterAudio: Failure.waveform),
            ffmpeg: FFmpeg(),
            fileSystem: ProjectPreparationFileSystem(
                fileExists: { _ in true },
                removeItem: { removedURLs.append($0) }
            )
        ).prepare(request(), events: { _ in })

        XCTAssertEqual(output.waveformPeaks, [])
        XCTAssertEqual(output.outcome, .degraded(.waveformUnavailable))
        XCTAssertEqual(removedURLs.count, 1)
    }

    func testWaveformAndCleanupFailureReturnsTypedDegradationWarning() async throws {
        let output = try await makePreparer(
            metadata: Metadata(),
            waveform: Waveform(errorAfterAudio: Failure.waveform),
            ffmpeg: FFmpeg(),
            fileSystem: failingCleanupFileSystem
        ).prepare(request(), events: { _ in })

        guard case .degraded(.waveformUnavailableAndCleanupFailed(let message)) = output.outcome else {
            return XCTFail("Expected degraded cleanup outcome")
        }
        XCTAssertEqual(message, "Cleanup failed.")
    }

    func testSuccessfulWaveformCleanupFailureIsExplicitError() async {
        do {
            _ = try await makePreparer(
                metadata: Metadata(),
                waveform: Waveform(),
                ffmpeg: FFmpeg(),
                fileSystem: failingCleanupFileSystem
            ).prepare(request(), events: { _ in })
            XCTFail("Expected cleanup error")
        } catch let error as ProjectPreparationError {
            XCTAssertEqual(error, .temporaryAudioCleanupFailed(message: "Cleanup failed."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancellationCleansTemporaryAudioAndRemainsCancellation() async {
        var removalCount = 0
        do {
            _ = try await makePreparer(
                metadata: Metadata(),
                waveform: Waveform(errorAfterAudio: CancellationError()),
                ffmpeg: FFmpeg(),
                fileSystem: ProjectPreparationFileSystem(
                    fileExists: { _ in true },
                    removeItem: { _ in removalCount += 1 }
                )
            ).prepare(request(), events: { _ in })
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(removalCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancellationAndCleanupFailureIsExplicitError() async {
        do {
            _ = try await makePreparer(
                metadata: Metadata(),
                waveform: Waveform(errorAfterAudio: CancellationError()),
                ffmpeg: FFmpeg(),
                fileSystem: failingCleanupFileSystem
            ).prepare(request(), events: { _ in })
            XCTFail("Expected cancellation plus cleanup error")
        } catch let error as ProjectPreparationError {
            XCTAssertEqual(error, .cancellationAndCleanupFailed(message: "Cleanup failed."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMetadataCancellationIsNotDegraded() async {
        do {
            _ = try await makePreparer(
                metadata: Metadata(metadataError: CancellationError()),
                waveform: Waveform(),
                ffmpeg: FFmpeg()
            ).prepare(request(), events: { _ in })
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTemporaryAudioURLsAreUniqueAndProjectScoped() async throws {
        let ffmpeg = FFmpeg()
        let preparer = makePreparer(metadata: Metadata(), waveform: Waveform(), ffmpeg: ffmpeg)
        let firstProject = makeProject()
        _ = try await preparer.prepare(
            ProjectPreparationRequest(project: firstProject, configuration: configuration()),
            events: { _ in }
        )
        let firstURL = try XCTUnwrap(ffmpeg.outputURL)
        let secondProject = makeProject()
        _ = try await preparer.prepare(
            ProjectPreparationRequest(project: secondProject, configuration: configuration()),
            events: { _ in }
        )
        let secondURL = try XCTUnwrap(ffmpeg.outputURL)

        XCTAssertNotEqual(firstURL, secondURL)
        XCTAssertTrue(firstURL.path.contains(firstProject.id.uuidString))
        XCTAssertTrue(secondURL.path.contains(secondProject.id.uuidString))
    }

    private var failingCleanupFileSystem: ProjectPreparationFileSystem {
        ProjectPreparationFileSystem(
            fileExists: { _ in true },
            removeItem: { _ in throw Failure.cleanup }
        )
    }

    private func makePreparer(
        metadata: Metadata,
        waveform: Waveform,
        ffmpeg: FFmpeg,
        fileSystem: ProjectPreparationFileSystem = ProjectPreparationFileSystem(
            fileExists: { _ in false },
            removeItem: { _ in }
        )
    ) -> any ProjectPreparing {
        makePreparer(
            metadata: metadata,
            waveform: waveform,
            makeFFmpeg: { _ in ffmpeg },
            fileSystem: fileSystem
        )
    }

    private func makePreparer(
        metadata: Metadata,
        waveform: Waveform,
        makeFFmpeg: @escaping ProjectPreparationFFmpegServiceBuilder,
        fileSystem: ProjectPreparationFileSystem = ProjectPreparationFileSystem(
            fileExists: { _ in false },
            removeItem: { _ in }
        )
    ) -> any ProjectPreparing {
        ProjectPreparationAssembly.makeProjectPreparer(
            mediaMetadataProvider: metadata,
            waveformLoader: waveform,
            makeFFmpegService: makeFFmpeg,
            fileSystem: fileSystem,
            temporaryDirectory: URL(fileURLWithPath: "/tmp/project-preparation-tests", isDirectory: true)
        )
    }

    private func request() -> ProjectPreparationRequest {
        ProjectPreparationRequest(project: makeProject(), configuration: configuration())
    }

    private func configuration() -> ProjectPreparationConfiguration {
        ProjectPreparationConfiguration(ffmpegExecutablePath: "/usr/bin/ffmpeg")
    }

    private func phases(in events: [ProjectPreparationEvent]) -> [ProjectPreparationPhase] {
        events.compactMap { event in
            guard case .progress(let progress) = event else { return nil }
            return progress.phase
        }
    }
}

private enum Failure: LocalizedError {
    case metadata
    case duration
    case waveform
    case cleanup

    var errorDescription: String? {
        switch self {
        case .metadata: "Metadata failed."
        case .duration: "Duration failed."
        case .waveform: "Waveform failed."
        case .cleanup: "Cleanup failed."
        }
    }
}

private final class Metadata: MediaMetadataProviding {
    let metadataError: Error?
    let durationError: Error?
    var durationCallCount = 0

    init(metadataError: Error? = nil, durationError: Error? = nil) {
        self.metadataError = metadataError
        self.durationError = durationError
    }

    func durationMs(for url: URL) async throws -> Int? {
        durationCallCount += 1
        if let durationError { throw durationError }
        return 12_000
    }

    func videoMetadata(for url: URL) async throws -> VideoMetadata {
        if let metadataError { throw metadataError }
        return VideoMetadata(width: 1920, height: 1080, nominalFrameRate: 30)
    }
}

private final class Waveform: WaveformLoading {
    let usesAudioProvider: Bool
    let errorAfterAudio: Error?
    var request: WaveformRequest?
    var audioURL: URL?

    init(usesAudioProvider: Bool = true, errorAfterAudio: Error? = nil) {
        self.usesAudioProvider = usesAudioProvider
        self.errorAfterAudio = errorAfterAudio
    }

    func loadWaveform(
        for request: WaveformRequest,
        audioProvider: @escaping WaveformAudioProvider,
        progressHandler: WaveformProgressHandler?
    ) async throws -> [Double] {
        self.request = request
        if let progressHandler { await progressHandler(0.5, "Loading waveform...") }
        if usesAudioProvider {
            audioURL = try await audioProvider()
        }
        if let errorAfterAudio { throw errorAfterAudio }
        return [0.2, 0.8]
    }
}

private final class FFmpeg: FFmpegService {
    var outputURL: URL?

    func checkAvailability() async throws -> FFmpegInfo {
        FFmpegInfo(executableURL: URL(fileURLWithPath: "/usr/bin/ffmpeg"), version: "test")
    }

    func extractAudio(from videoURL: URL, to outputURL: URL, clips: [ExportClipRange]?) async throws -> URL {
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
    ) async throws -> URL {
        outputURL
    }
}

private func makeProject() -> Project {
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
            sizeBytes: 42,
            durationMs: 10_000
        ),
        sourceLanguage: "English",
        targetLanguage: "Russian",
        subtitles: [
            SubtitleSegment(
                id: UUID(),
                index: 1,
                startMs: 0,
                endMs: 2_000,
                originalText: "Hello",
                translatedText: ""
            ),
        ],
        status: .ready
    )
}
