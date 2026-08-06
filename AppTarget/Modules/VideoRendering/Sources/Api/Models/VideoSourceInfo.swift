import CoreGraphics

public struct VideoSourceInfo: Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var nominalFrameRate: Double

    public var displaySize: CGSize {
        CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    public init(width: Int, height: Int, nominalFrameRate: Double) {
        self.width = width
        self.height = height
        self.nominalFrameRate = nominalFrameRate
    }
}
