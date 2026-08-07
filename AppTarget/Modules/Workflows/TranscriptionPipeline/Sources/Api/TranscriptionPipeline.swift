import Foundation
import Project
import SpeechToText

public struct TranscriptionPipelineConfiguration: Equatable {
    public let ffmpegExecutablePath: String
    public let speechToText: SpeechToTextProviderConfiguration

    public init(
        ffmpegExecutablePath: String,
        speechToText: SpeechToTextProviderConfiguration
    ) {
        self.ffmpegExecutablePath = ffmpegExecutablePath
        self.speechToText = speechToText
    }
}

public struct TranscriptionPipelineRequest {
    public let project: Project
    public let configuration: TranscriptionPipelineConfiguration

    public init(project: Project, configuration: TranscriptionPipelineConfiguration) {
        self.project = project
        self.configuration = configuration
    }
}

public enum TranscriptionPipelinePhase: Equatable, Sendable {
    case extractingAudio
    case transcribing
    case analyzingSpeakers
    case aligningSubtitles
}

public struct TranscriptionPipelineProgress: Equatable, Sendable {
    public let phase: TranscriptionPipelinePhase
    public let fractionCompleted: Double?
    public let providerDetail: String?

    public init(
        phase: TranscriptionPipelinePhase,
        fractionCompleted: Double?,
        providerDetail: String? = nil
    ) {
        self.phase = phase
        self.fractionCompleted = fractionCompleted
        self.providerDetail = providerDetail
    }
}

public enum TranscriptionPipelineEvent {
    case projectChanged(Project)
    case progress(TranscriptionPipelineProgress)
}

public typealias TranscriptionPipelineEventHandler = (TranscriptionPipelineEvent) async -> Void

public enum TranscriptionPipelineWarning: Equatable, Sendable {
    case speakerAnalysisUnavailable(detail: String?)
}

public struct TranscriptionPipelineOutput {
    public let project: Project
    public let warning: TranscriptionPipelineWarning?

    public init(project: Project, warning: TranscriptionPipelineWarning?) {
        self.project = project
        self.warning = warning
    }
}

public enum TranscriptionPipelineError: LocalizedError, Equatable, Sendable {
    case emptyEditTimeline
    case renderingServiceUnavailable
    case renderingFailed(message: String)
    case providerFailed(message: String)
    case operationFailed(message: String)
    case persistenceFailed(operation: String, persistence: String)
    case temporaryAudioCleanupFailed(message: String)
    case operationAndCleanupFailed(operation: String, cleanup: String)
    case persistenceAndCleanupFailed(operation: String, persistence: String, cleanup: String)
    case cancellationAndCleanupFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .emptyEditTimeline:
            "The edit timeline has no video to transcribe. Review your cuts in Edit mode."
        case .renderingServiceUnavailable:
            "FFmpeg is not installed or path is incorrect."
        case .renderingFailed(let message),
             .providerFailed(let message),
             .operationFailed(let message):
            message
        case .persistenceFailed(let operation, let persistence):
            "\(operation) The failed project state could not be saved: \(persistence)"
        case .temporaryAudioCleanupFailed(let message):
            "Transcription finished, but its temporary audio could not be removed: \(message)"
        case .operationAndCleanupFailed(let operation, let cleanup):
            "\(operation) Temporary audio cleanup also failed: \(cleanup)"
        case .persistenceAndCleanupFailed(let operation, let persistence, let cleanup):
            "\(operation) The failed project state could not be saved: \(persistence) Temporary audio cleanup also failed: \(cleanup)"
        case .cancellationAndCleanupFailed(let message):
            "Transcription was cancelled, but its temporary audio could not be removed: \(message)"
        }
    }
}

public protocol TranscribingProject {
    func transcribe(
        _ request: TranscriptionPipelineRequest,
        events: @escaping TranscriptionPipelineEventHandler
    ) async throws -> TranscriptionPipelineOutput
}
