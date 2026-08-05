import Foundation
import Subtitles
import Testing
import VideoRendering
@testable import VideoRenderingImpl

struct ShortsVerticalASSTests {
    private let service = VerticalShortsScriptTestAdapter()

    @Test
    func testVerticalScriptUsesVerticalPlayResolution() {
        let output = service.generateVerticalShortsASS(
            segments: [makeCue(startMs: 0, endMs: 2_000, text: "Hi")],
            style: makeDefaultVerticalSubtitleStyle(),
            platform: .youtubeShorts,
            hookText: "",
            hookFontSize: 72,
            shortDurationMs: 10_000
        )

        #expect(output.contains("PlayResX: 1080"))
        #expect(output.contains("PlayResY: 1920"))
    }

    @Test
    func testSubtitleBlockIsClampedIntoBottomSafeArea() throws {
        var style = makeDefaultVerticalSubtitleStyle()
        style.backgroundEnabled = false
        style.subtitlePositionY = 0.99

        let output = service.generateVerticalShortsASS(
            segments: [makeCue(startMs: 0, endMs: 2_000, text: "Low subtitle")],
            style: style,
            platform: .instagramReels,
            hookText: "",
            hookFontSize: 72,
            shortDurationMs: 10_000
        )

        let position = try #require(dialoguePosition(in: output, layer: 1))
        // Reels bottom inset is 20% of 1920 (=384) plus a 24px margin: the
        // block center must sit above 1536 - 24.
        #expect(position.y < 1_512)
        #expect(position.x == 540)
    }

    @Test
    func testHookRendersOnTopLayerInsideTopSafeArea() throws {
        let output = service.generateVerticalShortsASS(
            segments: [],
            style: makeDefaultVerticalSubtitleStyle(),
            platform: .youtubeShorts,
            hookText: "ЧТО СЛУЧИЛОСЬ",
            hookFontSize: 72,
            shortDurationMs: 45_000
        )

        #expect(output.contains("Style: HookText,"))
        #expect(output.contains("ЧТО СЛУЧИЛОСЬ"))

        let position = try #require(dialoguePosition(in: output, layer: 2))
        // Below the YouTube top UI zone (10% of 1920 = 192 plus margin)…
        #expect(position.y > 192)
        // …but still in the upper third of the frame.
        #expect(position.y < 640)
        #expect(output.contains("Dialogue: 2,0:00:00.00,0:00:45.00,HookText"))
    }

    @Test
    func testHookASSPositionMatchesSharedPreviewLayout() throws {
        let style = makeDefaultVerticalSubtitleStyle()
        let layout = try #require(BurnedSubtitleLayoutHelper.makeVerticalHookLayout(
            text: "A TWO LINE HOOK THAT WRAPS ACROSS THE FRAME",
            style: style,
            hookFontSize: 72,
            configuration: VerticalCaptionTestPlatform.instagramReels.configuration
        ))
        let output = service.generateVerticalShortsASS(
            segments: [],
            style: style,
            platform: .instagramReels,
            hookText: "A TWO LINE HOOK THAT WRAPS ACROSS THE FRAME",
            hookFontSize: 72,
            shortDurationMs: 10_000
        )

        let position = try #require(dialoguePosition(in: output, layer: 2))
        #expect(position.x == Int(layout.textPosition.x.rounded()))
        #expect(position.y == Int(layout.textPosition.y.rounded()))
        #expect(output.contains(layout.wrappedText.replacingOccurrences(of: "\n", with: "\\N")))
    }

    @Test
    func testEmptyHookProducesNoHookEvent() {
        let output = service.generateVerticalShortsASS(
            segments: [makeCue(startMs: 0, endMs: 2_000, text: "Hi")],
            style: makeDefaultVerticalSubtitleStyle(),
            platform: .tiktok,
            hookText: "   ",
            hookFontSize: 72,
            shortDurationMs: 10_000
        )

        #expect(!output.contains("Dialogue: 2,"))
    }

    @Test
    func testNoSegmentsKeepsHookButProducesNoSubtitleEvents() {
        let output = service.generateVerticalShortsASS(
            segments: [],
            style: makeDefaultVerticalSubtitleStyle(),
            platform: .youtubeShorts,
            hookText: "Hook only",
            hookFontSize: 72,
            shortDurationMs: 10_000
        )

        #expect(!output.contains("Dialogue: 0,"))
        #expect(!output.contains("Dialogue: 1,"))
        #expect(output.contains("Dialogue: 2,"))
    }

    @Test
    func testVerticalASSUsesProvidedShortsAppearanceSettings() throws {
        var appearance = makeDefaultVerticalSubtitleStyle()
        appearance.fontName = "Avenir Next"
        appearance.fontSize = 82
        appearance.textColorRed = 0.2
        appearance.textColorGreen = 0.4
        appearance.textColorBlue = 0.8
        appearance.backgroundEnabled = true
        appearance.backgroundColorRed = 0.9
        appearance.backgroundColorGreen = 0.1
        appearance.backgroundColorBlue = 0.3
        appearance.backgroundOpacity = 0.75
        appearance.borderEnabled = true
        appearance.borderWidth = 5
        appearance.subtitlePositionX = 0.14
        appearance.subtitlePositionY = 0.9
        let cue = makeCue(
            startMs: 0,
            endMs: 2_000,
            text: "A long Shorts caption that wraps with the exact same geometry in preview and export"
        )
        let layout = try #require(
            BurnedSubtitleLayoutHelper.makeVerticalCaptionLayout(
                for: cue,
                settings: appearance,
                configuration: VerticalCaptionTestPlatform.youtubeShorts.configuration
            )
        )

        let output = service.generateVerticalShortsASS(
            segments: [cue],
            style: appearance,
            platform: .youtubeShorts,
            hookText: "",
            hookFontSize: 72,
            shortDurationMs: 10_000
        )

        #expect(output.contains("Style: SubtitleText,Avenir Next,82,"))
        #expect(output.contains("Style: SubtitleBackground,Arial,1,"))
        #expect(output.contains(",5,0,7,0,0,0,1"))

        let position = try #require(dialoguePosition(in: output, layer: 1))
        #expect(position.x == Int(layout.textPosition.x.rounded()))
        #expect(position.y == Int(layout.textPosition.y.rounded()))
        #expect(output.contains(layout.wrappedText.replacingOccurrences(of: "\n", with: "\\N")))
    }

    private func makeCue(startMs: Int, endMs: Int, text: String) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: startMs,
            endMs: endMs,
            originalText: text,
            translatedText: ""
        )
    }

    private func dialoguePosition(in output: String, layer: Int) -> (x: Int, y: Int)? {
        let pattern = #"Dialogue: \#(layer),[^\n]*\\pos\((\d+),(\d+)\)"#
        guard let match = output.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let line = String(output[match])
        let numbers = line.components(separatedBy: "\\pos(").last?
            .components(separatedBy: ")").first?
            .components(separatedBy: ",")
        guard let numbers, numbers.count == 2,
              let x = Int(numbers[0]), let y = Int(numbers[1]) else {
            return nil
        }

        return (x, y)
    }
}
