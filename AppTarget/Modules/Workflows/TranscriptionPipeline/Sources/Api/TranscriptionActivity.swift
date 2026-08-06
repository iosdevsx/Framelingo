import Combine
import Foundation

public enum TranscriptionActivityStatus: Equatable, Sendable {
    case running
    case succeeded
    case failed
}

public struct TranscriptionActivity: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let projectName: String
    public var statusText: String
    public var progress: Double?
    public var status: TranscriptionActivityStatus

    public var isFinished: Bool { status != .running }

    public init(
        id: UUID = UUID(),
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

@MainActor
public protocol TranscriptionActivityTracking: AnyObject {
    var activity: TranscriptionActivity? { get }
    var activitySnapshots: AnyPublisher<TranscriptionActivity?, Never> { get }

    func start(projectName: String)
    func update(statusText: String, progress: Double?)
    func finish(success: Bool, message: String?)
    func dismiss()
}
