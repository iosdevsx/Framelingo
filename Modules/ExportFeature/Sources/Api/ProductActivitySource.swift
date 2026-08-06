import Combine
import Foundation

public enum ProductActivityStatus: Equatable {
    case running
    case succeeded
    case failed
}

public struct ProductActivityItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let detail: String?
    public let progress: Double?
    public let status: ProductActivityStatus
    public let errorMessage: String?
    public let outputURL: URL?
    public let diagnosticText: String?
    public let canDismiss: Bool

    public init(
        id: String,
        title: String,
        subtitle: String,
        detail: String? = nil,
        progress: Double?,
        status: ProductActivityStatus,
        errorMessage: String? = nil,
        outputURL: URL? = nil,
        diagnosticText: String? = nil,
        canDismiss: Bool
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.progress = progress
        self.status = status
        self.errorMessage = errorMessage
        self.outputURL = outputURL
        self.diagnosticText = diagnosticText
        self.canDismiss = canDismiss
    }
}

public struct ProductActivitySnapshot: Equatable {
    public let items: [ProductActivityItem]

    public init(items: [ProductActivityItem]) {
        self.items = items
    }
}

/// Read-only product activity feed plus actions routed to its canonical owner.
@MainActor
public struct ProductActivitySource {
    private let snapshotAction: () -> ProductActivitySnapshot
    private let snapshotsAction: () -> AnyPublisher<ProductActivitySnapshot, Never>
    private let dismissAction: (String) -> Void

    public init(
        snapshot: @escaping () -> ProductActivitySnapshot,
        snapshots: @escaping () -> AnyPublisher<ProductActivitySnapshot, Never>,
        dismiss: @escaping (String) -> Void
    ) {
        snapshotAction = snapshot
        snapshotsAction = snapshots
        dismissAction = dismiss
    }

    public var snapshot: ProductActivitySnapshot { snapshotAction() }
    public var snapshots: AnyPublisher<ProductActivitySnapshot, Never> { snapshotsAction() }

    public func dismiss(id: String) {
        dismissAction(id)
    }
}
