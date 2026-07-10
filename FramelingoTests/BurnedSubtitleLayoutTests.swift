import Foundation
import Testing
@testable import Framelingo

struct BurnedSubtitleLayoutTests {
    @Test
    func testSelectsTranslatedTextWithOriginalFallback() throws {
        var settings = VideoExportSettings()
        settings.subtitleTextMode = .translatedFallbackToOriginal
        var segment = makeSegment(original: "Original", translated: "   ")

        let fallbackLayout = try #require(
            BurnedSubtitleLayoutHelper.makeLayout(for: segment, settings: settings)
        )
        #expect(fallbackLayout.selectedText == "Original")

        segment.translatedText = "Translated"
        let translatedLayout = try #require(
            BurnedSubtitleLayoutHelper.makeLayout(for: segment, settings: settings)
        )
        #expect(translatedLayout.selectedText == "Translated")
    }

    @Test
    func testWrappingRespectsMaximumLineCount() throws {
        var settings = VideoExportSettings()
        settings.fontSize = 28
        settings.maxLines = 2
        let segment = makeSegment(
            original: "One two three four five six seven eight nine ten",
            translated: ""
        )

        let layout = try #require(
            BurnedSubtitleLayoutHelper.makeLayout(
                for: segment,
                settings: settings,
                scriptSize: CGSize(width: 360, height: 240)
            )
        )

        #expect(layout.wrappedLines.count == 2)
        #expect(layout.wrappedText.contains("\n"))
        #expect(layout.wrappedText.replacingOccurrences(of: "\n", with: " ") == segment.originalText)
    }

    @Test
    func testBoxSizeGrowsWithMeasuredText() throws {
        let segment = makeSegment(original: "Measured subtitle", translated: "")
        var smallSettings = VideoExportSettings()
        smallSettings.fontSize = 18
        var largeSettings = smallSettings
        largeSettings.fontSize = 48

        let smallLayout = try #require(
            BurnedSubtitleLayoutHelper.makeLayout(for: segment, settings: smallSettings)
        )
        let largeLayout = try #require(
            BurnedSubtitleLayoutHelper.makeLayout(for: segment, settings: largeSettings)
        )

        #expect(largeLayout.textSize.width > smallLayout.textSize.width)
        #expect(largeLayout.textSize.height > smallLayout.textSize.height)
        #expect(largeLayout.backgroundRect.width > smallLayout.backgroundRect.width)
        #expect(largeLayout.backgroundRect.height > smallLayout.backgroundRect.height)
    }

    @Test
    func testBackgroundRectClampsToScriptCanvas() throws {
        var settings = VideoExportSettings()
        settings.subtitlePositionX = -0.5
        settings.subtitlePositionY = 1.5
        let scriptSize = CGSize(width: 320, height: 180)

        let layout = try #require(
            BurnedSubtitleLayoutHelper.makeLayout(
                for: makeSegment(original: "Edge subtitle", translated: ""),
                settings: settings,
                scriptSize: scriptSize
            )
        )

        #expect(layout.backgroundRect.minX == 0)
        #expect(layout.backgroundRect.minY >= 0)
        #expect(layout.backgroundRect.maxX <= scriptSize.width)
        #expect(layout.backgroundRect.maxY == scriptSize.height)
        #expect(layout.textPosition.x >= 0 && layout.textPosition.x <= scriptSize.width)
        #expect(layout.textPosition.y >= 0 && layout.textPosition.y <= scriptSize.height)
    }

    private func makeSegment(original: String, translated: String) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 0,
            endMs: 1_000,
            originalText: original,
            translatedText: translated
        )
    }
}
