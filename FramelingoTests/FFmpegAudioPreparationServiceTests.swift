import Foundation
import Testing
@testable import Framelingo

struct FFmpegAudioPreparationServiceTests {
    @Test
    func testPreparedAudioIsCachedBySourceURL() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FramelingoTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let ffmpegService = CountingFFmpegService()
        let service = FFmpegAudioPreparationService(
            ffmpegService: ffmpegService,
            cacheRootURL: temporaryDirectory
        )
        let sourceURL = URL(fileURLWithPath: "/tmp/video with пробелами.mov")

        let firstURL = try await service.preparedAudioURL(for: sourceURL)
        let secondURL = try await service.preparedAudioURL(for: sourceURL)

        #expect(firstURL == secondURL)
        #expect(FileManager.default.fileExists(atPath: firstURL.path))
        #expect(await ffmpegService.extractionCount == 1)
    }

    @Test
    func testRemovePreparedAudioDeletesCachedFile() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FramelingoTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let service = FFmpegAudioPreparationService(
            ffmpegService: CountingFFmpegService(),
            cacheRootURL: temporaryDirectory
        )
        let sourceURL = URL(fileURLWithPath: "/tmp/interview.mov")
        let audioURL = try await service.preparedAudioURL(for: sourceURL)

        try service.removePreparedAudio(for: sourceURL)

        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
    }
}

private final class CountingFFmpegService: FFmpegService {
    private let counter = ExtractionCounter()

    var extractionCount: Int {
        get async {
            await counter.value
        }
    }

    func checkAvailability() async throws -> FFmpegInfo {
        FFmpegInfo(
            executableURL: URL(fileURLWithPath: "/usr/bin/false"),
            version: "test"
        )
    }

    func extractAudio(from videoURL: URL, to outputURL: URL) async throws -> URL {
        await counter.increment()
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("wav".utf8).write(to: outputURL, options: .atomic)
        return outputURL
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        outputURL
    }
}

private actor ExtractionCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
