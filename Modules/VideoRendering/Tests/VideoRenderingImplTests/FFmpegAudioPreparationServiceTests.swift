import Foundation
import Media
import Testing
import VideoRendering
@testable import VideoRenderingImpl

struct FFmpegAudioPreparationServiceTests {
    @Test
    func testPreparedAudioIsCachedBySourceURL() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FramelingoTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                if FileManager.default.fileExists(atPath: temporaryDirectory.path) {
                    try FileManager.default.removeItem(at: temporaryDirectory)
                }
            } catch {
                Issue.record("Temporary directory cleanup failed: \(error)")
            }
        }

        let ffmpegService = CountingFFmpegService()
        let service = FFmpegAudioPreparationService(
            ffmpegService: ffmpegService,
            cacheRootURL: temporaryDirectory
        )
        let sourceURL = URL(fileURLWithPath: "/tmp/video with пробелами.mov")

        let firstAudio = try await service.preparedAudioURL(for: sourceURL)
        let secondAudio = try await service.preparedAudioURL(for: sourceURL)

        #expect(firstAudio == secondAudio)
        #expect(FileManager.default.fileExists(atPath: firstAudio.path))
        #expect(await ffmpegService.extractionCount == 1)
    }

    @Test
    func testRemovePreparedAudioDeletesCachedFile() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FramelingoTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                if FileManager.default.fileExists(atPath: temporaryDirectory.path) {
                    try FileManager.default.removeItem(at: temporaryDirectory)
                }
            } catch {
                Issue.record("Temporary directory cleanup failed: \(error)")
            }
        }

        let service = FFmpegAudioPreparationService(
            ffmpegService: CountingFFmpegService(),
            cacheRootURL: temporaryDirectory
        )
        let sourceURL = URL(fileURLWithPath: "/tmp/interview.mov")
        let preparedAudioURL = try await service.preparedAudioURL(for: sourceURL)

        try service.removePreparedAudio(for: sourceURL)

        #expect(!FileManager.default.fileExists(atPath: preparedAudioURL.path))
    }
}
