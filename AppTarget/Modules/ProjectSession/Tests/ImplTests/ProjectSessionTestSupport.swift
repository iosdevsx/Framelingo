import Foundation
import Project
import ProjectSession
import ProjectSessionImpl
import Timeline
import XCTest

@MainActor
final class ManualSleeper {
    private var continuations: [CheckedContinuation<Void, Error>] = []

    var waitingCount: Int { continuations.count }

    func sleep(for _: Duration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeAll() {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}

actor RecordingProjectRepository: ProjectRepository {
    enum Failure: Error { case save }

    private var projects: [UUID: Project] = [:]
    private var savedProjects: [Project] = []
    private var heldSaveContinuations: [CheckedContinuation<Void, Never>] = []
    private var holdsSaves = false
    private var failsSaves = false

    func createProject(for mediaFile: MediaFile) async throws -> Project {
        throw Failure.save
    }

    func saveProject(_ project: Project) async throws {
        if holdsSaves {
            await withCheckedContinuation { continuation in
                heldSaveContinuations.append(continuation)
            }
        }
        if failsSaves { throw Failure.save }
        projects[project.id] = project
        savedProjects.append(project)
    }

    func loadProject(id: UUID) async throws -> Project {
        guard let project = projects[id] else { throw Failure.save }
        return project
    }

    func listProjects() async throws -> [Project] { Array(projects.values) }
    func deleteProject(id: UUID) async throws { projects[id] = nil }

    func saves() -> [Project] { savedProjects }
    func waitingSaveCount() -> Int { heldSaveContinuations.count }
    func setHoldsSaves(_ value: Bool) { holdsSaves = value }
    func setFailsSaves(_ value: Bool) { failsSaves = value }

    func resumeHeldSaves() {
        holdsSaves = false
        let continuations = heldSaveContinuations
        heldSaveContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}

@MainActor
func makeSessionFixture(
    historyLimit: Int = 50,
    repository: RecordingProjectRepository = RecordingProjectRepository(),
    sleeper providedSleeper: ManualSleeper? = nil,
    events: @escaping @MainActor @Sendable (ProjectSessionDocumentChangeEvent) -> Void = { _ in },
    editTimelineService: (any EditTimelineEditing)? = nil
) -> (DefaultProjectSession, RecordingProjectRepository, ManualSleeper) {
    let sleeper = providedSleeper ?? ManualSleeper()
    let session = DefaultProjectSession(dependencies: ProjectSessionDependencies(
        repository: repository,
        documentChangeSink: ProjectSessionDocumentChangeSink(send: events),
        historyLimit: historyLimit,
        sleeper: ProjectSessionSleeper { duration in
            try await sleeper.sleep(for: duration)
        },
        now: { Date(timeIntervalSince1970: 10) },
        editTimelineService: editTimelineService
    ))
    return (session, repository, sleeper)
}

func makeSessionProject(name: String = "Project", id: UUID = UUID()) -> Project {
    Project(
        id: id,
        name: name,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        mediaFile: MediaFile(
            id: UUID(),
            originalURL: URL(fileURLWithPath: "/tmp/\(id.uuidString).mp4"),
            fileName: "video.mp4",
            fileExtension: "mp4",
            sizeBytes: 1,
            durationMs: 1_000
        ),
        sourceLanguage: "en",
        targetLanguage: "ru",
        subtitles: [],
        status: .idle
    )
}

@MainActor
func waitUntil(
    _ description: String,
    iterations: Int = 200,
    condition: @escaping () async -> Bool
) async throws {
    for _ in 0..<iterations {
        if await condition() { return }
        await Task.yield()
    }
    XCTFail("Timed out waiting for \(description)")
}
