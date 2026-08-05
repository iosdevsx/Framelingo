import Foundation

public struct TranscriptionActivity: Identifiable, Equatable {
    public var id: UUID
    public var projectName: String
    public var statusText: String
    public var progress: Double?
    public var status: TranscriptionActivityStatus

    public var isFinished: Bool {
        status == .succeeded || status == .failed
    }

    public init(
        id: UUID,
        projectName: String,
        statusText: String,
        progress: Double?,
        status: TranscriptionActivityStatus
    ) {
        self.id = id
        self.projectName = projectName
        self.statusText = statusText
        self.progress = progress
        self.status = status
    }
}
