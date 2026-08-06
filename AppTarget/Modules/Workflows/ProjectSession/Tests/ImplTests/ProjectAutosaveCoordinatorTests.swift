import ProjectSession
import XCTest

@testable import ProjectSessionImpl

@MainActor
final class ProjectAutosaveCoordinatorTests: XCTestCase {
    func testRapidTransactionsPersistOnlyLatestProjectAfterDebounce() async throws {
        let (session, repository, sleeper) = makeSessionFixture()
        session.open(makeSessionProject(name: "Initial"))
        installName("One", in: session)
        installName("Two", in: session)
        installName("Latest", in: session)

        try await waitUntil("debounce waiter") { sleeper.waitingCount >= 1 }
        sleeper.resumeAll()
        try await waitUntil("one repository save") { await repository.saves().count == 1 }

        let saves = await repository.saves()
        XCTAssertEqual(saves.map(\.name), ["Latest"])
        XCTAssertEqual(session.snapshot.persistence, .saved(.autosave))
    }

    func testExplicitSaveCancelsDebounceAndPersistsCurrentProjectOnce() async throws {
        let (session, repository, sleeper) = makeSessionFixture()
        session.open(makeSessionProject(name: "Initial"))
        installName("Current", in: session)
        try await waitUntil("pending debounce") { sleeper.waitingCount == 1 }

        await session.save()
        sleeper.resumeAll()
        await Task.yield()

        let saves = await repository.saves()
        XCTAssertEqual(saves.map(\.name), ["Current"])
        XCTAssertEqual(session.snapshot.persistence, .saved(.explicit))
    }

    func testExplicitFailurePublishesTypedFailure() async {
        let repository = RecordingProjectRepository()
        await repository.setFailsSaves(true)
        let (session, _, _) = makeSessionFixture(repository: repository)
        let project = makeSessionProject()
        session.open(project)

        await session.save()

        XCTAssertEqual(
            session.snapshot.persistence,
            .failed(ProjectSessionPersistenceFailure(
                projectID: project.id,
                saveKind: .explicit,
                reason: .repositoryRejectedSave
            ))
        )
    }

    func testDelayedObsoleteCompletionCannotChangeReplacementState() async throws {
        let repository = RecordingProjectRepository()
        await repository.setHoldsSaves(true)
        let (session, _, sleeper) = makeSessionFixture(repository: repository)
        session.open(makeSessionProject(name: "First"))
        installName("Saving", in: session)
        try await waitUntil("pending debounce") { sleeper.waitingCount == 1 }
        sleeper.resumeAll()
        try await waitUntil("repository save to suspend") {
            await repository.waitingSaveCount() == 1
        }

        let replacement = makeSessionProject(name: "Replacement")
        session.open(replacement)
        await repository.resumeHeldSaves()
        await Task.yield()

        XCTAssertEqual(session.snapshot.project?.id, replacement.id)
        XCTAssertEqual(session.snapshot.persistence, .idle)
    }

    func testCloseCancelsPendingAutosave() async throws {
        let (session, repository, sleeper) = makeSessionFixture()
        session.open(makeSessionProject())
        installName("Changed", in: session)
        try await waitUntil("pending debounce") { sleeper.waitingCount == 1 }

        session.close()
        sleeper.resumeAll()
        await Task.yield()

        let saves = await repository.saves()
        XCTAssertTrue(saves.isEmpty)
        XCTAssertNil(session.snapshot.project)
    }

    private func installName(_ name: String, in session: DefaultProjectSession) {
        guard var project = session.snapshot.project else {
            XCTFail("Missing project")
            return
        }
        project.name = name
        XCTAssertTrue(session.install(candidate: project))
    }
}
