import Foundation
import Testing
@testable import Framelingo

struct ShortsVerticalArgumentsBuilderTests {
    @Test
    func testBlurPadWithoutClipsBuildsSplitOverlayGraph() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: nil,
            subtitlesPath: "/tmp/subtitles.ass",
            includeAudio: true,
            verticalReframe: VerticalReframePlan(
                mode: .blurPad,
                cropOffsetX: 0.5,
                sourceWidth: 1_920,
                sourceHeight: 1_080
            )
        )

        #expect(arguments.first == "-filter_complex")
        let graph = arguments[1]
        #expect(graph.hasPrefix("[0:v]split[shortmain][shortbgsrc]"))
        #expect(graph.contains("scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur"))
        #expect(graph.contains("scale=1080:1920:force_original_aspect_ratio=decrease:force_divisible_by=2"))
        #expect(graph.contains("overlay=(W-w)/2:(H-h)/2,ass=/tmp/subtitles.ass[vout]"))
        #expect(arguments.suffix(4) == ["-map", "[vout]", "-map", "0:a?"])
    }

    @Test
    func testCropOffsetIsClampedIntoUnitRange() {
        func graph(offset: Double) -> String {
            FFmpegExportArgumentsBuilder.filterArguments(
                clips: nil,
                subtitlesPath: "/tmp/s.ass",
                includeAudio: false,
                verticalReframe: VerticalReframePlan(
                    mode: .crop,
                    cropOffsetX: offset,
                    sourceWidth: 1_920,
                    sourceHeight: 1_080
                )
            )[1]
        }

        #expect(graph(offset: 1.7).contains("x='(iw-out_w)*1.0000'"))
        #expect(graph(offset: -0.4).contains("x='(iw-out_w)*0.0000'"))
        #expect(graph(offset: 0.8).contains("x='(iw-out_w)*0.8000'"))
        #expect(graph(offset: 0.8).contains("crop=w='min(iw,ih*1080/1920)':h='min(ih,iw*1920/1080)'"))
    }

    @Test
    func testCropPointsBuildDiscreteTimeExpression() {
        let graph = FFmpegExportArgumentsBuilder.filterArguments(
            clips: nil,
            subtitlesPath: "/tmp/s.ass",
            includeAudio: false,
            verticalReframe: VerticalReframePlan(
                mode: .crop,
                cropOffsetX: 0.5,
                cropKeyframes: [
                    ShortCropKeyframe(timeMs: 1_000, offsetX: 0.2),
                    ShortCropKeyframe(timeMs: 2_500, offsetX: 0.8)
                ],
                sourceWidth: 1_920,
                sourceHeight: 1_080
            )
        )[1]

        #expect(graph.contains(
            "x='(iw-out_w)*(if(gte(t,2.500),0.8000,if(gte(t,1.000),0.2000,0.5000)))'"
        ))
    }

    @Test
    func testVerticalSourcePassesThroughAsPlainScale() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: nil,
            subtitlesPath: "/tmp/s.ass",
            includeAudio: true,
            verticalReframe: VerticalReframePlan(
                mode: .blurPad,
                cropOffsetX: 0.5,
                sourceWidth: 1_080,
                sourceHeight: 1_920
            )
        )

        let graph = arguments[1]
        #expect(graph == "[0:v]scale=1080:1920,ass=/tmp/s.ass[vout]")
        #expect(!graph.contains("split"))
        #expect(!graph.contains("crop"))
    }

    @Test
    func testClipsComposeWithVerticalReframeAfterConcat() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: [
                ExportClipRange(sourceStartMs: 1_000, sourceEndMs: 2_000),
                ExportClipRange(sourceStartMs: 5_000, sourceEndMs: 6_500)
            ],
            subtitlesPath: "/tmp/s.ass",
            includeAudio: true,
            verticalReframe: VerticalReframePlan(
                mode: .blurPad,
                cropOffsetX: 0.5,
                sourceWidth: 1_920,
                sourceHeight: 1_080
            )
        )

        let graph = arguments[1]
        #expect(graph.contains("[0:v]trim=start=1.000:end=2.000"))
        #expect(graph.contains("concat=n=2:v=1:a=1[vcat][acat]"))
        #expect(graph.contains("[vcat]split[shortmain][shortbgsrc]"))
        #expect(arguments.suffix(4) == ["-map", "[vout]", "-map", "[acat]"])
    }

    @Test
    func testTargetFPSComposesBeforeReframe() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: nil,
            subtitlesPath: "/tmp/s.ass",
            includeAudio: false,
            targetFPS: 30,
            verticalReframe: VerticalReframePlan(
                mode: .crop,
                cropOffsetX: 0.5,
                sourceWidth: 1_920,
                sourceHeight: 1_080
            )
        )

        #expect(arguments[1].hasPrefix("[0:v]fps=30,crop="))
    }

    @Test
    func testNilReframeKeepsLegacyArguments() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: nil,
            subtitlesPath: "/tmp/s.ass",
            includeAudio: true
        )

        #expect(arguments == ["-vf", "ass=/tmp/s.ass"])
    }
}

struct ShortsVerticalASSTests {
    private let service = ASSSubtitleExportService()

    @Test
    func testVerticalScriptUsesVerticalPlayResolution() {
        let output = service.generateVerticalShortsASS(
            segments: [makeCue(startMs: 0, endMs: 2_000, text: "Hi")],
            style: ShortsExportSettings.defaultSubtitleStyle,
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
        var style = ShortsExportSettings.defaultSubtitleStyle
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
            style: ShortsExportSettings.defaultSubtitleStyle,
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
        let style = ShortsExportSettings.defaultSubtitleStyle
        let layout = try #require(BurnedSubtitleLayoutHelper.makeVerticalHookLayout(
            text: "A TWO LINE HOOK THAT WRAPS ACROSS THE FRAME",
            style: style,
            hookFontSize: 72,
            platform: .instagramReels
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
            style: ShortsExportSettings.defaultSubtitleStyle,
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
            style: ShortsExportSettings.defaultSubtitleStyle,
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
        var appearance = ShortsExportSettings.defaultSubtitleStyle
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
                platform: .youtubeShorts
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
