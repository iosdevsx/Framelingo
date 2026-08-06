import Combine
import Project
import XCTest

@testable import MacApp

@MainActor
final class MacProductShellTests: XCTestCase {
    func testInitialStateStartsOnHomeWithSinglePreparedSelection() {
        let project = MacMockData.project
        let shell = makeShell(project: project)

        XCTAssertEqual(shell.selectedProjectID, project.id)
        XCTAssertFalse(shell.hasOpenedProject)
        XCTAssertEqual(shell.workspaceMode, .subtitles)
        XCTAssertEqual(shell.projectMode, .subtitles)
    }

    func testOpenAndReplacementResetModesExactlyOnce() {
        let shell = makeShell(project: nil)
        shell.workspaceMode = .settings

        shell.open(MacMockData.project)

        XCTAssertTrue(shell.hasOpenedProject)
        XCTAssertEqual(shell.workspaceMode, .subtitles)
        XCTAssertEqual(shell.projectMode, .subtitles)

        var updated = MacMockData.project
        updated.name = "Updated"
        shell.projectMode = .shorts
        shell.refreshSummary(from: updated)

        XCTAssertEqual(shell.selectedProjectSummary?.displayName, "Updated")
        XCTAssertEqual(shell.workspaceMode, .shorts)
        XCTAssertEqual(shell.projectMode, .shorts)
    }

    func testWorkspaceAndProjectNavigationStaySynchronized() {
        let shell = makeShell(project: MacMockData.project)

        shell.workspaceMode = .videoEditor
        XCTAssertEqual(shell.projectMode, .edit)

        shell.projectMode = .shorts
        XCTAssertEqual(shell.workspaceMode, .shorts)

        shell.workspaceMode = .settings
        XCTAssertEqual(shell.projectMode, .shorts)
    }

    func testCloseCleansPreparedMediaBeforeClearingSelection() async {
        var selectionDuringCleanup: UUID?
        var shell: MacProductShell!
        shell = makeShell(
            project: MacMockData.project,
            cleanup: PreparedMediaCleanup { _ in
                selectionDuringCleanup = shell.selectedProjectID
            }
        )
        shell.open(MacMockData.project)

        await shell.closeSelectedProject()

        XCTAssertEqual(selectionDuringCleanup, MacMockData.project.id)
        XCTAssertNil(shell.selectedProjectID)
        XCTAssertFalse(shell.hasOpenedProject)
    }

    func testCleanupFailureLeavesSelectionAndWorkspaceDefined() async {
        let shell = makeShell(
            project: MacMockData.project,
            cleanup: PreparedMediaCleanup { _ in throw TestFailure.cleanup }
        )
        shell.open(MacMockData.project)

        await shell.closeSelectedProject()

        XCTAssertEqual(shell.selectedProjectID, MacMockData.project.id)
        XCTAssertTrue(shell.hasOpenedProject)
        XCTAssertNotNil(shell.failure)
        XCTAssertFalse(shell.isClosingProject)
    }

    func testActiveDeleteClearsOnlyAfterCatalogSuccess() async {
        let catalog = CatalogStub()
        let shell = makeShell(project: MacMockData.project, catalog: catalog)
        shell.open(MacMockData.project)

        await shell.deleteActiveProject()

        XCTAssertEqual(catalog.deletedIDs, [MacMockData.project.id])
        XCTAssertNil(shell.selectedProjectID)
    }

    func testActiveDeleteFailurePreservesSelection() async {
        let catalog = CatalogStub(deleteError: TestFailure.delete)
        let shell = makeShell(project: MacMockData.project, catalog: catalog)
        shell.open(MacMockData.project)

        await shell.deleteActiveProject()

        XCTAssertEqual(shell.selectedProjectID, MacMockData.project.id)
        XCTAssertTrue(shell.hasOpenedProject)
        XCTAssertNotNil(shell.failure)
    }

    private func makeShell(
        project: Project?,
        cleanup: PreparedMediaCleanup = PreparedMediaCleanup { _ in },
        catalog: (any ProjectCatalogManaging)? = nil
    ) -> MacProductShell {
        MacProductShell(
            selectedProject: project,
            preparedMediaCleanup: cleanup,
            projectCatalog: catalog ?? CatalogStub()
        )
    }
}

private enum TestFailure: Error {
    case cleanup
    case delete
}

@MainActor
private final class CatalogStub: ProjectCatalogManaging {
    var snapshot: ProjectCatalogSnapshot { subject.value }
    var snapshots: AnyPublisher<ProjectCatalogSnapshot, Never> { subject.eraseToAnyPublisher() }
    private let subject = CurrentValueSubject<ProjectCatalogSnapshot, Never>(
        ProjectCatalogSnapshot(summaries: [])
    )
    private let deleteError: Error?
    private(set) var deletedIDs: [UUID] = []

    init(deleteError: Error? = nil) {
        self.deleteError = deleteError
    }

    func refresh() async {}
    func register(_: Project) {}
    func open(id _: UUID) async throws -> Project { MacMockData.project }

    func delete(id: UUID) async throws -> UUID {
        deletedIDs.append(id)
        if let deleteError { throw deleteError }
        return id
    }
}
