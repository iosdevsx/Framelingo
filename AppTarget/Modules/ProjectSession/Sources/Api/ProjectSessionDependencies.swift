import Foundation
import Project

public struct ProjectSessionDocumentChangeSink: Sendable {
    private let sendAction: @MainActor @Sendable (ProjectSessionDocumentChangeEvent) -> Void

    public init(send: @escaping @MainActor @Sendable (ProjectSessionDocumentChangeEvent) -> Void) {
        sendAction = send
    }

    @MainActor
    public func send(_ event: ProjectSessionDocumentChangeEvent) {
        sendAction(event)
    }

    public static let none = ProjectSessionDocumentChangeSink { _ in }
}

public struct ProjectSessionSleeper: Sendable {
    private let sleepAction: @MainActor @Sendable (Duration) async throws -> Void

    public init(sleep: @escaping @MainActor @Sendable (Duration) async throws -> Void) {
        sleepAction = sleep
    }

    @MainActor
    public func sleep(for duration: Duration) async throws {
        try await sleepAction(duration)
    }

    public static let continuous = ProjectSessionSleeper { duration in
        try await Task.sleep(for: duration)
    }
}

public struct ProjectSessionDependencies {
    public let repository: any ProjectRepository
    public let documentChangeSink: ProjectSessionDocumentChangeSink
    public let historyLimit: Int
    public let autosaveDelay: Duration
    public let sleeper: ProjectSessionSleeper
    public let now: @MainActor () -> Date

    public init(
        repository: any ProjectRepository,
        documentChangeSink: ProjectSessionDocumentChangeSink = .none,
        historyLimit: Int = 50,
        autosaveDelay: Duration = .milliseconds(500),
        sleeper: ProjectSessionSleeper = .continuous,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.repository = repository
        self.documentChangeSink = documentChangeSink
        self.historyLimit = max(historyLimit, 0)
        self.autosaveDelay = autosaveDelay
        self.sleeper = sleeper
        self.now = now
    }
}
