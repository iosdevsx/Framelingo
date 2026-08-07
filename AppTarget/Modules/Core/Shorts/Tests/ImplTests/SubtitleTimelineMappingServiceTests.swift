import Foundation
import Shorts
import Subtitles
import Testing
import Timeline

struct SubtitleTimelineMappingServiceTests {
    private let service = SubtitleTimelineMappingService()

    @Test
    func subtitlesAfterDeletedRangeShiftLeft() {
        let segments = [segment(index: 1, start: 6_000, end: 8_000)]

        let updated = service.rippleDeleteSubtitles(
            segments: segments,
            range: VideoCutRange(startMs: 2_000, endMs: 5_000)
        )

        #expect(updated[0].startMs == 3_000)
        #expect(updated[0].endMs == 5_000)
    }

    @Test
    func subtitlesInsideDeletedRangeRemoved() {
        let segments = [
            segment(index: 1, start: 2_500, end: 4_000),
            segment(index: 2, start: 5_000, end: 7_000)
        ]

        let updated = service.rippleDeleteSubtitles(
            segments: segments,
            range: VideoCutRange(startMs: 2_000, endMs: 4_500)
        )

        #expect(updated.count == 1)
        #expect(updated[0].startMs == 2_500)
    }

    @Test
    func subtitleCrossingLeftBoundaryTrimmed() {
        let segments = [segment(index: 1, start: 1_000, end: 3_000)]

        let updated = service.rippleDeleteSubtitles(
            segments: segments,
            range: VideoCutRange(startMs: 2_000, endMs: 4_000)
        )

        #expect(updated.count == 1)
        #expect(updated[0].startMs == 1_000)
        #expect(updated[0].endMs == 2_000)
    }

    @Test
    func subtitleCrossingRightBoundaryTrimmedAndShifted() {
        let segments = [segment(index: 1, start: 3_000, end: 6_000)]

        let updated = service.rippleDeleteSubtitles(
            segments: segments,
            range: VideoCutRange(startMs: 2_000, endMs: 4_000)
        )

        #expect(updated.count == 1)
        #expect(updated[0].startMs == 2_000)
        #expect(updated[0].endMs == 4_000)
    }

    @Test
    func indicesRecalculated() {
        let segments = [
            segment(index: 10, start: 0, end: 1_000),
            segment(index: 11, start: 3_000, end: 5_000),
            segment(index: 12, start: 7_000, end: 9_000)
        ]

        let updated = service.rippleDeleteSubtitles(
            segments: segments,
            range: VideoCutRange(startMs: 2_000, endMs: 6_000)
        )

        #expect(updated.map(\.index) == [1, 2])
    }

    @Test
    func zeroLengthRangeLeavesValuesIntactAndReindexesSubtitles() {
        let subtitle = segment(index: 9, start: 1_000, end: 2_000)
        let short = ShortDefinition(title: "Keep", startMs: 1_000, endMs: 3_000)
        let range = VideoCutRange(startMs: 2_000, endMs: 2_000)

        let subtitles = service.rippleDeleteSubtitles(segments: [subtitle], range: range)
        let shorts = service.rippleDeleteShorts(shorts: [short], range: range)

        #expect(subtitles[0].id == subtitle.id)
        #expect(subtitles[0].index == 1)
        #expect(shorts == [short])
    }

    @Test
    func shortCrossingCutMovesRangeAndRelocatesOnlySurvivingKeyframes() {
        let beforeID = UUID()
        let insideID = UUID()
        let afterID = UUID()
        let short = ShortDefinition(
            title: "Mapped",
            startMs: 1_000,
            endMs: 8_000,
            cropKeyframes: [
                ShortCropKeyframe(id: beforeID, timeMs: 500, offsetX: 0.2),
                ShortCropKeyframe(id: insideID, timeMs: 2_000, offsetX: 0.5),
                ShortCropKeyframe(id: afterID, timeMs: 5_000, offsetX: 0.8),
            ]
        )

        let updated = service.rippleDeleteShorts(
            shorts: [short],
            range: VideoCutRange(startMs: 2_000, endMs: 5_000)
        )

        #expect(updated.count == 1)
        #expect(updated[0].startMs == 1_000)
        #expect(updated[0].endMs == 5_000)
        #expect(updated[0].cropKeyframes.map(\.id) == [beforeID, afterID])
        #expect(updated[0].cropKeyframes.map(\.timeMs) == [500, 2_000])
    }

    @Test
    func shortsAtCutBoundariesStayOrShiftWithoutOverlap() {
        let before = ShortDefinition(title: "Before", startMs: 0, endMs: 2_000)
        let after = ShortDefinition(title: "After", startMs: 4_000, endMs: 6_000)

        let updated = service.rippleDeleteShorts(
            shorts: [before, after],
            range: VideoCutRange(startMs: 2_000, endMs: 4_000)
        )

        #expect(updated.map(\.startMs) == [0, 2_000])
        #expect(updated.map(\.endMs) == [2_000, 4_000])
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
