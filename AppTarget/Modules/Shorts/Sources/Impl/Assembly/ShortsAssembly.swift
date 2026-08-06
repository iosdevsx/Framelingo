import Shorts

public enum ShortsAssembly {
    public static func makeSuggestionService() -> ShortsSuggestionService {
        ShortsSuggestionService()
    }

    public static func makeTimelineMappingService() -> SubtitleTimelineMappingService {
        SubtitleTimelineMappingService()
    }
}
