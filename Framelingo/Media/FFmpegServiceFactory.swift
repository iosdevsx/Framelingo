import Foundation

enum FFmpegServiceFactory {
    static func makeDefaultService(settings: AppSettings) -> FFmpegService {
        #if canImport(ffmpegkit)
        FFmpegKitFFmpegService()
        #else
        ProcessFFmpegService(
            preferredExecutableURL: URL(fileURLWithPath: normalizedFFmpegPath(settings.ffmpegPath))
        )
        #endif
    }

    static var usesEmbeddedFFmpegKit: Bool {
        #if canImport(ffmpegkit)
        true
        #else
        false
        #endif
    }

    private static func normalizedFFmpegPath(_ path: String) -> String {
        path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
