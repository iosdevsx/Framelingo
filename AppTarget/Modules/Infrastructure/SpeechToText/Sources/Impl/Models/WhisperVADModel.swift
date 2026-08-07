import Foundation

#if os(macOS)
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
#endif
