import Foundation

public protocol AudioPreparationService {
    func preparedAudioURL(for sourceVideoURL: URL) async throws -> URL
    func removePreparedAudio(for sourceVideoURL: URL) throws
}
