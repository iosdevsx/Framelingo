public struct TimelineWaveformBucket: Equatable {
    public let startMs: Int
    public let endMs: Int
    public let amplitude: Double

    public init(startMs: Int, endMs: Int, amplitude: Double) {
        self.startMs = startMs
        self.endMs = endMs
        self.amplitude = amplitude
    }
}
