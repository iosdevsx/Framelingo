import Foundation

protocol AudioPreparationService {
    func preparedAudioURL(for sourceVideoURL: URL) async throws -> URL
    func removePreparedAudio(for sourceVideoURL: URL) throws
}

struct PassthroughAudioPreparationService: AudioPreparationService {
    init() {
    }

    func preparedAudioURL(for sourceVideoURL: URL) async throws -> URL {
        sourceVideoURL
    }

    func removePreparedAudio(for sourceVideoURL: URL) throws {}
}
