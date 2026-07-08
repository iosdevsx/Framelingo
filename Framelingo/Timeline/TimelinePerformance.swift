import CoreGraphics
import Foundation

struct TimelineVisibleRange: Equatable {
    let startMs: Int
    let endMs: Int

    var durationMs: Int {
        max(0, endMs - startMs)
    }

    func contains(_ milliseconds: Int) -> Bool {
        milliseconds >= startMs && milliseconds <= endMs
    }

    func intersects(startMs segmentStartMs: Int, endMs segmentEndMs: Int) -> Bool {
        segmentEndMs > startMs && segmentStartMs < endMs
    }

    static func full(durationMs: Int) -> TimelineVisibleRange {
        TimelineVisibleRange(startMs: 0, endMs: max(0, durationMs))
    }

    static func visible(
        scrollOffsetX: CGFloat,
        viewportWidth: CGFloat,
        pxPerMs: CGFloat,
        durationMs: Int,
        bufferScreens: CGFloat = 1
    ) -> TimelineVisibleRange? {
        guard viewportWidth.isFinite,
              pxPerMs.isFinite,
              scrollOffsetX.isFinite,
              viewportWidth > 0,
              pxPerMs > 0,
              durationMs > 0 else {
            return nil
        }

        let bufferPx = max(0, viewportWidth * bufferScreens)
        let start = Int(floor(Double((scrollOffsetX - bufferPx) / pxPerMs)))
        let end = Int(ceil(Double((scrollOffsetX + viewportWidth + bufferPx) / pxPerMs)))

        return TimelineVisibleRange(
            startMs: min(max(start, 0), durationMs),
            endMs: min(max(end, 0), durationMs)
        )
    }
}

enum TimelinePerformance {
    static func visibleSegments(
        in segments: [SubtitleSegment],
        range: TimelineVisibleRange
    ) -> ArraySlice<SubtitleSegment> {
        guard !segments.isEmpty, range.endMs > range.startMs else {
            return []
        }

        let startIndex = firstSegmentIndexEnding(after: range.startMs, in: segments)
        var endIndex = startIndex

        while endIndex < segments.endIndex, segments[endIndex].startMs < range.endMs {
            endIndex += 1
        }

        return segments[startIndex..<endIndex]
    }

    static func activeSegmentID(
        at milliseconds: Int,
        in segments: [SubtitleSegment]
    ) -> UUID? {
        guard !segments.isEmpty else {
            return nil
        }

        var lowerBound = 0
        var upperBound = segments.count

        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2
            if segments[middle].startMs <= milliseconds {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        guard lowerBound > 0 else {
            return nil
        }

        let candidate = segments[lowerBound - 1]
        return milliseconds >= candidate.startMs && milliseconds <= candidate.endMs ? candidate.id : nil
    }

    static func downsampleWaveform(
        peaks: [Double],
        durationMs: Int,
        visibleRange: TimelineVisibleRange,
        targetBucketCount: Int
    ) -> [TimelineWaveformBucket] {
        guard !peaks.isEmpty,
              durationMs > 0,
              visibleRange.endMs > visibleRange.startMs,
              targetBucketCount > 0 else {
            return []
        }

        let clampedRange = TimelineVisibleRange(
            startMs: min(max(visibleRange.startMs, 0), durationMs),
            endMs: min(max(visibleRange.endMs, 0), durationMs)
        )
        guard clampedRange.endMs > clampedRange.startMs else {
            return []
        }

        let peakDurationMs = Double(durationMs) / Double(peaks.count)
        let firstPeakIndex = max(0, Int(floor(Double(clampedRange.startMs) / peakDurationMs)))
        let lastExclusivePeakIndex = min(
            peaks.count,
            max(firstPeakIndex + 1, Int(ceil(Double(clampedRange.endMs) / peakDurationMs)))
        )
        let visiblePeakCount = lastExclusivePeakIndex - firstPeakIndex
        guard visiblePeakCount > 0 else {
            return []
        }

        let bucketCount = min(targetBucketCount, visiblePeakCount)
        return (0..<bucketCount).compactMap { bucketIndex in
            let sourceStart = firstPeakIndex + Int(floor(Double(bucketIndex) * Double(visiblePeakCount) / Double(bucketCount)))
            let sourceEnd = firstPeakIndex + Int(ceil(Double(bucketIndex + 1) * Double(visiblePeakCount) / Double(bucketCount)))
            let boundedEnd = min(max(sourceEnd, sourceStart + 1), lastExclusivePeakIndex)

            guard sourceStart < boundedEnd else {
                return nil
            }

            let amplitude = peaks[sourceStart..<boundedEnd].reduce(0) { currentMax, peak in
                max(currentMax, min(1, max(0, peak)))
            }
            let bucketStartMs = Int((Double(sourceStart) * peakDurationMs).rounded())
            let bucketEndMs = Int((Double(boundedEnd) * peakDurationMs).rounded())

            return TimelineWaveformBucket(
                startMs: bucketStartMs,
                endMs: max(bucketStartMs + 1, bucketEndMs),
                amplitude: amplitude
            )
        }
    }

    private static func firstSegmentIndexEnding(
        after milliseconds: Int,
        in segments: [SubtitleSegment]
    ) -> Int {
        var lowerBound = segments.startIndex
        var upperBound = segments.endIndex

        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2
            if segments[middle].endMs <= milliseconds {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        return lowerBound
    }
}

struct TimelineWaveformBucket: Equatable {
    let startMs: Int
    let endMs: Int
    let amplitude: Double
}
