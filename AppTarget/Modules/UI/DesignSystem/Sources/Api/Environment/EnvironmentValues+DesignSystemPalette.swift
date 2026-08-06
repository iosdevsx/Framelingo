import SwiftUI

public extension EnvironmentValues {
    var designSystemPalette: DesignSystemPalette {
        get { self[DesignSystemPaletteKey.self] }
        set { self[DesignSystemPaletteKey.self] = newValue }
    }
}
