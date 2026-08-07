import DesignSystem
import SpeakerAnalysis
import SwiftUI

extension Speaker {
    var color: Color { Color(hex: colorHex) ?? Color.gray }
}
