import Subtitles

public struct SubtitleTranslationInput: Equatable {
    public var segments: [SubtitleSegment]
    public var sourceLanguage: String
    public var targetLanguage: String
    public var style: TranslationStyle

    public init(
        segments: [SubtitleSegment],
        sourceLanguage: String,
        targetLanguage: String,
        style: TranslationStyle
    ) {
        self.segments = segments
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.style = style
    }
}
