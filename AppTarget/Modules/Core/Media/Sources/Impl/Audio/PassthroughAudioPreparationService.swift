import Foundation
import Media

public struct PassthroughAudioPreparationService: AudioPreparationService {
    public init() {
    }

    public func preparedAudioURL(for sourceVideoURL: URL) async throws -> URL {
        sourceVideoURL
    }

    public func removePreparedAudio(for sourceVideoURL: URL) throws {}
}
