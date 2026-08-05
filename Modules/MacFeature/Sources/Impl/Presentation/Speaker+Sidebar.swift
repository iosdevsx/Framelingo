import DesignSystem
import SpeakerAnalysis
import SwiftUI

extension Speaker {
    var sidebarColor: Color {
        Color(hex: colorHex) ?? .gray
    }
}
