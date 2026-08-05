import FluidAudio
import Foundation

enum ParakeetLanguageSupport {
    static let supportedLanguageCodes: Set<String> = [
        "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr",
        "hr", "hu", "it", "lt", "lv", "mt", "nl", "pl", "pt", "ro",
        "ru", "sk", "sl", "sv", "uk"
    ]

    private static let displayNameLanguageCodes: [String: String] = [
        "bulgarian": "bg",
        "czech": "cs",
        "danish": "da",
        "dutch": "nl",
        "english": "en",
        "estonian": "et",
        "finnish": "fi",
        "french": "fr",
        "german": "de",
        "greek": "el",
        "croatian": "hr",
        "hungarian": "hu",
        "italian": "it",
        "latvian": "lv",
        "lithuanian": "lt",
        "maltese": "mt",
        "polish": "pl",
        "portuguese": "pt",
        "romanian": "ro",
        "russian": "ru",
        "slovak": "sk",
        "slovenian": "sl",
        "spanish": "es",
        "swedish": "sv",
        "ukrainian": "uk"
    ]

    static func isSupported(_ languageCode: String) -> Bool {
        guard let primarySubtag = primarySubtag(for: languageCode) else {
            return false
        }

        return supportedLanguageCodes.contains(primarySubtag)
    }

    static func fluidAudioLanguageHint(for languageCode: String?) -> Language? {
        guard let languageCode,
              let primarySubtag = primarySubtag(for: languageCode) else {
            return nil
        }

        return Language(rawValue: primarySubtag)
    }

    private static func primarySubtag(for languageCode: String) -> String? {
        let normalized = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        guard !normalized.isEmpty else {
            return nil
        }

        if let displayNameCode = displayNameLanguageCodes[normalized] {
            return displayNameCode
        }

        return normalized
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)
    }
}
