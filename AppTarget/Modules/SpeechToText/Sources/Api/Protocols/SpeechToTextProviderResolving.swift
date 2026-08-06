public protocol SpeechToTextProviderResolving {
    func resolve(
        configuration: SpeechToTextProviderConfiguration
    ) throws -> any SpeechToTextProvider
}
