import Foundation

public enum VideoExportJobStatus: Int, Comparable, Equatable, Sendable {
    case queued
    case preparing
    case exporting
    case writingSidecar
    case succeeded
    case failed

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var isFinished: Bool {
        self == .succeeded || self == .failed
    }
}

public struct VideoExportJob: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let projectName: String
    public let outputURL: URL
    public var status: VideoExportJobStatus
    public var statusText: String
    public var progress: Double?
    public var failure: VideoExportFailure?

    public var isFinished: Bool { status.isFinished }
    public var errorMessage: String? { failure?.message }
    public var debugOutput: String? { failure?.debugOutput }

    public init(
        id: UUID,
        projectName: String,
        outputURL: URL,
        status: VideoExportJobStatus,
        statusText: String,
        progress: Double?,
        failure: VideoExportFailure? = nil
    ) {
        self.id = id
        self.projectName = projectName
        self.outputURL = outputURL
        self.status = status
        self.statusText = statusText
        self.progress = progress
        self.failure = failure
    }
}
