import AVFoundation
import Foundation

struct MediaMetadataService {
    func durationMs(for url: URL) async throws -> Int? {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)

        guard seconds.isFinite, seconds > 0 else {
            return nil
        }

        return Int((seconds * 1_000).rounded())
    }
}
