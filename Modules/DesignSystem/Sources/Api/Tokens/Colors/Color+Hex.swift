import SwiftUI

public extension Color {
    init?(hex: String) {
        var normalizedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedHex.hasPrefix("#") {
            normalizedHex.removeFirst()
        }

        guard normalizedHex.count == 6,
              let value = UInt64(normalizedHex, radix: 16) else {
            return nil
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
