import XCTest
@testable import Framelingo

final class EditTimelineServiceTests: XCTestCase {
    private let service = EditTimelineService()

    func testInitialTimelineCreatesOneClip() {
        let timeline = service.makeInitialTimeline(durationMs: 10_000)

        XCTAssertEqual(timeline.clips.count, 1)
        XCTAssertEqual(timeline.totalDurationMs, 10_000)
        XCTAssertEqual(timeline.clips[0].sourceStartMs, 0)
        XCTAssertEqual(timeline.clips[0].sourceEndMs, 10_000)
    }

    func testDeleteMiddleRangeSplitsOneClipIntoTwo() throws {
        let timeline = service.makeInitialTimeline(durationMs: 10_000)

        let updated = try service.rippleDeleteRange(
            timeline: timeline,
            range: VideoCutRange(startMs: 3_000, endMs: 5_000)
        )

        XCTAssertEqual(updated.clips.count, 2)
        XCTAssertEqual(updated.totalDurationMs, 8_000)
        XCTAssertEqual(updated.clips[0].sourceStartMs, 0)
        XCTAssertEqual(updated.clips[0].sourceEndMs, 3_000)
        XCTAssertEqual(updated.clips[1].sourceStartMs, 5_000)
        XCTAssertEqual(updated.clips[1].sourceEndMs, 10_000)
        XCTAssertEqual(updated.clips[1].timelineStartMs, 3_000)
    }

    func testDeleteBeginningTrimsFirstClip() throws {
        let timeline = service.makeInitialTimeline(durationMs: 10_000)

        let updated = try service.rippleDeleteRange(
            timeline: timeline,
            range: VideoCutRange(startMs: 0, endMs: 2_000)
        )

        XCTAssertEqual(updated.clips.count, 1)
        XCTAssertEqual(updated.clips[0].sourceStartMs, 2_000)
        XCTAssertEqual(updated.clips[0].timelineStartMs, 0)
        XCTAssertEqual(updated.totalDurationMs, 8_000)
    }

    func testDeleteEndTrimsLastClip() throws {
        let timeline = service.makeInitialTimeline(durationMs: 10_000)

        let updated = try service.rippleDeleteRange(
            timeline: timeline,
            range: VideoCutRange(startMs: 8_000, endMs: 10_000)
        )

        XCTAssertEqual(updated.clips.count, 1)
        XCTAssertEqual(updated.clips[0].sourceEndMs, 8_000)
        XCTAssertEqual(updated.totalDurationMs, 8_000)
    }

    func testDeleteAcrossMultipleClips() throws {
        let initial = service.makeInitialTimeline(durationMs: 12_000)
        let split = try service.rippleDeleteRange(
            timeline: initial,
            range: VideoCutRange(startMs: 3_000, endMs: 5_000)
        )

        let updated = try service.rippleDeleteRange(
            timeline: split,
            range: VideoCutRange(startMs: 2_000, endMs: 6_000)
        )

        XCTAssertEqual(updated.clips.count, 2)
        XCTAssertEqual(updated.totalDurationMs, 6_000)
        XCTAssertEqual(updated.clips[0].sourceStartMs, 0)
        XCTAssertEqual(updated.clips[0].sourceEndMs, 2_000)
        XCTAssertEqual(updated.clips[1].sourceStartMs, 8_000)
        XCTAssertEqual(updated.clips[1].sourceEndMs, 12_000)
        XCTAssertEqual(updated.clips[1].timelineStartMs, 2_000)
    }

    func testCannotDeleteEntireTimeline() {
        let timeline = service.makeInitialTimeline(durationMs: 10_000)

        XCTAssertThrowsError(
            try service.rippleDeleteRange(
                timeline: timeline,
                range: VideoCutRange(startMs: 0, endMs: 10_000)
            )
        ) { error in
            XCTAssertEqual(error as? EditTimelineError, .cannotDeleteEntireTimeline)
        }
    }

    func testTimelinePositionsRecalculated() {
        let clips = [
            TimelineClip(id: UUID(), sourceStartMs: 4_000, sourceEndMs: 6_000, timelineStartMs: 99, timelineEndMs: 100),
            TimelineClip(id: UUID(), sourceStartMs: 8_000, sourceEndMs: 11_000, timelineStartMs: 99, timelineEndMs: 100)
        ]

        let timeline = service.recalculateTimelinePositions(clips: clips)

        XCTAssertEqual(timeline.clips[0].timelineStartMs, 0)
        XCTAssertEqual(timeline.clips[0].timelineEndMs, 2_000)
        XCTAssertEqual(timeline.clips[1].timelineStartMs, 2_000)
        XCTAssertEqual(timeline.clips[1].timelineEndMs, 5_000)
        XCTAssertEqual(timeline.totalDurationMs, 5_000)
    }

    func testSourceTimeMappingWorks() throws {
        let timeline = try service.rippleDeleteRange(
            timeline: service.makeInitialTimeline(durationMs: 10_000),
            range: VideoCutRange(startMs: 3_000, endMs: 5_000)
        )

        XCTAssertEqual(service.sourceTime(forTimelineTime: 4_000, in: timeline), 6_000)
    }

    func testClipAtTimelineTimeWorks() throws {
        let timeline = try service.rippleDeleteRange(
            timeline: service.makeInitialTimeline(durationMs: 10_000),
            range: VideoCutRange(startMs: 3_000, endMs: 5_000)
        )

        let clip = service.clip(atTimelineTime: 4_000, in: timeline)

        XCTAssertEqual(clip?.sourceStartMs, 5_000)
    }

    // MARK: - playbackAdvance

    func testPlaybackAdvancePausesWhenTimelineIsEmpty() {
        let timeline = EditTimeline(clips: [], totalDurationMs: 0)

        let result = service.playbackAdvance(
            sourceTimeMs: 0,
            currentClipID: nil,
            lastKnownTimelineMs: 0,
            in: timeline
        )

        XCTAssertEqual(result, .paused)
    }

    func testPlaybackAdvancePausesWhenCurrentClipCannotBeResolved() throws {
        let timeline = try service.rippleDeleteRange(
            timeline: service.makeInitialTimeline(durationMs: 10_000),
            range: VideoCutRange(startMs: 3_000, endMs: 5_000)
        )

        let result = service.playbackAdvance(
            sourceTimeMs: 0,
            currentClipID: nil,
            lastKnownTimelineMs: -100,
            in: timeline
        )

        XCTAssertEqual(result, .paused)
    }

    func testPlaybackAdvanceSeeksWithinCurrentClip() throws {
        let timeline = try service.rippleDeleteRange(
            timeline: service.makeInitialTimeline(durationMs: 10_000),
            range: VideoCutRange(startMs: 3_000, endMs: 5_000)
        )
        let firstClip = timeline.clips[0]

        let result = service.playbackAdvance(
            sourceTimeMs: 1_500,
            currentClipID: firstClip.id,
            lastKnownTimelineMs: 0,
            in: timeline
        )

        XCTAssertEqual(result, .seekWithinClip(timelineMs: 1_500))
    }

    func testPlaybackAdvanceMovesToNextClipNearCutBoundary() throws {
        let timeline = try service.rippleDeleteRange(
            timeline: service.makeInitialTimeline(durationMs: 10_000),
            range: VideoCutRange(startMs: 3_000, endMs: 5_000)
        )
        let firstClip = timeline.clips[0]

        let result = service.playbackAdvance(
            sourceTimeMs: 2_980,
            currentClipID: firstClip.id,
            lastKnownTimelineMs: 0,
            in: timeline
        )

        XCTAssertEqual(result, .advanceToNextClip(timeline.clips[1]))
    }

    func testPlaybackAdvanceFinishesOnLastClipCutBoundary() throws {
        let timeline = try service.rippleDeleteRange(
            timeline: service.makeInitialTimeline(durationMs: 10_000),
            range: VideoCutRange(startMs: 3_000, endMs: 5_000)
        )
        let lastClip = timeline.clips[1]

        let result = service.playbackAdvance(
            sourceTimeMs: 9_980,
            currentClipID: lastClip.id,
            lastKnownTimelineMs: 0,
            in: timeline
        )

        XCTAssertEqual(result, .finished(totalDurationMs: timeline.totalDurationMs))
    }

    func testPlaybackAdvancePrefersCurrentClipIDOverLastKnownTimelineMs() throws {
        let timeline = try service.rippleDeleteRange(
            timeline: service.makeInitialTimeline(durationMs: 10_000),
            range: VideoCutRange(startMs: 3_000, endMs: 5_000)
        )
        let firstClip = timeline.clips[0]

        // lastKnownTimelineMs falls within the second clip's timeline range, but
        // currentClipID must take priority and resolve to the first clip instead.
        let result = service.playbackAdvance(
            sourceTimeMs: 1_000,
            currentClipID: firstClip.id,
            lastKnownTimelineMs: 5_000,
            in: timeline
        )

        XCTAssertEqual(result, .seekWithinClip(timelineMs: 1_000))
    }

    func testPlaybackAdvanceLookaheadMsShiftsTheCutBoundaryDecision() throws {
        let timeline = try service.rippleDeleteRange(
            timeline: service.makeInitialTimeline(durationMs: 10_000),
            range: VideoCutRange(startMs: 3_000, endMs: 5_000)
        )
        let firstClip = timeline.clips[0]

        let withDefaultLookahead = service.playbackAdvance(
            sourceTimeMs: 2_950,
            currentClipID: firstClip.id,
            lastKnownTimelineMs: 0,
            in: timeline
        )
        XCTAssertEqual(withDefaultLookahead, .seekWithinClip(timelineMs: 2_950))

        let withWiderLookahead = service.playbackAdvance(
            sourceTimeMs: 2_950,
            currentClipID: firstClip.id,
            lastKnownTimelineMs: 0,
            in: timeline,
            lookaheadMs: 100
        )
        XCTAssertEqual(withWiderLookahead, .advanceToNextClip(timeline.clips[1]))
    }
}
