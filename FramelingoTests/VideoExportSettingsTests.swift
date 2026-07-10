import Foundation
import Testing
@testable import Framelingo

struct VideoExportSettingsTests {
    @Test
    func testLegacyJSONDefaultsBorderAndCornerAppearance() throws {
        let legacyJSON = """
        {
          "fontName": "Arial",
          "fontSize": 32,
          "backgroundEnabled": true,
          "backgroundOpacity": 0.55
        }
        """

        let decoded = try JSONDecoder().decode(
            VideoExportSettings.self,
            from: Data(legacyJSON.utf8)
        )

        #expect(decoded.borderEnabled)
        #expect(decoded.borderColorRed == 1)
        #expect(decoded.borderColorGreen == 1)
        #expect(decoded.borderColorBlue == 1)
        #expect(decoded.borderOpacity == 0.35)
        #expect(decoded.borderWidth == 1)
        #expect(decoded.backgroundCornerRadius == 8)
    }
}
