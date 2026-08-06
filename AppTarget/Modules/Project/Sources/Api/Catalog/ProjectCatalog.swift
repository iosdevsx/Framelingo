import Combine
import Foundation
import VideoRendering

public struct ProjectSummary: Identifiable, Equatable {
    public let id: UUID
    public let displayName: String
    public let mediaFileName: String
    public let mediaSizeBytes: Int64
    public let updatedAt: Date
    public let status: ProcessingStatus

    public init(
        id: UUID,
        displayName: String,
        mediaFileName: String,
        mediaSizeBytes: Int64,
        updatedAt: Date,
        status: ProcessingStatus
    ) {
        self.id = id
        self.displayName = displayName
        self.mediaFileName = mediaFileName
        self.mediaSizeBytes = mediaSizeBytes
        self.updatedAt = updatedAt
        self.status = status
    }

    public init(project: Project) {
        self.init(
            id: project.id,
            displayName: project.displayName,
            mediaFileName: project.mediaFile.fileName,
            mediaSizeBytes: project.mediaFile.sizeBytes,
            updatedAt: project.updatedAt,
            status: project.status
        )
    }

    public var readableMediaSize: String {
        ByteCountFormatter.string(fromByteCount: mediaSizeBytes, countStyle: .file)
    }
}

public enum ProjectCatalogOperation: String, Equatable {
    case refresh
    case open
    case cleanup
    case delete
}

public struct ProjectCatalogFailure: Error, Equatable, LocalizedError {
    public let operation: ProjectCatalogOperation
    public let message: String

    public init(operation: ProjectCatalogOperation, message: String) {
        self.operation = operation
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

public struct ProjectCatalogSnapshot: Equatable {
    public let summaries: [ProjectSummary]
    public let failure: ProjectCatalogFailure?

    public init(
        summaries: [ProjectSummary],
        failure: ProjectCatalogFailure? = nil
    ) {
        self.summaries = summaries
        self.failure = failure
    }
}

/// Narrow cleanup port owned by Project API. The product composer adapts its
/// selected preparation implementation without exposing that implementation
/// to ProjectImpl.
public struct PreparedMediaCleanup {
    private let removeAction: (URL) throws -> Void

    public init(remove: @escaping (URL) throws -> Void) {
        removeAction = remove
    }

    public func removePreparedMedia(for mediaURL: URL) throws {
        try removeAction(mediaURL)
    }
}

@MainActor
public protocol ProjectCatalogManaging: AnyObject {
    var snapshot: ProjectCatalogSnapshot { get }
    var snapshots: AnyPublisher<ProjectCatalogSnapshot, Never> { get }

    func refresh() async
    func register(_ project: Project)
    func open(id: UUID) async throws -> Project
    @discardableResult
    func delete(id: UUID) async throws -> UUID
}

/// Project-owned adapter for the selected document's export settings. It is
/// separate from global Settings and intentionally exposes no Project value.
@MainActor
public protocol ActiveProjectExportSettingsManaging: AnyObject {
    var current: VideoExportSettings? { get }
    func update(_ settings: VideoExportSettings)
}
