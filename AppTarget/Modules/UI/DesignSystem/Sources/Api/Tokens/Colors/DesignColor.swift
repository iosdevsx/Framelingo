import SwiftUI

public enum DesignColor {
    public static func sRGBComponents(
        of color: Color
    ) -> (red: Double, green: Double, blue: Double) {
        let resolved = color.resolve(in: EnvironmentValues())
        return (
            Double(resolved.red),
            Double(resolved.green),
            Double(resolved.blue)
        )
    }
}
