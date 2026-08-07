import Foundation

public enum WaveformServiceError: LocalizedError, Equatable, Sendable {
    case emptyAudio
    case unsupportedAudio

    public var errorDescription: String? {
        switch self {
        case .emptyAudio:
            return "Audio waveform could not be generated because the audio track is empty."
        case .unsupportedAudio:
            return "Audio waveform could not be generated from the extracted audio format."
        }
    }
}
