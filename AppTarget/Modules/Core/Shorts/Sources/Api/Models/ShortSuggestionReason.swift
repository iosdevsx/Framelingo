public enum ShortSuggestionReason: Equatable {
    case pause
    case speakerChange
    case durationLimit
    case endOfVideo

    public var displayName: String {
        switch self {
        case .pause:
            return "Pause"
        case .speakerChange:
            return "Speaker change"
        case .durationLimit:
            return "Duration limit"
        case .endOfVideo:
            return "End of video"
        }
    }
}
