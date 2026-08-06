public struct SpeechToTextProviderCapabilities: Equatable, Sendable {
    public var supportedLanguageCodes: Set<String>
    public var supportsAutomaticLanguageDetection: Bool
    public var supportsWordTimings: Bool

    public init(
        supportedLanguageCodes: Set<String>,
        supportsAutomaticLanguageDetection: Bool,
        supportsWordTimings: Bool
    ) {
        self.supportedLanguageCodes = supportedLanguageCodes
        self.supportsAutomaticLanguageDetection = supportsAutomaticLanguageDetection
        self.supportsWordTimings = supportsWordTimings
    }
}
