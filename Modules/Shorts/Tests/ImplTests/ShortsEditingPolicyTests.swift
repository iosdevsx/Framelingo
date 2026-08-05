import Foundation
import Shorts
import Testing

struct ShortsEditingPolicyTests {
    private let policy = ShortsEditingPolicy()

    @Test
    func addClampsStartAndSortsCollection() throws {
        let later = ShortDefinition(title: "Later", startMs: 5_000, endMs: 7_000)
        let addedID = UUID()

        let result = try policy.add(
            shorts: [later], title: "First", startMs: -500, endMs: 2_000, id: addedID
        )

        #expect(result.shorts.map(\.id) == [addedID, later.id])
        #expect(result.shorts[0].startMs == 0)
        #expect(result.didChange)
    }

    @Test
    func invalidClampedRangeReturnsTypedError() {
        #expect(throws: ShortsEditError.invalidRange) {
            try policy.add(shorts: [], title: "Invalid", startMs: -1_000, endMs: 0)
        }
    }

    @Test
    func rangeEditRelocatesAndRemovesKeyframesAtBoundaries() throws {
        let beforeID = UUID()
        let startID = UUID()
        let endID = UUID()
        let afterID = UUID()
        let short = ShortDefinition(
            title: "Range",
            startMs: 1_000,
            endMs: 8_000,
            cropKeyframes: [
                ShortCropKeyframe(id: beforeID, timeMs: 500, offsetX: 0.1),
                ShortCropKeyframe(id: startID, timeMs: 2_000, offsetX: 0.2),
                ShortCropKeyframe(id: endID, timeMs: 5_000, offsetX: 0.8),
                ShortCropKeyframe(id: afterID, timeMs: 6_000, offsetX: 0.9),
            ]
        )

        let result = try policy.updateRange(
            shorts: [short], id: short.id, startMs: 3_000, endMs: 6_000
        )
        let updated = result.shorts[0]

        #expect(updated.startMs == 3_000)
        #expect(updated.endMs == 6_000)
        #expect(updated.cropKeyframes.map(\.id) == [startID, endID])
        #expect(updated.cropKeyframes.map(\.timeMs) == [0, 3_000])
    }

    @Test
    func cropUpsertClampsTimeAndOffsetAndKeepsPointsSorted() throws {
        let short = ShortDefinition(title: "Crop", startMs: 2_000, endMs: 5_000)
        let afterEnd = try policy.upsertCropKeyframe(
            shorts: [short], id: short.id, timelineTimeMs: 9_000, offsetX: 2
        )
        let beforeStart = try policy.upsertCropKeyframe(
            shorts: afterEnd.shorts, id: short.id, timelineTimeMs: 1_000, offsetX: -1
        )

        #expect(beforeStart.shorts[0].cropKeyframes.map(\.timeMs) == [0, 3_000])
        #expect(beforeStart.shorts[0].cropKeyframes.map(\.offsetX) == [0, 1])
        #expect(beforeStart.shorts[0].cropOffset(atTimelineTimeMs: 1_999) == 0)
        #expect(beforeStart.shorts[0].cropOffset(atTimelineTimeMs: 5_000) == 1)
    }

    @Test
    func cropDeleteAndUnchangedMutationReportWhetherACommitIsNeeded() throws {
        let keyframe = ShortCropKeyframe(timeMs: 500, offsetX: 0.2)
        let short = ShortDefinition(
            title: "Crop", startMs: 0, endMs: 2_000, cropKeyframes: [keyframe]
        )

        let deleted = try policy.deleteCropKeyframe(
            shorts: [short], shortID: short.id, keyframeID: keyframe.id
        )
        let unchanged = try policy.deleteCropKeyframe(
            shorts: deleted.shorts, shortID: short.id, keyframeID: keyframe.id
        )

        #expect(deleted.shorts[0].cropKeyframes.isEmpty)
        #expect(deleted.didChange)
        #expect(!unchanged.didChange)
    }

    @Test
    func suggestionInputsProduceTheSameRangeAndIdentity() throws {
        let suggestion = ShortSuggestion(
            startMs: 4_000,
            endMs: 12_000,
            reason: .pause
        )

        let result = try policy.add(
            shorts: [],
            title: "Suggested",
            startMs: suggestion.startMs,
            endMs: suggestion.endMs
        )

        #expect(result.shorts[0].startMs == suggestion.startMs)
        #expect(result.shorts[0].endMs == suggestion.endMs)
        #expect(result.editedShortID == result.shorts[0].id)
    }

    @Test
    func missingShortReturnsTypedError() {
        #expect(throws: ShortsEditError.shortNotFound) {
            try policy.updateRange(shorts: [], id: UUID(), startMs: 0, endMs: 1_000)
        }
    }
}
