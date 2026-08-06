import ApplicationImpl
import XCTest

@testable import Application

final class ApplicationRemainingSurfaceTests: XCTestCase {
    func testApplicationRetainsExportFailurePresentationUntilExportExtraction() {
        XCTAssertEqual(
            ApplicationExportError.editTimelineEmpty.errorDescription,
            "The edit timeline has no clips to export. Review your cuts in Edit mode."
        )
    }
}
