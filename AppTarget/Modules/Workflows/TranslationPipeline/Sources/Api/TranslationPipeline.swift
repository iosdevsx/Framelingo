import Foundation
import Project

public struct TranslationPipelineRequest {
    public let project: Project

    public init(project: Project) {
        self.project = project
    }
}

public enum TranslationPipelineEvent {
    case translating(Project)
    case ready(Project)
    case failed(Project)

    public var project: Project {
        switch self {
        case .translating(let project), .ready(let project), .failed(let project):
            project
        }
    }
}

public typealias TranslationPipelineEventHandler = (TranslationPipelineEvent) async -> Void

public struct TranslationPipelineOutput {
    public let project: Project

    public init(project: Project) {
        self.project = project
    }
}

public enum TranslationPipelineError: LocalizedError, Equatable, Sendable {
    case noSubtitles
    case segmentCountMismatch
    case providerFailed(message: String)
    case operationFailed(message: String)
    case persistenceFailed(operation: String, persistence: String)

    public var errorDescription: String? {
        switch self {
        case .noSubtitles:
            "No subtitles to translate."
        case .segmentCountMismatch:
            "Translation provider returned a different number of subtitle segments."
        case .providerFailed(let message), .operationFailed(let message):
            message
        case .persistenceFailed(let operation, let persistence):
            "\(operation) The failed project state could not be saved: \(persistence)"
        }
    }
}

public protocol TranslatingProject {
    func translate(
        _ request: TranslationPipelineRequest,
        events: @escaping TranslationPipelineEventHandler
    ) async throws -> TranslationPipelineOutput
}
