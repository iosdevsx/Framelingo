import Foundation

enum WhisperModel: String, CaseIterable, Identifiable, Codable {
    case tiny
    case base
    case small
    case largeV3Turbo = "large-v3-turbo"
    case largeV3TurboQ5_0 = "large-v3-turbo-q5_0"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny:
            return "Tiny"
        case .base:
            return "Base"
        case .small:
            return "Small"
        case .largeV3Turbo:
            return "Large v3 Turbo"
        case .largeV3TurboQ5_0:
            return "Large v3 Turbo (Quantized)"
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
        case .largeV3Turbo:
            return "~1.6 GB"
        case .largeV3TurboQ5_0:
            return "~574 MB"
        }
    }

    var isRecommended: Bool {
        self == .largeV3TurboQ5_0
    }

    /// whisper.cpp `--dtw` alignment-heads preset for this model architecture.
    /// Quantization does not change the architecture, so both turbo variants share a preset.
    var dtwPreset: String {
        switch self {
        case .tiny:
            return "tiny"
        case .base:
            return "base"
        case .small:
            return "small"
        case .largeV3Turbo, .largeV3TurboQ5_0:
            return "large.v3.turbo"
        }
    }
}

/// Silero VAD model used by `whisper-cli --vad`. Not a transcription model —
/// it must never appear in the model picker, hence a separate type.
enum WhisperVADModel {
    static let fileName = "ggml-silero-v5.1.2.bin"

    static var downloadURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.path = "/ggml-org/whisper-vad/resolve/main/\(fileName)"
        return components.url ?? URL(fileURLWithPath: fileName)
    }
}

enum SpeechToTextProviderName {
    static let mock = "Mock Speech-to-Text"
    static let localWhisper = "Local Whisper"
}
