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

    func videoSourceInfo(for url: URL) async throws -> VideoSourceInfo {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw MediaMetadataError.videoTrackMissing
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let displaySize = VideoExportGeometry.displaySize(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )
        let width = Int(displaySize.width.rounded())
        let height = Int(displaySize.height.rounded())

        guard width > 0, height > 0 else {
            throw MediaMetadataError.invalidVideoDimensions
        }

        return VideoSourceInfo(
            width: width,
            height: height,
            nominalFrameRate: Double(nominalFrameRate)
        )
    }
}

enum MediaMetadataError: LocalizedError, Equatable {
    case videoTrackMissing
    case invalidVideoDimensions

    var errorDescription: String? {
        switch self {
        case .videoTrackMissing:
            return "The video track could not be read."
        case .invalidVideoDimensions:
            return "The video dimensions are invalid."
        }
    }
}
