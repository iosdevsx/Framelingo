import ExportFeature
import SubtitleEditorFeature
import UniformTypeIdentifiers
import XCTest

@testable import MacApp

@MainActor
final class AppKitCapabilityPortsTests: XCTestCase {
    func testSubtitlePickerPassesAllowedSubtitleTypesAndReturnsSelection() async {
        let expectedURL = URL(fileURLWithPath: "/tmp/subtitles.srt")
        var receivedTypes: [UTType] = []
        let picker = AppKitSubtitleDocumentPickerAdapter { contentTypes in
            receivedTypes = contentTypes
            return expectedURL
        }.port

        let outcome = await picker.pick(
            SubtitleDocumentPickerRequest(allowedFileExtensions: ["srt", "vtt", "txt"])
        )

        XCTAssertEqual(outcome, .selected(expectedURL))
        XCTAssertEqual(Set(receivedTypes.map(\.preferredFilenameExtension)), Set(["srt", "vtt", "txt"]))
    }

    func testSubtitlePickerDistinguishesCancellationAndFailure() async {
        let cancelled = AppKitSubtitleDocumentPickerAdapter { _ in nil }.port
        let failed = AppKitSubtitleDocumentPickerAdapter { _ in throw PortTestError.failed }.port
        let request = SubtitleDocumentPickerRequest(allowedFileExtensions: ["srt"])

        let cancelledOutcome = await cancelled.pick(request)
        XCTAssertEqual(cancelledOutcome, .cancelled)
        guard case .failed(let failure) = await failed.pick(request) else {
            return XCTFail("Expected explicit picker failure")
        }
        XCTAssertFalse(failure.message.isEmpty)
    }

    func testSubtitlePickerRejectsUnknownTypesBeforeOpeningPanel() async {
        var didRunPanel = false
        let picker = AppKitSubtitleDocumentPickerAdapter { _ in
            didRunPanel = true
            return nil
        }.port

        let outcome = await picker.pick(
            SubtitleDocumentPickerRequest(allowedFileExtensions: [""])
        )

        guard case .failed = outcome else { return XCTFail("Expected invalid type failure") }
        XCTAssertFalse(didRunPanel)
    }

    func testRevealReportsSuccessMissingOutputAndPlatformFailure() {
        let url = URL(fileURLWithPath: "/tmp/output.mp4")
        var revealedURL: URL?
        let success = AppKitOutputRevealAdapter(
            fileExists: { _ in true },
            reveal: { revealedURL = $0 }
        ).port
        let missing = AppKitOutputRevealAdapter(fileExists: { _ in false }).port
        let failed = AppKitOutputRevealAdapter(
            fileExists: { _ in true },
            reveal: { _ in throw PortTestError.failed }
        ).port

        XCTAssertEqual(success.reveal(url), .success)
        XCTAssertEqual(revealedURL, url)
        guard case .failure = missing.reveal(url) else { return XCTFail("Expected missing failure") }
        guard case .failure = failed.reveal(url) else { return XCTFail("Expected reveal failure") }
    }

    func testRevealPreservesFileURLWithSpacesAndCyrillicCharacters() {
        let url = URL(fileURLWithPath: "/tmp/Готовые видео/мой ролик.mp4")
        var revealedURL: URL?
        let port = AppKitOutputRevealAdapter(
            fileExists: { $0 == url.path },
            reveal: { revealedURL = $0 }
        ).port

        XCTAssertEqual(port.reveal(url), .success)
        XCTAssertEqual(revealedURL, url)
    }

    func testDiagnosticCopyReportsSuccessAndPlatformErrors() {
        var copiedText: String?
        let success = AppKitDiagnosticCopyAdapter { text in
            copiedText = text
            return true
        }.port
        let rejected = AppKitDiagnosticCopyAdapter { _ in false }.port
        let failed = AppKitDiagnosticCopyAdapter { _ in throw PortTestError.failed }.port

        XCTAssertEqual(success.copy("debug"), .success)
        XCTAssertEqual(copiedText, "debug")
        guard case .failure = rejected.copy("debug") else { return XCTFail("Expected copy rejection") }
        guard case .failure = failed.copy("debug") else { return XCTFail("Expected copy failure") }
        guard case .failure = success.copy("") else { return XCTFail("Expected empty diagnostic failure") }
    }
}

private enum PortTestError: Error {
    case failed
}
