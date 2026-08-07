import TranscriptionPipeline
import XCTest

/// This target intentionally depends on the pipeline API product only.
final class TranscriptionPipelineAPIContractTests: XCTestCase {
    func testTypedContractCompilesWithoutUmbrellaOrImplementationProducts() {
        let progress = TranscriptionPipelineProgress(
            phase: .transcribing,
            fractionCompleted: 0.5,
            providerDetail: "Provider detail"
        )

        XCTAssertEqual(progress.phase, .transcribing)
        XCTAssertEqual(
            TranscriptionPipelineWarning.speakerAnalysisUnavailable(detail: "Unavailable"),
            .speakerAnalysisUnavailable(detail: "Unavailable")
        )
    }
}
