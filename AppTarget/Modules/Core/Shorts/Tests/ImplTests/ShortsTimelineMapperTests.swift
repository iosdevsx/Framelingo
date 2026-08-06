import Foundation
import Shorts
import Testing
import Timeline

struct ShortsTimelineMapperTests {
    private let mapper = SubtitleTimelineMappingService()

    @Test
    func shortBeforeCutIsUnchanged() {
        let shorts = [ShortDefinition(title: "A", startMs: 0, endMs: 10_000)]
        let updated = mapper.rippleDeleteShorts(
            shorts: shorts,
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        )
        #expect(updated == shorts)
    }

    @Test
    func shortAfterCutShiftsLeft() {
        let shorts = [ShortDefinition(id: UUID(), title: "B", startMs: 300_000, endMs: 340_000)]
        let updated = mapper.rippleDeleteShorts(
            shorts: shorts,
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        )
        #expect(updated.first?.startMs == 290_000)
        #expect(updated.first?.endMs == 330_000)
        #expect(updated.first?.id == shorts.first?.id)
    }

    @Test
    func shortContainingCutShrinks() {
        let updated = mapper.rippleDeleteShorts(
            shorts: [ShortDefinition(title: "C", startMs: 10_000, endMs: 50_000)],
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        )
        #expect(updated.first?.startMs == 10_000)
        #expect(updated.first?.endMs == 40_000)
    }

    @Test
    func rippleDeleteRetimesAndDropsCropPoints() throws {
        let short = ShortDefinition(
            title: "Interview",
            startMs: 10_000,
            endMs: 50_000,
            cropKeyframes: [
                ShortCropKeyframe(timeMs: 5_000, offsetX: 0.1),
                ShortCropKeyframe(timeMs: 15_000, offsetX: 0.5),
                ShortCropKeyframe(timeMs: 30_000, offsetX: 0.9)
            ]
        )
        let updated = try #require(mapper.rippleDeleteShorts(
            shorts: [short],
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        ).first)
        #expect(updated.cropKeyframes.map(\.timeMs) == [5_000, 20_000])
        #expect(updated.cropKeyframes.map(\.offsetX) == [0.1, 0.9])
    }

    @Test
    func shortInsideCutIsDropped() {
        let updated = mapper.rippleDeleteShorts(
            shorts: [
                ShortDefinition(title: "Gone", startMs: 22_000, endMs: 28_000),
                ShortDefinition(title: "Kept", startMs: 40_000, endMs: 45_000)
            ],
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        )
        #expect(updated.count == 1)
        #expect(updated.first?.startMs == 30_000)
        #expect(updated.first?.endMs == 35_000)
    }

    @Test
    func shortsOverlappingCutEdgesAreTrimmed() {
        let updated = mapper.rippleDeleteShorts(
            shorts: [
                ShortDefinition(title: "Head", startMs: 15_000, endMs: 25_000),
                ShortDefinition(title: "Tail", startMs: 25_000, endMs: 35_000)
            ],
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        )
        #expect(updated.map(\.startMs) == [15_000, 20_000])
        #expect(updated.map(\.endMs) == [20_000, 25_000])
    }
}
