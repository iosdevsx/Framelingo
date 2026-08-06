import Combine
import Foundation
import Media
import SpeakerAnalysis
import Subtitles
import Translation

@MainActor
public final class AppState: ObservableObject {
    @Published public var transcriptionActivity: TranscriptionActivity?

    public let subtitleExportService: any SubtitleExportService
    public let translationService: any TranslationOrchestrating
    public let speakerDiarizationEngine: any SpeakerDiarizationEngine
    public let subtitleAlignmentEngine: any SubtitleAlignmentEngine
    public let audioPreparationService: any AudioPreparationService

    public init(
        subtitleExportService: any SubtitleExportService,
        translationService: any TranslationOrchestrating,
        speakerDiarizationEngine: any SpeakerDiarizationEngine,
        subtitleAlignmentEngine: any SubtitleAlignmentEngine,
        audioPreparationService: any AudioPreparationService
    ) {
        self.subtitleExportService = subtitleExportService
        self.translationService = translationService
        self.speakerDiarizationEngine = speakerDiarizationEngine
        self.subtitleAlignmentEngine = subtitleAlignmentEngine
        self.audioPreparationService = audioPreparationService
    }

    public func startTranscriptionActivity(projectName: String) {
        transcriptionActivity = TranscriptionActivity(
            id: UUID(),
            projectName: projectName,
            statusText: "Extracting audio...",
            progress: 0,
            status: .running
        )
    }

    public func updateTranscriptionActivity(statusText: String, progress: Double?) {
        guard transcriptionActivity != nil else {
            return
        }

        transcriptionActivity?.statusText = statusText
        if let progress {
            transcriptionActivity?.progress = min(max(progress, 0), 1)
        }
    }

    public func finishTranscriptionActivity(success: Bool, message: String? = nil) {
        guard transcriptionActivity != nil else {
            return
        }

        transcriptionActivity?.status = success ? .succeeded : .failed
        transcriptionActivity?.progress = success ? 1 : transcriptionActivity?.progress
        transcriptionActivity?.statusText = message ?? (success ? "Transcription complete" : "Transcription failed")
    }

    public func dismissTranscriptionActivity() {
        transcriptionActivity = nil
    }

}
