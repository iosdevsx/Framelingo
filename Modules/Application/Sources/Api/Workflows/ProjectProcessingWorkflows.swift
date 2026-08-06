import Foundation
import Project
import Settings

/// Application workflows are reserved for use cases that coordinate multiple
/// owner modules. Subtitle export remains on `SubtitleExportService`, while
/// video export remains on the ExportFeature/AppState job path; wrapping either
/// single-owner operation here would only duplicate its public API.
public enum ProjectProcessingEvent {
    case projectChanged(Project)
    case progress(value: Double?, status: String)
}

public typealias ProjectProcessingEventHandler = (ProjectProcessingEvent) async -> Void

public struct ProjectTranscriptionRequest {
    public let project: Project
    public let settings: AppSettings

    public init(project: Project, settings: AppSettings) {
        self.project = project
        self.settings = settings
    }
}

public struct ProjectTranscriptionOutput {
    public let project: Project
    public let completionMessage: String?

    public init(project: Project, completionMessage: String?) {
        self.project = project
        self.completionMessage = completionMessage
    }
}

public enum ProjectTranscriptionError: LocalizedError, Equatable {
    case emptyEditTimeline
    case ffmpegNotFound
    case failed(String)
    case persistenceFailed(operation: String, persistence: String)
    case temporaryFileCleanupFailed(String)
    case operationAndCleanupFailed(operation: String, cleanup: String)
    case cancellationAndCleanupFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyEditTimeline:
            "The edit timeline has no video to transcribe. Review your cuts in Edit mode."
        case .ffmpegNotFound:
            "FFmpeg is not installed or path is incorrect."
        case .failed(let message):
            message
        case .persistenceFailed(let operation, let persistence):
            "\(operation) The failed project state could not be saved: \(persistence)"
        case .temporaryFileCleanupFailed(let message):
            "Transcription finished, but its temporary audio could not be removed: \(message)"
        case .operationAndCleanupFailed(let operation, let cleanup):
            "\(operation) Temporary audio cleanup also failed: \(cleanup)"
        case .cancellationAndCleanupFailed(let message):
            "Transcription was cancelled, but its temporary audio could not be removed: \(message)"
        }
    }
}

public protocol ProjectTranscriptionWorkflow {
    func transcribe(
        _ request: ProjectTranscriptionRequest,
        events: @escaping ProjectProcessingEventHandler
    ) async throws -> ProjectTranscriptionOutput
}

public struct ProjectTranslationRequest {
    public let project: Project

    public init(project: Project) {
        self.project = project
    }
}

public struct ProjectTranslationOutput {
    public let project: Project

    public init(project: Project) {
        self.project = project
    }
}

public enum ProjectTranslationError: LocalizedError, Equatable {
    case noSubtitles
    case segmentCountMismatch
    case failed(String)
    case persistenceFailed(operation: String, persistence: String)

    public var errorDescription: String? {
        switch self {
        case .noSubtitles:
            "No subtitles to translate."
        case .segmentCountMismatch:
            "Translation provider returned a different number of subtitle segments."
        case .failed(let message):
            message
        case .persistenceFailed(let operation, let persistence):
            "\(operation) The failed project state could not be saved: \(persistence)"
        }
    }
}

public protocol ProjectTranslationWorkflow {
    func translate(
        _ request: ProjectTranslationRequest,
        events: @escaping ProjectProcessingEventHandler
    ) async throws -> ProjectTranslationOutput
}
