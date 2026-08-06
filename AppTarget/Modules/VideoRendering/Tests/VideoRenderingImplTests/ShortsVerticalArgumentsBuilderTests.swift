import Foundation
import Subtitles
import Testing
import VideoRendering
@testable import VideoRenderingImpl

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
                    VideoCropKeyframe(id: UUID(), timeMs: 1_000, offsetX: 0.2),
                    VideoCropKeyframe(id: UUID(), timeMs: 2_500, offsetX: 0.8)
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
