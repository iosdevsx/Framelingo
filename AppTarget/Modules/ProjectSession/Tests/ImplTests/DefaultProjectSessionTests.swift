import Combine
import ProjectSession
import XCTest

@testable import ProjectSessionImpl

@MainActor
final class DefaultProjectSessionTests: XCTestCase {
    func testCanonicalOwnershipPublishesOneDocumentSnapshotAndEventPerTransaction() throws {
        var events: [ProjectSessionDocumentChangeEvent] = []
        let (session, _, sleeper) = makeSessionFixture { events.append($0) }
        var snapshots: [ProjectSessionSnapshot] = []
        let subscription = session.snapshots.sink { snapshots.append($0) }
        let original = makeSessionProject(name: "Original")
        session.open(original)
        var candidate = original
        candidate.name = "Changed"

        XCTAssertTrue(session.install(candidate: candidate))

        XCTAssertEqual(session.snapshot.project?.name, "Changed")
        XCTAssertEqual(session.snapshot.project?.updatedAt, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(snapshots.map(\.project?.name), [nil, "Original", "Changed"])
        XCTAssertEqual(events.map(\.kind), [.opened, .changed])
        XCTAssertEqual(sleeper.waitingCount, 0)
        withExtendedLifetime(subscription) {}
    }

    func testInvalidAndNoOpCandidatesChangeNoCountsOrAutosaveSchedule() async {
        var events: [ProjectSessionDocumentChangeEvent] = []
        let (session, repository, sleeper) = makeSessionFixture { events.append($0) }
        let project = makeSessionProject()
        session.open(project)
        var snapshots: [ProjectSessionSnapshot] = []
        let subscription = session.snapshots.sink { snapshots.append($0) }
        var invalid = project
        invalid.name = "Invalid"

        XCTAssertFalse(session.install(candidate: project))
        XCTAssertFalse(session.install(candidate: invalid, validate: { _ in false }))
        await Task.yield()

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(events.map(\.kind), [.opened])
        XCTAssertEqual(sleeper.waitingCount, 0)
        let saves = await repository.saves()
        XCTAssertEqual(saves.count, 0)
        withExtendedLifetime(subscription) {}
    }

    func testTwoSessionsKeepDocumentsHistoryAndObservationIsolated() {
        let (first, _, _) = makeSessionFixture()
        let (second, _, _) = makeSessionFixture()
        let firstProject = makeSessionProject(name: "First")
        let secondProject = makeSessionProject(name: "Second")
        first.open(firstProject)
        second.open(secondProject)
        var candidate = firstProject
        candidate.name = "First changed"

        XCTAssertTrue(first.install(candidate: candidate))

        XCTAssertEqual(first.snapshot.project?.name, "First changed")
        XCTAssertTrue(first.snapshot.history.canUndo)
        XCTAssertEqual(second.snapshot.project?.name, "Second")
        XCTAssertFalse(second.snapshot.history.canUndo)
    }
}
