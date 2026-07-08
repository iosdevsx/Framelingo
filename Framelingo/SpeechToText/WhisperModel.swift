import Foundation

enum WhisperModel: String, CaseIterable, Identifiable, Codable {
    case tiny
    case base
    case small

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny:
            return "Tiny"
        case .base:
            return "Base"
        case .small:
            return "Small"
        }
    }

    var fileName: String {
        "ggml-\(rawValue).bin"
    }

    var downloadURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.path = "/ggerganov/whisper.cpp/resolve/main/\(fileName)"
        return components.url ?? URL(fileURLWithPath: fileName)
    }

    var approximateSizeText: String {
        switch self {
        case .tiny:
            return "~75 MB"
        case .base:
            return "~142 MB"
        case .small:
            return "~466 MB"
        }
    }
}

enum SpeechToTextProviderName {
    static let mock = "Mock Speech-to-Text"
    static let localWhisper = "Local Whisper"
}
