import XCTest
@testable import Framelingo

final class SubtitleTimelineMappingServiceTests: XCTestCase {
    private let service = SubtitleTimelineMappingService()

    func testSubtitlesAfterDeletedRangeShiftLeft() {
        let segments = [
            segment(index: 1, start: 6_000, end: 8_000)
        ]

        let updated = service.rippleDeleteSubtitles(
            segments: segments,
            range: VideoCutRange(startMs: 2_000, endMs: 5_000)
        )

        XCTAssertEqual(updated[0].startMs, 3_000)
        XCTAssertEqual(updated[0].endMs, 5_000)
    }

    func testSubtitlesInsideDeletedRangeRemoved() {
        let segments = [
            segment(index: 1, start: 2_500, end: 4_000),
            segment(index: 2, start: 5_000, end: 7_000)
        ]

        let updated = service.rippleDeleteSubtitles(
            segments: segments,
            range: VideoCutRange(startMs: 2_000, endMs: 4_500)
        )

        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(updated[0].startMs, 2_500)
    }

    func testSubtitleCrossingLeftBoundaryTrimmed() {
        let segments = [
            segment(index: 1, start: 1_000, end: 3_000)
        ]

        let updated = service.rippleDeleteSubtitles(
            segments: segments,
            range: VideoCutRange(startMs: 2_000, endMs: 4_000)
        )

        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(updated[0].startMs, 1_000)
        XCTAssertEqual(updated[0].endMs, 2_000)
    }

    func testSubtitleCrossingRightBoundaryTrimmedAndShifted() {
        let segments = [
            segment(index: 1, start: 3_000, end: 6_000)
        ]

        let updated = service.rippleDeleteSubtitles(
            segments: segments,
            range: VideoCutRange(startMs: 2_000, endMs: 4_000)
        )

        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(updated[0].startMs, 2_000)
        XCTAssertEqual(updated[0].endMs, 4_000)
    }

    func testIndicesRecalculated() {
        let segments = [
            segment(index: 10, start: 0, end: 1_000),
            segment(index: 11, start: 3_000, end: 5_000),
            segment(index: 12, start: 7_000, end: 9_000)
        ]

        let updated = service.rippleDeleteSubtitles(
            segments: segments,
            range: VideoCutRange(startMs: 2_000, endMs: 6_000)
        )

        XCTAssertEqual(updated.map(\.index), [1, 2])
    }

    private func segment(index: Int, start: Int, end: Int) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: index,
            startMs: start,
            endMs: end,
            originalText: "Original \(index)",
            translatedText: "",
            speaker: nil,
            confidence: nil
        )
    }
}
