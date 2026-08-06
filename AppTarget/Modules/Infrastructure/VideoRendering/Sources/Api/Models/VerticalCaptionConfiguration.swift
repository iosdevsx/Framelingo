import CoreGraphics

public struct VerticalCaptionConfiguration: Equatable, Sendable {
    public var canvasSize: CGSize
    public var topSafeAreaFraction: Double
    public var bottomSafeAreaFraction: Double
    public var safeAreaMargin: CGFloat

    public init(
        canvasSize: CGSize = CGSize(width: 1_080, height: 1_920),
        topSafeAreaFraction: Double,
        bottomSafeAreaFraction: Double,
        safeAreaMargin: CGFloat = 24
    ) {
        self.canvasSize = canvasSize
        self.topSafeAreaFraction = topSafeAreaFraction
        self.bottomSafeAreaFraction = bottomSafeAreaFraction
        self.safeAreaMargin = safeAreaMargin
    }
}
