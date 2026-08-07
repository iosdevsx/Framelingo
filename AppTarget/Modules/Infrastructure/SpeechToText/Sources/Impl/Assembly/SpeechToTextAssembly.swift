import Foundation
import SpeechToText
import Subtitles

public enum SpeechToTextAssembly {
    public static func makeProviderResolver(
        subtitleParser: any SubtitleParsing
    ) -> any SpeechToTextProviderResolving {
        ConfiguredSpeechToTextProviderResolver(subtitleParser: subtitleParser)
    }

    public static func makeProvider(
        configuration: SpeechToTextProviderConfiguration,
        subtitleParser: any SubtitleParsing
    ) throws -> any SpeechToTextProvider {
        switch configuration.providerName {
        case SpeechToTextProviderName.localWhisper:
#if os(macOS)
            return try makeLocalWhisperProvider(
                configuration: configuration,
                subtitleParser: subtitleParser
            )
#else
            throw SpeechToTextError.executableMissing
#endif
        case SpeechToTextProviderName.localParakeet:
#if os(macOS)
            return ParakeetSpeechToTextProvider(
                fallback: makeLocalWhisperFallback(
                    configuration: configuration,
                    subtitleParser: subtitleParser
                )
            )
#else
            return ParakeetSpeechToTextProvider()
#endif
        default:
            return MockSpeechToTextProvider()
        }
    }

    public static func makeMockProvider() -> any SpeechToTextProvider {
        MockSpeechToTextProvider()
    }

    public static func makeWhisperModelManager() -> any WhisperModelManaging {
#if os(macOS)
        WhisperInstaller()
#else
        UnavailableWhisperModelManager()
#endif
    }

    public static func makeParakeetModelManager() -> any ParakeetModelManaging {
        ParakeetModelStore()
    }

#if os(macOS)
    private static func makeLocalWhisperProvider(
        configuration: SpeechToTextProviderConfiguration,
        subtitleParser: any SubtitleParsing
    ) throws -> LocalWhisperSpeechToTextProvider {
        guard let executableURL = configuration.whisperExecutableURL,
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw WhisperTranscriptionError.executableMissing
        }
        guard let modelURL = configuration.whisperModelURL,
              FileManager.default.fileExists(atPath: modelURL.path) else {
            throw WhisperTranscriptionError.modelMissing
        }
        return LocalWhisperSpeechToTextProvider(
            executableURL: executableURL,
            modelURL: modelURL,
            whisperModelName: configuration.whisperModelName,
            vadEnabled: configuration.whisperVADEnabled,
            vadModelURL: configuration.whisperVADModelURL,
            subtitleParser: subtitleParser
        )
    }

    private static func makeLocalWhisperFallback(
        configuration: SpeechToTextProviderConfiguration,
        subtitleParser: any SubtitleParsing
    ) -> LocalWhisperSpeechToTextProvider? {
        do {
            return try makeLocalWhisperProvider(
                configuration: configuration,
                subtitleParser: subtitleParser
            )
        } catch {
            return nil
        }
    }
#endif
}
