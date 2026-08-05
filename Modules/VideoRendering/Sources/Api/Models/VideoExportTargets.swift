public struct VideoExportTargets: Equatable, Sendable {
    public var size: VideoOutputSize?
    public var framesPerSecond: Int?

    public init(size: VideoOutputSize?, framesPerSecond: Int?) {
        self.size = size
        self.framesPerSecond = framesPerSecond
    }
}
