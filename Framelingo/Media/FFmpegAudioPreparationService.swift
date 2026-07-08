import CryptoKit
import Foundation

final class FFmpegAudioPreparationService: AudioPreparationService {
    private let appName: String
    private let cacheRootURL: URL?
    private let ffmpegService: FFmpegService

    init(
        ffmpegService: FFmpegService,
        appName: String = "Framelingo",
        cacheRootURL: URL? = nil
    ) {
        self.ffmpegService = ffmpegService
        self.appName = appName
        self.cacheRootURL = cacheRootURL
    }

    func preparedAudioURL(for sourceVideoURL: URL) async throws -> URL {
        let outputURL = preparedAudioURL(forSourceURL: sourceVideoURL)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        return try await ffmpegService.extractAudio(
            from: sourceVideoURL,
            to: outputURL
        )
    }

    func removePreparedAudio(for sourceVideoURL: URL) throws {
        let outputURL = preparedAudioURL(forSourceURL: sourceVideoURL)
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: outputURL)
    }

    private func preparedAudioURL(forSourceURL sourceURL: URL) -> URL {
        cacheDirectoryURL()
            .appendingPathComponent(cacheKey(for: sourceURL), isDirectory: false)
            .appendingPathExtension("wav")
    }

    private func cacheDirectoryURL() -> URL {
        let applicationSupportURL = cacheRootURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return applicationSupportURL
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("Cache", isDirectory: true)
            .appendingPathComponent("prepared-audio", isDirectory: true)
    }

    private func cacheKey(for sourceURL: URL) -> String {
        let bytes = SHA256.hash(data: Data(sourceURL.standardizedFileURL.absoluteString.utf8))
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
