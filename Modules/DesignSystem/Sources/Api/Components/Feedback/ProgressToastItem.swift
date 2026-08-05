public struct ProgressToastItem: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let detail: String?
    public let progress: Double?
    public let status: ProgressToastStatus
    public let errorMessage: String?
    public let actions: [ProgressToastAction]
    public let onDismiss: (() -> Void)?

    public init(
        id: String,
        title: String,
        subtitle: String,
        detail: String?,
        progress: Double?,
        status: ProgressToastStatus,
        errorMessage: String?,
        actions: [ProgressToastAction],
        onDismiss: (() -> Void)?
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.progress = progress
        self.status = status
        self.errorMessage = errorMessage
        self.actions = actions
        self.onDismiss = onDismiss
    }
}
