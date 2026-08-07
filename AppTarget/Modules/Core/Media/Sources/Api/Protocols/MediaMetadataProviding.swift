import Foundation

public protocol MediaMetadataProviding {
    func durationMs(for url: URL) async throws -> Int?
    func videoMetadata(for url: URL) async throws -> VideoMetadata
}
