import Foundation
import XCTest
@testable import Framelingo

final class WaveformServiceTests: XCTestCase {
    func testLoadWaveformUsesValidCacheWithoutExtractingAudio() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FramelingoTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let projectID = UUID()
        let mediaURL = tempRoot.appendingPathComponent("video.mov")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try Data([1, 2, 3, 4]).write(to: mediaURL)

        let project = Project(
            id: projectID,
            name: "Cached Waveform",
            createdAt: Date(),
            updatedAt: Date(),
            mediaFile: MediaFile(
                id: UUID(),
                originalURL: mediaURL,
                fileName: "video.mov",
                fileExtension: "mov",
                sizeBytes: 4,
                durationMs: 3_000
            ),
            sourceLanguage: "English",
            targetLanguage: "Russian",
            subtitles: [],
            status: .ready
        )

        let attributes = try FileManager.default.attributesOfItem(atPath: mediaURL.path)
        let modificationDate = try XCTUnwrap(attributes[.modificationDate] as? Date)
        let cache = WaveformCache(
            version: 4,
            mediaPath: mediaURL.path,
            mediaSizeBytes: 4,
            mediaModificationTime: modificationDate.timeIntervalSince1970,
            durationMs: 3_000,
            peaks: [0.1, 0.4, 0.8]
        )
        let cacheURL = tempRoot
            .appendingPathComponent("FramelingoTests", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("waveform.json")
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(cache).write(to: cacheURL)

        let service = WaveformService(appName: "FramelingoTests", cacheRootURL: tempRoot)
        let peaks = try await service.loadWaveform(for: project, ffmpegService: FailingFFmpegService())

        XCTAssertEqual(peaks, cache.peaks)
    }
}

private struct FailingFFmpegService: FFmpegService {
    func checkAvailability() async throws -> FFmpegInfo {
        FFmpegInfo(executableURL: URL(fileURLWithPath: "/usr/bin/false"), version: "test")
    }

    func extractAudio(from videoURL: URL, to outputURL: URL) async throws -> URL {
        XCTFail("Expected cached waveform to avoid audio extraction.")
        throw CocoaError(.fileNoSuchFile)
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        XCTFail("Unexpected burnSubtitles call.")
        throw CocoaError(.fileNoSuchFile)
    }
}
