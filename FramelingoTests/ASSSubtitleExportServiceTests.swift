import Testing
import Foundation
@testable import Framelingo

struct ASSSubtitleExportServiceTests {
    @Test
    func testTranslatedFallbackToOriginal() throws {
        let segment = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 83_450,
            endMs: 85_000,
            originalText: "Original text",
            translatedText: ""
        )

        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: VideoExportSettings()
        )

        #expect(output.contains("0:01:23.45"))
        #expect(output.contains("Original text"))
    }

    @Test
    func testTranslatedModeSkipsEmptyText() throws {
        let segment = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 1_000,
            endMs: 2_000,
            originalText: "Original text",
            translatedText: ""
        )

        var settings = VideoExportSettings()
        settings.subtitleTextMode = .translated

        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: settings
        )

        #expect(!output.contains("Dialogue:"))
    }

    @Test
    func testEscapesMultilineText() throws {
        let segment = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 0,
            endMs: 1_000,
            originalText: "Line {one}\nLine two",
            translatedText: ""
        )

        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: VideoExportSettings()
        )

        #expect(output.contains("Line \\{one\\}\\NLine two"))
    }

    @Test
    func testBackgroundOpacityAppliesToVectorFillColor() throws {
        let segment = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 0,
            endMs: 1_000,
            originalText: "Visible background",
            translatedText: ""
        )

        var settings = VideoExportSettings()
        settings.backgroundEnabled = true
        settings.backgroundColorRed = 0.2
        settings.backgroundColorGreen = 0.4
        settings.backgroundColorBlue = 0.6
        settings.backgroundOpacity = 0.25

        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: settings
        )

        #expect(output.contains("Style: SubtitleBackground,Arial,1,&HBF996633"))
    }

    @Test
    func testRoundedBackgroundUsesLowerLayerBezierDrawing() throws {
        var settings = VideoExportSettings()
        settings.backgroundCornerRadius = 8

        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: settings
        )
        let backgroundEvent = try #require(dialogueLine(layer: 0, in: output))

        #expect(backgroundEvent.contains("SubtitleBackground"))
        #expect(backgroundEvent.contains("\\p1}m "))
        #expect(backgroundEvent.contains(" b "))
    }

    @Test
    func testZeroCornerRadiusUsesSquareRectangleDrawing() throws {
        var settings = VideoExportSettings()
        settings.backgroundCornerRadius = 0

        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: settings
        )
        let backgroundEvent = try #require(dialogueLine(layer: 0, in: output))

        #expect(backgroundEvent.contains("\\p1}m 0 0 l "))
        #expect(!backgroundEvent.contains(" b "))
    }

    @Test
    func testTextEventUsesHigherLayerThanBackground() throws {
        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: VideoExportSettings()
        )
        let lines = output.components(separatedBy: "\n")
        let backgroundIndex = try #require(
            lines.firstIndex { $0.hasPrefix("Dialogue: 0,") }
        )
        let textIndex = try #require(
            lines.firstIndex { $0.hasPrefix("Dialogue: 1,") }
        )

        #expect(backgroundIndex < textIndex)
        #expect(lines[textIndex].contains("SubtitleText"))
    }

    @Test
    func testDisabledBackgroundEmitsOnlyTextDialogue() throws {
        var settings = VideoExportSettings()
        settings.backgroundEnabled = false

        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: settings
        )

        #expect(dialogueLine(layer: 0, in: output) == nil)
        #expect(dialogueLine(layer: 1, in: output) != nil)
        #expect(!output.contains("\\p1}"))
    }

    @Test
    func testEnabledBorderUsesConfiguredWidth() throws {
        var settings = VideoExportSettings()
        settings.borderEnabled = true
        settings.borderWidth = 2.5

        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: settings
        )
        let fields = try #require(styleFields(named: "SubtitleBackground", in: output))

        #expect(fields[15] == "1")
        #expect(fields[16] == "2.5")
    }

    @Test
    func testDisabledBorderUsesZeroOutlineWidth() throws {
        var settings = VideoExportSettings()
        settings.borderEnabled = false
        settings.borderWidth = 6

        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: settings
        )
        let fields = try #require(styleFields(named: "SubtitleBackground", in: output))

        #expect(fields[16] == "0")
    }

    @Test
    func testBorderOpacityIsEncodedInOutlineColor() throws {
        var settings = VideoExportSettings()
        settings.borderEnabled = true
        settings.borderColorRed = 0.1
        settings.borderColorGreen = 0.2
        settings.borderColorBlue = 0.3
        settings.borderOpacity = 0.4

        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: settings
        )
        let fields = try #require(styleFields(named: "SubtitleBackground", in: output))

        #expect(fields[5] == "&H994D331A")
    }

    @Test
    func testGeneratedStylesNeverUseOpaqueBoxBorderStyle() throws {
        let output = try ASSSubtitleExportService().generateASS(
            segments: [segment],
            settings: VideoExportSettings()
        )
        let textFields = try #require(styleFields(named: "SubtitleText", in: output))
        let backgroundFields = try #require(styleFields(named: "SubtitleBackground", in: output))

        #expect(textFields[15] == "1")
        #expect(backgroundFields[15] == "1")
        #expect(!output.contains("Style: Default"))
    }

    private var segment: SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 0,
            endMs: 1_000,
            originalText: "Visible subtitle",
            translatedText: ""
        )
    }

    private func dialogueLine(layer: Int, in output: String) -> String? {
        output.components(separatedBy: "\n")
            .first { $0.hasPrefix("Dialogue: \(layer),") }
    }

    private func styleFields(named name: String, in output: String) -> [Substring]? {
        output.components(separatedBy: "\n")
            .first { $0.hasPrefix("Style: \(name),") }?
            .split(separator: ",", omittingEmptySubsequences: false)
    }
}
