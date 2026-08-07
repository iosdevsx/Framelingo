import SwiftUI

public struct DesignSystemPalette {
    public var controlBackground: Color
    public var separator: Color
    public var windowBackground: Color

    public init(
        controlBackground: Color,
        separator: Color,
        windowBackground: Color
    ) {
        self.controlBackground = controlBackground
        self.separator = separator
        self.windowBackground = windowBackground
    }

    public static let fallback = DesignSystemPalette(
        controlBackground: Color.secondary.opacity(0.08),
        separator: Color.primary.opacity(0.12),
        windowBackground: Color.clear
    )
}
