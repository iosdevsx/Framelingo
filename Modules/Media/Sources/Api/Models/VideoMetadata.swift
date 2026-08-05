public struct VideoMetadata: Equatable {
    public var width: Int
    public var height: Int
    public var nominalFrameRate: Double

    public init(width: Int, height: Int, nominalFrameRate: Double) {
        self.width = width
        self.height = height
        self.nominalFrameRate = nominalFrameRate
    }
}
