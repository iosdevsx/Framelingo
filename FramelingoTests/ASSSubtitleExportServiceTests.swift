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
}
