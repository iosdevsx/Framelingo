import SubtitleEditorFeature
import XCTest

@MainActor
final class SubtitleDocumentPickerContractTests: XCTestCase {
    func testPortPreservesRequestAndDistinctOutcomes() async {
        let selectedURL = URL(fileURLWithPath: "/tmp/input.srt")
        var receivedRequest: SubtitleDocumentPickerRequest?
        let selected = SubtitleDocumentPicker { request in
            receivedRequest = request
            return .selected(selectedURL)
        }
        let request = SubtitleDocumentPickerRequest(allowedFileExtensions: ["srt", "vtt"])

        let selectedOutcome = await selected.pick(request)
        XCTAssertEqual(selectedOutcome, .selected(selectedURL))
        XCTAssertEqual(receivedRequest, request)

        let cancelled = SubtitleDocumentPicker { _ in .cancelled }
        let failed = SubtitleDocumentPicker { _ in
            .failed(SubtitleDocumentPickerFailure(message: "Unavailable"))
        }
        let cancelledOutcome = await cancelled.pick(request)
        let failedOutcome = await failed.pick(request)
        XCTAssertEqual(cancelledOutcome, .cancelled)
        XCTAssertEqual(
            failedOutcome,
            .failed(SubtitleDocumentPickerFailure(message: "Unavailable"))
        )
    }
}
