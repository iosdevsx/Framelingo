import ProjectPreparation
import XCTest

/// This target intentionally depends on the API product only. Compiling it
/// proves that consumers need no Application, Settings, feature, or Impl module.
final class ProjectPreparationAPIContractTests: XCTestCase {
    func testTypedContractCanBeUsedFromAPIOnlyTarget() {
        let configuration = ProjectPreparationConfiguration(ffmpegExecutablePath: "/usr/bin/ffmpeg")
        let progress = ProjectPreparationProgress(
            phase: .preparingWaveform,
            fractionCompleted: 0.5,
            providerDetail: "Provider detail"
        )

        XCTAssertEqual(configuration.ffmpegExecutablePath, "/usr/bin/ffmpeg")
        XCTAssertEqual(progress.phase, .preparingWaveform)
        XCTAssertEqual(
            ProjectPreparationOutcome.degraded(.waveformUnavailable),
            .degraded(.waveformUnavailable)
        )
    }
}
