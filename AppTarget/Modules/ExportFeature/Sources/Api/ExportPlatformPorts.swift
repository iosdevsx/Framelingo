import Foundation

public struct ExportPlatformFailure: Error, Equatable, LocalizedError {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

public enum ExportPlatformResult: Equatable {
    case success
    case failure(ExportPlatformFailure)
}

@MainActor
public struct ExportOutputRevealing {
    private let revealAction: (URL) -> ExportPlatformResult

    public init(reveal: @escaping (URL) -> ExportPlatformResult) {
        revealAction = reveal
    }

    public func reveal(_ outputURL: URL) -> ExportPlatformResult {
        revealAction(outputURL)
    }
}

@MainActor
public struct ExportDiagnosticCopying {
    private let copyAction: (String) -> ExportPlatformResult

    public init(copy: @escaping (String) -> ExportPlatformResult) {
        copyAction = copy
    }

    public func copy(_ text: String) -> ExportPlatformResult {
        copyAction(text)
    }
}
