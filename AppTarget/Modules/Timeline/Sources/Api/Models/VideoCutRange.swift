public struct VideoCutRange: Equatable {
    public var startMs: Int
    public var endMs: Int

    public init(startMs: Int, endMs: Int) {
        self.startMs = startMs
        self.endMs = endMs
    }

    public var normalized: VideoCutRange {
        VideoCutRange(startMs: min(startMs, endMs), endMs: max(startMs, endMs))
    }

    public var durationMs: Int {
        max(0, endMs - startMs)
    }
}
