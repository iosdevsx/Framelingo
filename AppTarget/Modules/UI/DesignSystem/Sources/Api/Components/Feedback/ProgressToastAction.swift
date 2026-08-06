import Foundation

public struct ProgressToastAction: Identifiable {
    public let id: UUID
    public let title: String
    public let handler: () -> Void

    public init(
        id: UUID = UUID(),
        title: String,
        handler: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.handler = handler
    }
}
