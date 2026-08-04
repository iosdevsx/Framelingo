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

    @Test
    func testVerticalDefaultWrapsWithinEightyPercentAndThreeLines() throws {
        let layout = try #require(
            BurnedSubtitleLayoutHelper.makeVerticalCaptionLayout(
                for: makeSegment(
                    original: "A readable vertical subtitle wraps automatically across the short without using the regular export style",
                    translated: ""
                ),
                settings: ShortsExportSettings.defaultSubtitleStyle,
                platform: .youtubeShorts
            )
        )

        #expect(layout.wrappedLines.count <= 3)
        #expect(layout.backgroundRect.width <= 1_080 * 0.8)
        #expect(layout.backgroundRect.minX >= 0)
        #expect(layout.backgroundRect.maxX <= 1_080)
    }

    @Test
    func testVerticalMultilineTextKeepsConfiguredLineLimit() throws {
        let layout = try #require(
            BurnedSubtitleLayoutHelper.makeVerticalCaptionLayout(
                for: makeSegment(
                    original: "First paragraph\nSecond paragraph with more words\nThird paragraph",
                    translated: ""
                ),
                settings: ShortsExportSettings.defaultSubtitleStyle,
                platform: .youtubeShorts
            )
        )

        #expect(layout.wrappedLines.count == 3)
        #expect(layout.wrappedText.contains("\n"))
    }

    @Test
    func testVerticalLayoutClampsToEveryPlatformSafeArea() throws {
        for platform in ShortsPlatform.allCases {
            var topStyle = ShortsExportSettings.defaultSubtitleStyle
            topStyle.subtitlePositionY = 0
            let topLayout = try #require(
                BurnedSubtitleLayoutHelper.makeVerticalCaptionLayout(
                    for: makeSegment(original: "Top edge", translated: ""),
                    settings: topStyle,
                    platform: platform
                )
            )
            let minimumY = CGFloat(platform.topSafeAreaFraction) * 1_920
                + BurnedSubtitleLayoutHelper.verticalSafeAreaMargin
            #expect(topLayout.backgroundRect.minY >= minimumY)

            var bottomStyle = ShortsExportSettings.defaultSubtitleStyle
            bottomStyle.subtitlePositionY = 1
            let bottomLayout = try #require(
                BurnedSubtitleLayoutHelper.makeVerticalCaptionLayout(
                    for: makeSegment(original: "Bottom edge", translated: ""),
                    settings: bottomStyle,
                    platform: platform
                )
            )
            let maximumY = (1 - CGFloat(platform.bottomSafeAreaFraction)) * 1_920
                - BurnedSubtitleLayoutHelper.verticalSafeAreaMargin
            #expect(bottomLayout.backgroundRect.maxY <= maximumY)
        }
    }

    @Test
    func testVerticalLayoutClampsHorizontallyAndReportsNormalizedCenter() throws {
        for requestedX in [-1.0, 2.0] {
            var style = ShortsExportSettings.defaultSubtitleStyle
            style.subtitlePositionX = requestedX
            let layout = try #require(
                BurnedSubtitleLayoutHelper.makeVerticalCaptionLayout(
                    for: makeSegment(original: "Horizontal edge subtitle", translated: ""),
                    settings: style,
                    platform: .instagramReels
                )
            )
            let normalized = BurnedSubtitleLayoutHelper.normalizedPosition(for: layout)

            #expect(layout.backgroundRect.minX >= 0)
            #expect(layout.backgroundRect.maxX <= 1_080)
            #expect(normalized.x == layout.textPosition.x / 1_080)
            #expect(normalized.y == layout.textPosition.y / 1_920)
            #expect((0...1).contains(normalized.x))
            #expect((0...1).contains(normalized.y))
        }
    }

    @Test
    func testVerticalPreviewFallsBackToOriginalWhenTranslationIsEmpty() throws {
        var style = ShortsExportSettings.defaultSubtitleStyle
        style.subtitleTextMode = .translated
        let segment = makeSegment(
            original: "Shared original caption",
            translated: ""
        )

        #expect(BurnedSubtitleLayoutHelper.makeVerticalCaptionLayout(
            for: segment,
            settings: style,
            platform: .youtubeShorts
        ) == nil)

        let previewLayout = try #require(
            BurnedSubtitleLayoutHelper.makeVerticalPreviewCaptionLayout(
                for: segment,
                settings: style,
                platform: .youtubeShorts
            )
        )
        #expect(previewLayout.selectedText == "Shared original caption")
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
