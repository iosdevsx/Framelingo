/// Vertical (9:16) reframing parameters for shorts export. When source
/// dimensions are known and already match the output aspect, the graph
/// degenerates to a plain scale (no padding, no cropping).
public struct VerticalReframePlan: Equatable, Sendable {
    public var mode: VideoReframeMode
    /// Horizontal position of the crop window, 0…1 (0.5 = centered). Ignored
    /// for blur-pad.
    public var cropOffsetX: Double
    /// Discrete crop changes in short-local time. The last point at or before
    /// the current frame wins, producing hard cuts rather than animation.
    public var cropKeyframes: [VideoCropKeyframe] = []
    public var outputWidth: Int = 1_080
    public var outputHeight: Int = 1_920
    public var sourceWidth: Int?
    public var sourceHeight: Int?

    public var sourceMatchesOutputAspect: Bool {
        guard let sourceWidth, let sourceHeight, sourceWidth > 0, sourceHeight > 0 else {
            return false
        }

        let sourceAspect = Double(sourceWidth) / Double(sourceHeight)
        let outputAspect = Double(outputWidth) / Double(outputHeight)
        return abs(sourceAspect - outputAspect) < 0.01
    }

    public init(
        mode: VideoReframeMode,
        cropOffsetX: Double,
        cropKeyframes: [VideoCropKeyframe] = [],
        outputWidth: Int = 1_080,
        outputHeight: Int = 1_920,
        sourceWidth: Int? = nil,
        sourceHeight: Int? = nil
    ) {
        self.mode = mode
        self.cropOffsetX = cropOffsetX
        self.cropKeyframes = cropKeyframes
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
    }
}
