import AppUpdate
import AppUpdateImpl
import XCTest

@MainActor
final class AppUpdateAssemblyTests: XCTestCase {
    func testAssemblyReturnsUpdateCheckingContractWithoutStartingUpdater() {
        let checker: any AppUpdateChecking = AppUpdateAssembly.makeChecker(startingUpdater: false)

        XCTAssertNotNil(checker)
    }
}
