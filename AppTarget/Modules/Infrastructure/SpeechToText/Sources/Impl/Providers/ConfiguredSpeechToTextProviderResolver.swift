import SpeechToText
import Subtitles

struct ConfiguredSpeechToTextProviderResolver: SpeechToTextProviderResolving {
    let subtitleParser: any SubtitleParsing

    func resolve(
        configuration: SpeechToTextProviderConfiguration
    ) throws -> any SpeechToTextProvider {
        try SpeechToTextAssembly.makeProvider(
            configuration: configuration,
            subtitleParser: subtitleParser
        )
    }
}
