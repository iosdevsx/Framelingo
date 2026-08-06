import Combine
import Foundation
import Project
import ProjectSession
import XCTest

@MainActor
final class ProjectSessionAPIContractTests: XCTestCase {
    func testSnapshotIsAValueAndCallerMutationCannotWriteBack() throws {
        let original = makeProject(name: "Original")
        let snapshot = ProjectSessionSnapshot(
            project: original,
            history: .empty,
            persistence: .idle
        )

        var callerCopy = try XCTUnwrap(snapshot.project)
        callerCopy.name = "Caller copy"

        XCTAssertEqual(snapshot.project?.name, "Original")
        XCTAssertEqual(callerCopy.name, "Caller copy")
    }

    func testExistentialExposesOnlyLifecycleHistoryPersistenceAndReadOnlyState() async {
        let concrete = ContractSession()
        let session: any ProjectSession = concrete
        let project = makeProject(name: "Opened")

        session.open(project)
        session.beginInteraction(named: "gesture")
        session.endInteraction(named: "gesture")
        session.undo()
        session.redo()
        await session.save()

        XCTAssertEqual(session.activeProjectID, project.id)
        XCTAssertEqual(session.snapshot.project, project)
        XCTAssertEqual(concrete.saveCount, 1)
        session.close()
        XCTAssertNil(session.snapshot.project)
    }
}

@MainActor
private final class ContractSession: ProjectSession {
    private let subject = CurrentValueSubject<ProjectSessionSnapshot, Never>(
        ProjectSessionSnapshot(project: nil, history: .empty, persistence: .idle)
    )
    private(set) var saveCount = 0

    var snapshot: ProjectSessionSnapshot { subject.value }
    var snapshots: AnyPublisher<ProjectSessionSnapshot, Never> { subject.eraseToAnyPublisher() }
    var activeProjectID: UUID? { snapshot.project?.id }

    func open(_ project: Project) {
        subject.send(ProjectSessionSnapshot(project: project, history: .empty, persistence: .idle))
    }

    func close() {
        subject.send(ProjectSessionSnapshot(project: nil, history: .empty, persistence: .idle))
    }

    func undo() {}
    func redo() {}
    func beginInteraction(named name: String) {}
    func endInteraction(named name: String) {}
    func save() async { saveCount += 1 }
}

private func makeProject(name: String, id: UUID = UUID()) -> Project {
    Project(
        id: id,
        name: name,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        mediaFile: MediaFile(
            id: UUID(),
            originalURL: URL(fileURLWithPath: "/tmp/video.mp4"),
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
