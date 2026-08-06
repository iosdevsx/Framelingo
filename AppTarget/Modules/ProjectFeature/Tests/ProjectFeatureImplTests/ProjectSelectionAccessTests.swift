import Combine
import Project
import ProjectFeature
import XCTest

@MainActor
final class ProjectSelectionAccessTests: XCTestCase {
    func testAccessForwardsCurrentUpdatesAndCloseWithoutExposingMutation() async {
        let subject = CurrentValueSubject<Project?, Never>(TestDoubles.project())
        let access = ProjectSelectionAccess(
            current: { subject.value },
            updates: { subject.eraseToAnyPublisher() },
            close: { subject.send(nil) }
        )
        var received: Project?
        let subscription = access.updates.sink { received = $0 }
        var updated = TestDoubles.project()
        updated.name = "Updated"

        subject.send(updated)
        XCTAssertEqual(access.current?.name, "Updated")
        XCTAssertEqual(received?.name, "Updated")

        await access.close()
        XCTAssertNil(access.current)
        _ = subscription
    }
}
