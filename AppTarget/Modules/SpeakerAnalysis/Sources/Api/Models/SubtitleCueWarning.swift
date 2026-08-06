public enum SubtitleCueWarning: String, Codable, Hashable, Sendable {
    case overlappingSpeakers
    case lowConfidenceSpeaker
    case tooLong
    case tooShort
    case noSpeakerDetected
}
