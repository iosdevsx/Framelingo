import Foundation
import Project

/// Application workflows are reserved for use cases that coordinate multiple
/// owner modules. Subtitle export remains on `SubtitleExportService`, while
/// video export remains on the ExportFeature/AppState job path; wrapping either
/// single-owner operation here would only duplicate its public API.
public enum ProjectProcessingEvent {
    case projectChanged(Project)
    case progress(value: Double?, status: String)
}

public typealias ProjectProcessingEventHandler = (ProjectProcessingEvent) async -> Void

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
