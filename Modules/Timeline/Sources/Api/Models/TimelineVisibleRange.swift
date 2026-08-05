import CoreGraphics
import Foundation

public struct TimelineVisibleRange: Equatable {
    public let startMs: Int
    public let endMs: Int

    public init(startMs: Int, endMs: Int) {
        self.startMs = startMs
        self.endMs = endMs
    }

    public var durationMs: Int {
        max(0, endMs - startMs)
    }

    public func contains(_ milliseconds: Int) -> Bool {
        milliseconds >= startMs && milliseconds <= endMs
    }

    public func intersects(startMs segmentStartMs: Int, endMs segmentEndMs: Int) -> Bool {
        segmentEndMs > startMs && segmentStartMs < endMs
    }

    public static func full(durationMs: Int) -> TimelineVisibleRange {
        TimelineVisibleRange(startMs: 0, endMs: max(0, durationMs))
    }

    public static func visible(
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
