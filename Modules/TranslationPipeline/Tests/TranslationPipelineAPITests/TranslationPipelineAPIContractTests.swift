import TranslationPipeline
import XCTest

final class TranslationPipelineAPIContractTests: XCTestCase {
    func testTypedContractCompilesWithoutApplicationOrImplementationProducts() {
        let operation: (any TranslatingProject)? = nil
        let handler: TranslationPipelineEventHandler = { _ in }

        XCTAssertNil(operation)
        _ = handler
        XCTAssertEqual(TranslationPipelineError.noSubtitles.errorDescription, "No subtitles to translate.")
    }
}
