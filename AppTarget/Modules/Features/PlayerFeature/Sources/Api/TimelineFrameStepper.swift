public enum TimelineFrameStepper {
    public static func steppedTime(
        from currentTimeMs: Int,
        direction: Int,
        frameRate: Double,
        durationMs: Int
    ) -> Int {
        let resolvedFrameRate = frameRate.isFinite && frameRate > 0 ? frameRate : 30
        let clampedCurrentTimeMs = max(0, currentTimeMs)
        let framePosition = Double(clampedCurrentTimeMs) * resolvedFrameRate / 1_000
        let nearestFrame = framePosition.rounded()
        let nearestFrameTimeMs = Int((nearestFrame * 1_000 / resolvedFrameRate).rounded())

        let targetFrame: Double
        if nearestFrameTimeMs == clampedCurrentTimeMs {
            targetFrame = nearestFrame + (direction < 0 ? -1 : 1)
        } else if direction < 0 {
            targetFrame = framePosition.rounded(.down)
        } else {
            targetFrame = framePosition.rounded(.up)
        }

        let targetTimeMs = Int((targetFrame * 1_000 / resolvedFrameRate).rounded())
        return min(max(0, targetTimeMs), max(0, durationMs))
    }
}
