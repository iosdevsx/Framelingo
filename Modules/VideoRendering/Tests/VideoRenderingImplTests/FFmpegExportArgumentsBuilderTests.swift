import Foundation
import VideoRendering
import XCTest
@testable import VideoRenderingImpl

final class FFmpegExportArgumentsBuilderTests: XCTestCase {
    func testFilterArgumentsWithoutClipsUsesVFPass() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: nil,
            subtitlesPath: "/tmp/subs dir/subtitles.ass",
            includeAudio: true
        )
        XCTAssertEqual(arguments, ["-vf", "ass=/tmp/subs dir/subtitles.ass"])
    }

    func testFPSAndScalePrecedeSubtitleFilter() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: nil,
            subtitlesPath: "/tmp/subtitles.ass",
            includeAudio: true,
            targetSize: VideoOutputSize(width: 1_280, height: 720),
            targetFPS: 30
        )
        XCTAssertEqual(
            arguments,
            ["-vf", "fps=30,scale=1280:720,ass=/tmp/subtitles.ass"]
        )
    }

    func testClipGraphTrimsConcatenatesAndMapsAudio() {
        let clips = [
            ExportClipRange(sourceStartMs: 0, sourceEndMs: 2_000),
            ExportClipRange(sourceStartMs: 5_000, sourceEndMs: 8_500),
        ]
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: clips,
            subtitlesPath: "/tmp/subtitles.ass",
            includeAudio: true
        )
        let graph = arguments[1]

        XCTAssertEqual(arguments[0], "-filter_complex")
        XCTAssertTrue(graph.contains("trim=start=0.000:end=2.000"))
        XCTAssertTrue(graph.contains("trim=start=5.000:end=8.500"))
        XCTAssertTrue(graph.contains("concat=n=2:v=1:a=1[vcat][acat]"))
        XCTAssertTrue(arguments.contains("[acat]"))
    }

    func testVideoOnlyClipGraphSkipsAudio() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: [ExportClipRange(sourceStartMs: 100, sourceEndMs: 900)],
            subtitlesPath: "/tmp/subtitles.ass",
            includeAudio: false
        )
        XCTAssertFalse(arguments[1].contains("[0:a]"))
        XCTAssertFalse(arguments.contains("[acat]"))
    }

    func testVerticalCropUsesGenericReframePlan() {
        let plan = VerticalReframePlan(
            mode: .crop,
            cropOffsetX: 0.25,
            cropKeyframes: [
                VideoCropKeyframe(id: UUID(), timeMs: 2_000, offsetX: 0.75),
            ]
        )
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: nil,
            subtitlesPath: "/tmp/subtitles.ass",
            includeAudio: true,
            verticalReframe: plan
        )

        XCTAssertTrue(arguments[1].contains("if(gte(t,2.000),0.7500,0.2500)"))
        XCTAssertTrue(arguments[1].contains("scale=1080:1920"))
    }

    func testAudioCodecReflectsWhetherClipsExist() {
        XCTAssertEqual(
            FFmpegExportArgumentsBuilder.audioCodecArguments(
                clips: nil,
                includeAudio: true
            ),
            ["-c:a", "copy"]
        )
        XCTAssertEqual(
            FFmpegExportArgumentsBuilder.audioCodecArguments(
                clips: [ExportClipRange(sourceStartMs: 0, sourceEndMs: 1_000)],
                includeAudio: true
            ),
            ["-c:a", "aac", "-b:a", "192k"]
        )
    }

    func testFormattingEscapingAndMissingAudioDetection() {
        XCTAssertEqual(FFmpegExportArgumentsBuilder.seconds(fromMs: 1_234), "1.234")
        XCTAssertEqual(FFmpegExportArgumentsBuilder.seconds(fromMs: -1), "0.000")
        XCTAssertEqual(
            FFmpegExportArgumentsBuilder.escapedSubtitleFilterPath("/tmp/a:b's.ass"),
            "/tmp/a\\:b\\'s.ass"
        )
        XCTAssertTrue(
            FFmpegExportArgumentsBuilder.indicatesMissingAudioStream(
                "filtergraph matches no streams"
            )
        )
    }
}
