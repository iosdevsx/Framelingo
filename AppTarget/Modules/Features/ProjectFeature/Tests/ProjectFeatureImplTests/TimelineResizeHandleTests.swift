@testable import ProjectFeatureImpl
import Testing

@MainActor
struct TimelineResizeHandleTests {
    @Test
    func shortsConfigurationUsesItsCompactBounds() {
        let handle = TimelineResizeHandleNSView()
        handle.totalHeight = 1_000
        handle.minimumHeight = 110
        handle.maximumHeight = 240
        handle.reservedHeight = 420

        #expect(handle.clampedHeight(80) == 110)
        #expect(handle.clampedHeight(180) == 180)
        #expect(handle.clampedHeight(500) == 240)
    }

    @Test
    func compactTimelineStillReservesThePreviewInAShortWindow() {
        let handle = TimelineResizeHandleNSView()
        handle.totalHeight = 520
        handle.minimumHeight = 110
        handle.maximumHeight = 240
        handle.reservedHeight = 420

        #expect(handle.clampedHeight(200) == 110)
    }
}
