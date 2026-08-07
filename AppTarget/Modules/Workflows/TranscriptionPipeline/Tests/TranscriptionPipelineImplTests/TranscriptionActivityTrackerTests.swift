import Combine
import TranscriptionPipeline
import XCTest

@testable import TranscriptionPipelineImpl

@MainActor
final class TranscriptionActivityTrackerTests: XCTestCase {
    func testLifecyclePublishesClampedProgressAndDismissesFinishedActivity() {
        let tracker = DefaultTranscriptionActivityTracker()
        var snapshots: [TranscriptionActivity?] = []
        let subscription = tracker.activitySnapshots.sink { snapshots.append($0) }

        tracker.start(projectName: "Demo")
        tracker.update(statusText: "Transcribing", progress: 1.5)
        tracker.finish(success: true, message: "Ready")

        XCTAssertEqual(tracker.activity?.projectName, "Demo")
        XCTAssertEqual(tracker.activity?.progress, 1)
        XCTAssertEqual(tracker.activity?.status, .succeeded)
        XCTAssertEqual(tracker.activity?.statusText, "Ready")
        XCTAssertGreaterThanOrEqual(snapshots.count, 4)

        tracker.dismiss()
        XCTAssertNil(tracker.activity)
        _ = subscription
    }
}
