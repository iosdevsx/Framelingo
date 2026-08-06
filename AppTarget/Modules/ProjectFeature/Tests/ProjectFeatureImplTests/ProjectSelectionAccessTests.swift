import Combine
import Project
import ProjectFeature
import XCTest

@MainActor
final class ProjectSelectionAccessTests: XCTestCase {
    func testAccessForwardsCurrentUpdatesUpdateAndClose() async {
        let subject = CurrentValueSubject<Project?, Never>(TestDoubles.project())
        let access = ProjectSelectionAccess(
            current: { subject.value },
            updates: { subject.eraseToAnyPublisher() },
            update: { subject.send($0) },
            close: { subject.send(nil) }
        )
        var received: Project?
        let subscription = access.updates.sink { received = $0 }
        var updated = TestDoubles.project()
        updated.name = "Updated"

        access.update(updated)
        XCTAssertEqual(access.current?.name, "Updated")
        XCTAssertEqual(received?.name, "Updated")

        await access.close()
        XCTAssertNil(access.current)
        _ = subscription
    }
}
