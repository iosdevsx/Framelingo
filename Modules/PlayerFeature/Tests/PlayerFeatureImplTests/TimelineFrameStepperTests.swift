import PlayerFeature
import Testing

struct TimelineFrameStepperTests {
    @Test
    func movesExactlyOneNTSCFrameAndClamps() {
        let first = TimelineFrameStepper.steppedTime(
            from: 0,
            direction: 1,
            frameRate: 29.97,
            durationMs: 10_000
        )
        let second = TimelineFrameStepper.steppedTime(
            from: first,
            direction: 1,
            frameRate: 29.97,
            durationMs: 10_000
        )
        let back = TimelineFrameStepper.steppedTime(
            from: second,
            direction: -1,
            frameRate: 29.97,
            durationMs: 10_000
        )

        #expect(first == 33)
        #expect(second == 67)
        #expect(back == first)
        #expect(TimelineFrameStepper.steppedTime(
            from: 10_000,
            direction: 1,
            frameRate: 30,
            durationMs: 10_000
        ) == 10_000)
    }

    @Test
    func movesToAdjacentBoundaryFromArbitraryPlayheadTime() {
        #expect(TimelineFrameStepper.steppedTime(
            from: 50,
            direction: 1,
            frameRate: 30,
            durationMs: 10_000
        ) == 67)
        #expect(TimelineFrameStepper.steppedTime(
            from: 50,
            direction: -1,
            frameRate: 30,
            durationMs: 10_000
        ) == 33)
    }
}
