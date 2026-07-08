import XCTest
@testable import Framelingo

final class WhisperModelTests: XCTestCase {
    func testLargeV3TurboFileNameAndDownloadURL() {
        XCTAssertEqual(WhisperModel.largeV3Turbo.fileName, "ggml-large-v3-turbo.bin")
        XCTAssertEqual(
            WhisperModel.largeV3Turbo.downloadURL.absoluteString,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
        )
    }

    func testLargeV3TurboQ5_0FileNameAndDownloadURL() {
        XCTAssertEqual(WhisperModel.largeV3TurboQ5_0.fileName, "ggml-large-v3-turbo-q5_0.bin")
        XCTAssertEqual(
            WhisperModel.largeV3TurboQ5_0.downloadURL.absoluteString,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin"
        )
    }

    func testNewModelDisplayNamesAndSizes() {
        XCTAssertEqual(WhisperModel.largeV3Turbo.displayName, "Large v3 Turbo")
        XCTAssertEqual(WhisperModel.largeV3TurboQ5_0.displayName, "Large v3 Turbo (Quantized)")
        XCTAssertEqual(WhisperModel.largeV3Turbo.approximateSizeText, "~1.6 GB")
        XCTAssertEqual(WhisperModel.largeV3TurboQ5_0.approximateSizeText, "~574 MB")
    }

    func testDTWPresets() {
        XCTAssertEqual(WhisperModel.tiny.dtwPreset, "tiny")
        XCTAssertEqual(WhisperModel.base.dtwPreset, "base")
        XCTAssertEqual(WhisperModel.small.dtwPreset, "small")
        XCTAssertEqual(WhisperModel.largeV3Turbo.dtwPreset, "large.v3.turbo")
        XCTAssertEqual(WhisperModel.largeV3TurboQ5_0.dtwPreset, "large.v3.turbo")
    }

    func testVADModelDefinition() {
        XCTAssertEqual(WhisperVADModel.fileName, "ggml-silero-v5.1.2.bin")
        XCTAssertEqual(
            WhisperVADModel.downloadURL.absoluteString,
            "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin"
        )
    }
}
