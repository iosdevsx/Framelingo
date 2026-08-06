import Foundation

public struct SubtitleDocumentPickerRequest: Equatable {
    public let allowedFileExtensions: [String]

    public init(allowedFileExtensions: [String]) {
        self.allowedFileExtensions = allowedFileExtensions
    }
}

public struct SubtitleDocumentPickerFailure: Error, Equatable, LocalizedError {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

public enum SubtitleDocumentPickerOutcome: Equatable {
    case selected(URL)
    case cancelled
    case failed(SubtitleDocumentPickerFailure)
}

/// Capability-owned system document picker. Platform composition supplies the
/// implementation; the subtitle capability owns the semantic request/result.
@MainActor
public struct SubtitleDocumentPicker {
    private let pickAction: (SubtitleDocumentPickerRequest) async -> SubtitleDocumentPickerOutcome

    public init(
        pick: @escaping (SubtitleDocumentPickerRequest) async -> SubtitleDocumentPickerOutcome
    ) {
        pickAction = pick
    }

    public func pick(
        _ request: SubtitleDocumentPickerRequest
    ) async -> SubtitleDocumentPickerOutcome {
        await pickAction(request)
    }
}
