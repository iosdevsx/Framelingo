import ProjectSession
import XCTest

@testable import ProjectSessionImpl

@MainActor
final class ProjectSessionHistoryTests: XCTestCase {
    func testUndoRedoRestoreAtomicallyWithoutRecursiveHistory() {
        let (session, _, _) = makeSessionFixture()
        let project = makeSessionProject(name: "Initial")
        session.open(project)
        installName("Changed", in: session)

        session.undo()
        XCTAssertEqual(session.snapshot.project?.name, "Initial")
        XCTAssertFalse(session.snapshot.history.canUndo)
        XCTAssertTrue(session.snapshot.history.canRedo)

        session.redo()
        XCTAssertEqual(session.snapshot.project?.name, "Changed")
        XCTAssertTrue(session.snapshot.history.canUndo)
        XCTAssertFalse(session.snapshot.history.canRedo)
    }

    func testHistoryLimitKeepsNewestEntriesAndNewChangeInvalidatesRedo() {
        let (session, _, _) = makeSessionFixture(historyLimit: 2)
        session.open(makeSessionProject(name: "Initial"))
        installName("One", in: session)
        installName("Two", in: session)
        installName("Three", in: session)

        session.undo()
        XCTAssertEqual(session.snapshot.project?.name, "Two")
        session.undo()
        XCTAssertEqual(session.snapshot.project?.name, "One")
        XCTAssertFalse(session.snapshot.history.canUndo)

        installName("Branch", in: session)
        XCTAssertFalse(session.snapshot.history.canRedo)
    }

    func testGroupedChangeInvalidatesRedoBeforeInteractionEnds() {
        let (session, _, _) = makeSessionFixture()
        session.open(makeSessionProject(name: "Initial"))
        installName("Changed", in: session)
        session.undo()
        XCTAssertTrue(session.snapshot.history.canRedo)

        session.beginInteraction(named: "drag")
        installName("Branch", in: session)

        XCTAssertFalse(session.snapshot.history.canRedo)
    }

    func testInteractionGroupCreatesOneUndoEntryForSeveralChanges() {
        let (session, _, _) = makeSessionFixture()
        session.open(makeSessionProject(name: "Initial"))
        session.beginInteraction(named: "drag")
        installName("One", in: session)
        installName("Two", in: session)
        XCTAssertFalse(session.snapshot.history.canUndo)

        session.endInteraction(named: "drag")
        XCTAssertTrue(session.snapshot.history.canUndo)
        session.undo()

        XCTAssertEqual(session.snapshot.project?.name, "Initial")
        XCTAssertFalse(session.snapshot.history.canUndo)
    }

    func testNoOpGroupAndIdentityReplacementCreateNoHistory() {
        let (session, _, _) = makeSessionFixture()
        let first = makeSessionProject(name: "First")
        session.open(first)
        session.beginInteraction(named: "noop")
        session.endInteraction(named: "noop")
        XCTAssertFalse(session.snapshot.history.canUndo)

        session.beginInteraction(named: "discarded")
        installName("Changed", in: session)
        session.open(makeSessionProject(name: "Second"))
        session.endInteraction(named: "discarded")

        XCTAssertEqual(session.snapshot.project?.name, "Second")
        XCTAssertFalse(session.snapshot.history.canUndo)
    }

    func testInteractionReturningToInitialDocumentCreatesNoHistory() {
        let (session, _, _) = makeSessionFixture()
        session.open(makeSessionProject(name: "Initial"))
        session.beginInteraction(named: "roundtrip")
        installName("Temporary", in: session)
        installName("Initial", in: session)

        session.endInteraction(named: "roundtrip")

        XCTAssertFalse(session.snapshot.history.canUndo)
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
