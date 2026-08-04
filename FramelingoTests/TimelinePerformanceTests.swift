import XCTest
@testable import Framelingo

final class TimelinePerformanceTests: XCTestCase {
    func testCompactShortsTrackStaysBetweenRulerAndCues() {
        let layout = SubtitleTimelineTrackLayout(
            rulerHeight: 24,
            shortsHeight: 22,
            waveformHeight: 0,
            cueHeight: 34
        )

        XCTAssertEqual(layout.shortsTopY, 24)
        XCTAssertEqual(layout.waveformTopY, 46)
        XCTAssertEqual(layout.cueTopY, 50)
        XCTAssertEqual(layout.minimumContentHeight, 94)
    }

    func testExpandedShortsTrackPlacesWaveformBeforeCues() {
        let layout = SubtitleTimelineTrackLayout(
            rulerHeight: 24,
            shortsHeight: 22,
            waveformHeight: 74,
            cueHeight: 34
        )

        XCTAssertEqual(layout.waveformTopY, 46)
        XCTAssertEqual(layout.cueTopY, 124)
    }

    func testWaveformShrinksToKeepShortsAndCuesInsideTimeline() {
        let waveformHeight = SubtitleTimelineTrackLayout.resolvedWaveformHeight(
            isVisible: true,
            preferredHeight: 74,
            availableHeight: 146,
            rulerHeight: 24,
            shortsHeight: 22,
            cueHeight: 34
        )
        let layout = SubtitleTimelineTrackLayout(
            rulerHeight: 24,
            shortsHeight: 22,
            waveformHeight: waveformHeight,
            cueHeight: 34
        )

        XCTAssertEqual(waveformHeight, 52)
        XCTAssertEqual(layout.minimumContentHeight, 146)
    }

    func testFrameStepperMovesExactlyOneNTSCFrameAndClamps() {
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

        XCTAssertEqual(first, 33)
        XCTAssertEqual(second, 67)
        XCTAssertEqual(back, first)
        XCTAssertEqual(TimelineFrameStepper.steppedTime(
            from: 10_000,
            direction: 1,
            frameRate: 30,
            durationMs: 10_000
        ), 10_000)
    }

    func testFrameStepperMovesToAdjacentBoundaryFromArbitraryPlayheadTime() {
        XCTAssertEqual(TimelineFrameStepper.steppedTime(
            from: 50,
            direction: 1,
            frameRate: 30,
            durationMs: 10_000
        ), 67)
        XCTAssertEqual(TimelineFrameStepper.steppedTime(
            from: 50,
            direction: -1,
            frameRate: 30,
            durationMs: 10_000
        ), 33)
    }

    func testVisibleRangeClampsWithBuffer() {
        let range = TimelineVisibleRange.visible(
            scrollOffsetX: 80,
            viewportWidth: 100,
            pxPerMs: 0.1,
            durationMs: 3_000,
            bufferScreens: 1
        )

        XCTAssertEqual(range, TimelineVisibleRange(startMs: 0, endMs: 2_800))
    }

    func testVisibleRangeClampsToDuration() {
        let range = TimelineVisibleRange.visible(
            scrollOffsetX: 250,
            viewportWidth: 100,
            pxPerMs: 0.1,
            durationMs: 3_000,
            bufferScreens: 1
        )

        XCTAssertEqual(range, TimelineVisibleRange(startMs: 1_500, endMs: 3_000))
    }

    func testVisibleSegmentsIncludeBoundaryOverlaps() {
        let segments = [
            segment(index: 1, startMs: 0, endMs: 900),
            segment(index: 2, startMs: 900, endMs: 1_200),
            segment(index: 3, startMs: 1_200, endMs: 1_800),
            segment(index: 4, startMs: 1_800, endMs: 2_200)
        ]

        let visible = Array(TimelinePerformance.visibleSegments(
            in: segments,
            range: TimelineVisibleRange(startMs: 1_000, endMs: 1_900)
        ))

        XCTAssertEqual(visible.map(\.index), [2, 3, 4])
    }

    func testVisibleSegmentsExcludeTouchingEndBoundary() {
        let segments = [
            segment(index: 1, startMs: 0, endMs: 1_000),
            segment(index: 2, startMs: 1_000, endMs: 2_000)
        ]

        let visible = Array(TimelinePerformance.visibleSegments(
            in: segments,
            range: TimelineVisibleRange(startMs: 1_000, endMs: 1_500)
        ))

        XCTAssertEqual(visible.map(\.index), [2])
    }

    func testActiveSegmentLookupFindsSegmentAndGaps() {
        let firstID = UUID()
        let secondID = UUID()
        let segments = [
            segment(id: firstID, index: 1, startMs: 0, endMs: 1_000),
            segment(id: secondID, index: 2, startMs: 2_000, endMs: 3_000)
        ]

        XCTAssertEqual(TimelinePerformance.activeSegmentID(at: 500, in: segments), firstID)
        XCTAssertNil(TimelinePerformance.activeSegmentID(at: 1_500, in: segments))
        XCTAssertEqual(TimelinePerformance.activeSegmentID(at: 2_500, in: segments), secondID)
        XCTAssertNil(TimelinePerformance.activeSegmentID(at: 4_000, in: segments))
    }

    func testWaveformDownsamplingPreservesMaximumAmplitudePerBucket() {
        let buckets = TimelinePerformance.downsampleWaveform(
            peaks: [0.1, 0.4, 0.2, 0.9, 0.3, 0.8],
            durationMs: 6_000,
            visibleRange: TimelineVisibleRange(startMs: 0, endMs: 6_000),
            targetBucketCount: 3
        )

        XCTAssertEqual(buckets.count, 3)
        XCTAssertEqual(buckets.map(\.amplitude), [0.4, 0.9, 0.8])
    }

    private func segment(
        id: UUID = UUID(),
        index: Int,
        startMs: Int,
        endMs: Int
    ) -> SubtitleSegment {
        SubtitleSegment(
            id: id,
            index: index,
            startMs: startMs,
            endMs: endMs,
            originalText: "Original \(index)",
            translatedText: "Translated \(index)",
            speaker: nil,
            confidence: nil
        )
    }
}
