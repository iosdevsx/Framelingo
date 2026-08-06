import Foundation

public struct WaveformCache: Codable, Equatable, Sendable {
    public var version: Int
    public var mediaPath: String
    public var mediaSizeBytes: Int64
    public var mediaModificationTime: TimeInterval?
    public var durationMs: Int
    public var peaks: [Double]

    public init(
        version: Int,
        mediaPath: String,
        mediaSizeBytes: Int64,
        mediaModificationTime: TimeInterval?,
        durationMs: Int,
        peaks: [Double]
    ) {
        self.version = version
        self.mediaPath = mediaPath
        self.mediaSizeBytes = mediaSizeBytes
        self.mediaModificationTime = mediaModificationTime
        self.durationMs = durationMs
        self.peaks = peaks
    }
}
