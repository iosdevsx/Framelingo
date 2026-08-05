import Foundation
import Shorts
import Subtitles
import Testing
import Timeline
import VideoRendering

struct ShortsClipPlannerTests {
    @Test
    func shortWithoutEditTimelineMapsToSingleSourceRange() throws {
        let short = ShortDefinition(title: "One", startMs: 100_000, endMs: 140_000)

        let clips = try ShortsClipPlanner.clips(for: short, editTimeline: nil)

        #expect(clips == [ExportClipRange(sourceStartMs: 100_000, sourceEndMs: 140_000)])
    }

    @Test
    func shortSpanningCutResolvesToTwoSourceRanges() throws {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 120_000,
                    timelineStartMs: 0,
                    timelineEndMs: 120_000
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 300_000,
                    sourceEndMs: 420_000,
                    timelineStartMs: 120_000,
                    timelineEndMs: 240_000
                )
            ],
            totalDurationMs: 240_000
        )
        let short = ShortDefinition(title: "Cut", startMs: 100_000, endMs: 140_000)

        let clips = try ShortsClipPlanner.clips(for: short, editTimeline: timeline)

        #expect(clips == [
            ExportClipRange(sourceStartMs: 100_000, sourceEndMs: 120_000),
            ExportClipRange(sourceStartMs: 300_000, sourceEndMs: 320_000)
        ])
    }

    @Test
    func degenerateShortThrowsEmptyPlan() {
        let short = ShortDefinition(title: "Empty", startMs: 5_000, endMs: 5_000)

        #expect(throws: ExportClipPlanError.emptyPlan) {
            try ShortsClipPlanner.clips(for: short, editTimeline: nil)
        }
    }

    @Test
    func shortOutsideTimelineThrowsEmptyPlan() {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 60_000,
                    timelineStartMs: 0,
                    timelineEndMs: 60_000
                )
            ],
            totalDurationMs: 60_000
        )
        let short = ShortDefinition(title: "Beyond", startMs: 70_000, endMs: 80_000)

        #expect(throws: ExportClipPlanError.emptyPlan) {
            try ShortsClipPlanner.clips(for: short, editTimeline: timeline)
        }
    }

    @Test
    func localizedSubtitlesClampAndShiftIntoShortTime() {
        let cues = [
            makeCue(index: 1, startMs: 0, endMs: 2_000, text: "before"),
            makeCue(index: 2, startMs: 3_000, endMs: 5_000, text: "clipped head"),
            makeCue(index: 3, startMs: 5_500, endMs: 9_000, text: "inside"),
            makeCue(index: 4, startMs: 10_000, endMs: 12_000, text: "clipped tail"),
            makeCue(index: 5, startMs: 12_000, endMs: 14_000, text: "after")
        ]
        let originalCues = cues
        let short = ShortDefinition(title: "Mid", startMs: 4_000, endMs: 11_000)

        let localized = ShortsClipPlanner.localizedSubtitles(cues, for: short)

        #expect(localized.count == 3)
        #expect(localized[0].originalText == "clipped head")
        #expect(localized[0].startMs == 0)
        #expect(localized[0].endMs == 1_000)
        #expect(localized[1].originalText == "inside")
        #expect(localized[1].startMs == 1_500)
        #expect(localized[1].endMs == 5_000)
        #expect(localized[2].originalText == "clipped tail")
        #expect(localized[2].startMs == 6_000)
        #expect(localized[2].endMs == 7_000)
        #expect(localized.map(\.index) == [1, 2, 3])
        #expect(cues == originalCues)
    }

    private func makeCue(index: Int, startMs: Int, endMs: Int, text: String) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: index,
            startMs: startMs,
            endMs: endMs,
            originalText: text,
            translatedText: ""
        )
    }
}
