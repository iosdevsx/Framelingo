import AVFoundation
import Foundation
import Media

struct MediaMetadataService: MediaMetadataProviding {
    func durationMs(for url: URL) async throws -> Int? {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)

        guard seconds.isFinite, seconds > 0 else {
            return nil
        }

        return Int((seconds * 1_000).rounded())
    }

    func videoMetadata(for url: URL) async throws -> VideoMetadata {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw MediaMetadataError.videoTrackMissing
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let displaySize = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
            .size
        let width = Int(abs(displaySize.width).rounded())
        let height = Int(abs(displaySize.height).rounded())

        guard width > 0, height > 0 else {
            throw MediaMetadataError.invalidVideoDimensions
        }

        return VideoMetadata(
            width: width,
            height: height,
            nominalFrameRate: Double(nominalFrameRate)
        )
    }
}
