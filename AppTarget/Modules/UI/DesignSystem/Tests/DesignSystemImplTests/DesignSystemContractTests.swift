import DesignSystem
import SwiftUI
import Testing

struct DesignSystemContractTests {
    @Test
    func hexColorAcceptsSixDigitRGBAndRejectsInvalidInput() {
        #expect(Color(hex: "#0A84FF") != nil)
        #expect(Color(hex: "not-a-color") == nil)
    }

    @Test
    func panelAcceptsGenericContentWithoutTypeErasure() {
        let panel = SurfacePanel {
            Text("Reusable content")
        }

        #expect(type(of: panel) == SurfacePanel<Text>.self)
    }
}
