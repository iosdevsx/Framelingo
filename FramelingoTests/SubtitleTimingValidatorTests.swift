import Testing
import Foundation
@testable import Framelingo

struct SubtitleTimingValidatorTests {
    @Test
    func testResizeLeftBoundary() {
        let id = UUID()
        let result = SubtitleTimingValidator.resizeSegment(
            segments: [segment(id: id, index: 1, start: 1_000, end: 3_000)],
            id: id,
            edge: .left,
            deltaMs: 500,
            durationMs: 10_000
        )

        #expect(result[0].startMs == 1_500)
        #expect(result[0].endMs == 3_000)
    }

    @Test
    func testResizeRightBoundary() {
        let id = UUID()
        let result = SubtitleTimingValidator.resizeSegment(
            segments: [segment(id: id, index: 1, start: 1_000, end: 3_000)],
            id: id,
            edge: .right,
            deltaMs: 700,
            durationMs: 10_000
        )

        #expect(result[0].startMs == 1_000)
        #expect(result[0].endMs == 3_700)
    }

    @Test
    func testMoveWholeSegment() {
        let id = UUID()
        let result = SubtitleTimingValidator.moveSegment(
            segments: [segment(id: id, index: 1, start: 1_000, end: 3_000)],
            id: id,
            deltaMs: 1_200,
            durationMs: 10_000
        )

        #expect(result[0].startMs == 2_200)
        #expect(result[0].endMs == 4_200)
    }

    @Test
    func testMinimumDuration() {
        let id = UUID()
        let result = SubtitleTimingValidator.resizeSegment(
            segments: [segment(id: id, index: 1, start: 1_000, end: 3_000)],
            id: id,
            edge: .right,
            deltaMs: -1_800,
            durationMs: 10_000
        )

        #expect(result[0].startMs == 1_000)
        #expect(result[0].endMs == 1_500)
    }

    @Test
    func testNoOverlapWithPrevious() {
        let previousID = UUID()
        let id = UUID()
        let result = SubtitleTimingValidator.resizeSegment(
            segments: [
                segment(id: previousID, index: 1, start: 0, end: 1_000),
                segment(id: id, index: 2, start: 1_500, end: 3_000)
            ],
            id: id,
            edge: .left,
            deltaMs: -1_000,
            durationMs: 10_000
        )

        #expect(result[1].startMs == 1_050)
        #expect(result[1].endMs == 3_000)
    }

    @Test
    func testNoOverlapWithNext() {
        let id = UUID()
        let nextID = UUID()
        let result = SubtitleTimingValidator.resizeSegment(
            segments: [
                segment(id: id, index: 1, start: 1_000, end: 2_000),
                segment(id: nextID, index: 2, start: 3_000, end: 4_000)
            ],
            id: id,
            edge: .right,
            deltaMs: 2_000,
            durationMs: 10_000
        )

        #expect(result[0].startMs == 1_000)
        #expect(result[0].endMs == 2_950)
    }

    @Test
    func testClampToZero() {
        let id = UUID()
        let result = SubtitleTimingValidator.moveSegment(
            segments: [segment(id: id, index: 1, start: 1_000, end: 2_000)],
            id: id,
            deltaMs: -5_000,
            durationMs: 10_000
        )

        #expect(result[0].startMs == 0)
        #expect(result[0].endMs == 1_000)
    }

    @Test
    func testClampToDuration() {
        let id = UUID()
        let result = SubtitleTimingValidator.moveSegment(
            segments: [segment(id: id, index: 1, start: 1_000, end: 3_000)],
            id: id,
            deltaMs: 10_000,
            durationMs: 5_000
        )

        #expect(result[0].startMs == 3_000)
        #expect(result[0].endMs == 5_000)
    }

    @Test
    func testMoveDoesNotCrashWhenThereIsNoValidGap() {
        let previousID = UUID()
        let id = UUID()
        let nextID = UUID()
        let result = SubtitleTimingValidator.moveSegment(
            segments: [
                segment(id: previousID, index: 1, start: 0, end: 1_000),
                segment(id: id, index: 2, start: 900, end: 2_000),
                segment(id: nextID, index: 3, start: 1_950, end: 3_000)
            ],
            id: id,
            deltaMs: 300,
            durationMs: 10_000
        )

        #expect(result[1].startMs == 900)
        #expect(result[1].endMs == 2_000)
    }

    @Test
    func testResizeDoesNotCrashWhenThereIsNoValidGap() {
        let previousID = UUID()
        let id = UUID()
        let result = SubtitleTimingValidator.resizeSegment(
            segments: [
                segment(id: previousID, index: 1, start: 0, end: 1_900),
                segment(id: id, index: 2, start: 1_800, end: 2_200)
            ],
            id: id,
            edge: .left,
            deltaMs: -500,
            durationMs: 10_000
        )

        #expect(result[1].startMs == 1_800)
        #expect(result[1].endMs == 2_200)
    }

    private func segment(id: UUID, index: Int, start: Int, end: Int) -> SubtitleSegment {
        SubtitleSegment(
            id: id,
            index: index,
            startMs: start,
            endMs: end,
            originalText: "Original \(index)",
            translatedText: ""
        )
    }
}
