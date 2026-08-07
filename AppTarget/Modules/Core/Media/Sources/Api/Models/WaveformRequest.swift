import Foundation

public struct WaveformRequest: Equatable, Sendable {
    public var projectID: UUID
    public var mediaURL: URL
    public var mediaSizeBytes: Int64
    public var durationMs: Int?
    public var fallbackContentEndMs: Int?

    public init(
        projectID: UUID,
        mediaURL: URL,
        mediaSizeBytes: Int64,
        durationMs: Int?,
        fallbackContentEndMs: Int? = nil
    ) {
        self.projectID = projectID
        self.mediaURL = mediaURL
        self.mediaSizeBytes = mediaSizeBytes
        self.durationMs = durationMs
        self.fallbackContentEndMs = fallbackContentEndMs
    }
}
