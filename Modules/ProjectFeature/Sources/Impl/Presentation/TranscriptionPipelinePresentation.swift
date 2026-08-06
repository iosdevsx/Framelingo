import Foundation
import Settings
import SpeechToText
import TranscriptionPipeline

enum TranscriptionPipelinePresentation {
    static func configuration(from settings: AppSettings) -> TranscriptionPipelineConfiguration {
        TranscriptionPipelineConfiguration(
            ffmpegExecutablePath: settings.ffmpegPath,
            speechToText: SpeechToTextProviderConfiguration(
                providerName: settings.speechToTextProviderName,
                whisperExecutableURL: fileURL(from: settings.whisperExecutablePath),
                whisperModelURL: fileURL(from: settings.whisperModelPath),
                whisperModelName: settings.whisperModelName,
                whisperVADEnabled: settings.whisperVADEnabled,
                whisperVADModelURL: fileURL(from: settings.whisperVADModelPath)
            )
        )
    }

    static func status(for progress: TranscriptionPipelineProgress) -> String {
        if let detail = progress.providerDetail?.trimmingCharacters(in: .whitespacesAndNewlines),
           !detail.isEmpty {
            return detail
        }
        return switch progress.phase {
        case .extractingAudio: "Extracting audio..."
        case .transcribing: "Transcribing audio..."
        case .analyzingSpeakers: "Analyzing speakers..."
        case .aligningSubtitles: "Aligning subtitles..."
        }
    }

    static func completionMessage(for warning: TranscriptionPipelineWarning?) -> String? {
        guard case .speakerAnalysisUnavailable(let detail) = warning else { return nil }
        let message = "Transcription complete. Speaker analysis failed; subtitle timings were not refined."
        let trimmedDetail = detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedDetail.isEmpty ? message : "\(message) \(trimmedDetail)"
    }

    private static func fileURL(from path: String) -> URL? {
        let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }
}
