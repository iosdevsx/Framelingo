import Foundation
import Media
import MediaImpl
import Testing

@Suite("Media implementation")
struct MediaImplTests {
    @Test("Valid waveform cache avoids audio extraction")
    func cachedWaveform() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                if FileManager.default.fileExists(atPath: tempRoot.path) {
                    try FileManager.default.removeItem(at: tempRoot)
                }
            } catch {
                Issue.record("Temporary directory cleanup failed: \(error)")
            }
        }

        let projectID = UUID()
        let mediaURL = tempRoot.appendingPathComponent("video.mov")
        try FileManager.default.createDirectory(
            at: tempRoot,
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3, 4]).write(to: mediaURL)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: mediaURL.path
        )
        let modificationDate = try #require(attributes[.modificationDate] as? Date)
        let cache = WaveformCache(
            version: 4,
            mediaPath: mediaURL.path,
            mediaSizeBytes: 4,
            mediaModificationTime: modificationDate.timeIntervalSince1970,
            durationMs: 3_000,
            peaks: [0.1, 0.4, 0.8]
        )
        let cacheURL = tempRoot
            .appendingPathComponent("MediaTests", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("waveform.json")
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(cache).write(to: cacheURL)

        let loader = MediaAssembly.makeWaveformLoader(
            appName: "MediaTests",
            cacheRootURL: tempRoot
        )
        let request = WaveformRequest(
            projectID: projectID,
            mediaURL: mediaURL,
            mediaSizeBytes: 4,
            durationMs: 3_000
        )
        let waveform = try await loader.loadWaveform(
            for: request,
            audioProvider: {
                Issue.record("Expected cached waveform to avoid audio extraction.")
                throw CocoaError(.fileNoSuchFile)
            }
        )

        #expect(waveform == cache.peaks)
    }

    @Test("Passthrough audio preparation preserves URL")
    func passthroughAudio() async throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/video with пробелами.mov")
        let service = MediaAssembly.makePassthroughAudioPreparationService()

        let preparedAudioURL = try await service.preparedAudioURL(for: sourceURL)
        #expect(preparedAudioURL == sourceURL)
        try service.removePreparedAudio(for: sourceURL)
    }
}
