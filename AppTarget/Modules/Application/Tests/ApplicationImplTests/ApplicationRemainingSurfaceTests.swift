import ApplicationImpl
import Foundation
import XCTest

@testable import Application

final class ApplicationRemainingSurfaceTests: XCTestCase {
    @MainActor
    func testApplicationRetainsOnlyCrossScreenTranscriptionActivity() {
        let activity = TranscriptionActivity(
            id: UUID(),
            projectName: "Demo",
            statusText: "Transcribing",
            progress: 0.5,
            status: .running
        )

        XCTAssertEqual(activity.projectName, "Demo")
        XCTAssertEqual(activity.progress, 0.5)
        XCTAssertFalse(activity.isFinished)
    }
}
