import XCTest
@testable import Framelingo

final class FFmpegExportArgumentsBuilderTests: XCTestCase {
    // MARK: - ExportClipPlanResolver

    func testResolverReturnsNilWithoutEditTimeline() throws {
        let project = makeProject(editTimeline: nil)

        XCTAssertNil(try ExportClipPlanResolver.clips(for: project))
    }

    func testResolverReturnsNilForFullLengthSingleClip() throws {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 10_000,
                    timelineStartMs: 0,
                    timelineEndMs: 10_000
                )
            ],
            totalDurationMs: 10_000
        )

        XCTAssertNil(try ExportClipPlanResolver.clips(for: makeProject(editTimeline: timeline)))
    }

    func testResolverDetectsTailTrimAgainstSourceDuration() throws {
        // Keeping only the first 10s of a 60s video leaves a single clip
        // starting at source 0 — invisible to EditTimeline.hasVirtualCuts.
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 10_000,
                    timelineStartMs: 0,
                    timelineEndMs: 10_000
                )
            ],
            totalDurationMs: 10_000
        )

        let clips = try XCTUnwrap(
            ExportClipPlanResolver.clips(for: makeProject(editTimeline: timeline, mediaDurationMs: 60_000))
        )

        XCTAssertEqual(clips, [ExportClipRange(sourceStartMs: 0, sourceEndMs: 10_000)])
    }

    func testResolverReturnsClipsSortedByTimelineStart() throws {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 5_000,
                    sourceEndMs: 10_000,
                    timelineStartMs: 3_000,
                    timelineEndMs: 8_000
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 3_000,
                    timelineStartMs: 0,
                    timelineEndMs: 3_000
                )
            ],
            totalDurationMs: 8_000
        )

        let clips = try XCTUnwrap(ExportClipPlanResolver.clips(for: makeProject(editTimeline: timeline)))

        XCTAssertEqual(clips, [
            ExportClipRange(sourceStartMs: 0, sourceEndMs: 3_000),
            ExportClipRange(sourceStartMs: 5_000, sourceEndMs: 10_000)
        ])
    }

    func testResolverFiltersDegenerateClips() throws {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 4_000,
                    sourceEndMs: 4_000,
                    timelineStartMs: 0,
                    timelineEndMs: 0
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 6_000,
                    sourceEndMs: 9_000,
                    timelineStartMs: 0,
                    timelineEndMs: 3_000
                )
            ],
            totalDurationMs: 3_000
        )

        let clips = try XCTUnwrap(ExportClipPlanResolver.clips(for: makeProject(editTimeline: timeline)))

        XCTAssertEqual(clips, [ExportClipRange(sourceStartMs: 6_000, sourceEndMs: 9_000)])
    }

    func testResolverThrowsWhenPlanIsEmpty() {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 4_000,
                    sourceEndMs: 4_000,
                    timelineStartMs: 0,
                    timelineEndMs: 0
                )
            ],
            totalDurationMs: 0
        )

        XCTAssertThrowsError(try ExportClipPlanResolver.clips(for: makeProject(editTimeline: timeline))) { error in
            XCTAssertEqual(error as? ExportClipPlanError, .emptyPlan)
        }
    }

    // MARK: - Filter arguments without cuts

    func testFilterArgumentsWithoutClipsMatchesLegacyVFPass() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: nil,
            subtitlesPath: "/tmp/subs dir/subtitles.ass",
            includeAudio: true
        )

        XCTAssertEqual(arguments, ["-vf", "ass=/tmp/subs dir/subtitles.ass"])
    }

    func testAudioCodecArgumentsWithoutClipsIsStreamCopy() {
        let arguments = FFmpegExportArgumentsBuilder.audioCodecArguments(clips: nil, includeAudio: true)

        XCTAssertEqual(arguments, ["-c:a", "copy"])
    }

    // MARK: - Filter arguments with cuts

    func testFilterArgumentsForSingleClip() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: [ExportClipRange(sourceStartMs: 1_500, sourceEndMs: 4_250)],
            subtitlesPath: "/tmp/subtitles.ass",
            includeAudio: true
        )

        XCTAssertEqual(arguments, [
            "-filter_complex",
            "[0:v]trim=start=1.500:end=4.250,setpts=PTS-STARTPTS[v0];"
                + "[0:a]atrim=start=1.500:end=4.250,asetpts=PTS-STARTPTS[a0];"
                + "[v0][a0]concat=n=1:v=1:a=1[vcat][acat];"
                + "[vcat]ass=/tmp/subtitles.ass[vout]",
            "-map", "[vout]",
            "-map", "[acat]"
        ])
    }

    func testFilterArgumentsForThreeClips() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: [
                ExportClipRange(sourceStartMs: 0, sourceEndMs: 10_000),
                ExportClipRange(sourceStartMs: 20_000, sourceEndMs: 30_000),
                ExportClipRange(sourceStartMs: 45_000, sourceEndMs: 60_000)
            ],
            subtitlesPath: "/tmp/subtitles.ass",
            includeAudio: true
        )

        XCTAssertEqual(arguments.count, 6)
        XCTAssertEqual(arguments[0], "-filter_complex")

        let graph = arguments[1]
        XCTAssertTrue(graph.contains("[0:v]trim=start=0.000:end=10.000,setpts=PTS-STARTPTS[v0]"))
        XCTAssertTrue(graph.contains("[0:a]atrim=start=20.000:end=30.000,asetpts=PTS-STARTPTS[a1]"))
        XCTAssertTrue(graph.contains("[0:v]trim=start=45.000:end=60.000,setpts=PTS-STARTPTS[v2]"))
        XCTAssertTrue(graph.contains("[v0][a0][v1][a1][v2][a2]concat=n=3:v=1:a=1[vcat][acat]"))
        XCTAssertTrue(graph.hasSuffix("[vcat]ass=/tmp/subtitles.ass[vout]"))
    }

    func testFilterArgumentsVideoOnlyVariantSkipsAudio() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: [
                ExportClipRange(sourceStartMs: 0, sourceEndMs: 1_000),
                ExportClipRange(sourceStartMs: 2_000, sourceEndMs: 3_000)
            ],
            subtitlesPath: "/tmp/subtitles.ass",
            includeAudio: false
        )

        XCTAssertEqual(arguments, [
            "-filter_complex",
            "[0:v]trim=start=0.000:end=1.000,setpts=PTS-STARTPTS[v0];"
                + "[0:v]trim=start=2.000:end=3.000,setpts=PTS-STARTPTS[v1];"
                + "[v0][v1]concat=n=2:v=1:a=0[vcat];"
                + "[vcat]ass=/tmp/subtitles.ass[vout]",
            "-map", "[vout]"
        ])
    }

    func testAudioCodecArgumentsWithClips() {
        XCTAssertEqual(
            FFmpegExportArgumentsBuilder.audioCodecArguments(
                clips: [ExportClipRange(sourceStartMs: 0, sourceEndMs: 1_000)],
                includeAudio: true
            ),
            ["-c:a", "aac", "-b:a", "192k"]
        )

        XCTAssertEqual(
            FFmpegExportArgumentsBuilder.audioCodecArguments(
                clips: [ExportClipRange(sourceStartMs: 0, sourceEndMs: 1_000)],
                includeAudio: false
            ),
            []
        )
    }

    // MARK: - Formatting helpers

    func testSecondsFormattingIsMillisecondPreciseAndClamped() {
        XCTAssertEqual(FFmpegExportArgumentsBuilder.seconds(fromMs: 0), "0.000")
        XCTAssertEqual(FFmpegExportArgumentsBuilder.seconds(fromMs: 7), "0.007")
        XCTAssertEqual(FFmpegExportArgumentsBuilder.seconds(fromMs: 61_234), "61.234")
        XCTAssertEqual(FFmpegExportArgumentsBuilder.seconds(fromMs: -500), "0.000")
    }

    func testSubtitlePathEscapingMatchesLegacyBehavior() {
        XCTAssertEqual(
            FFmpegExportArgumentsBuilder.escapedSubtitleFilterPath("/tmp/it's:a\\path.ass"),
            "/tmp/it\\'s\\:a\\\\path.ass"
        )
    }

    func testEscapedPathIsUsedInsideFilterGraph() {
        let arguments = FFmpegExportArgumentsBuilder.filterArguments(
            clips: [ExportClipRange(sourceStartMs: 0, sourceEndMs: 1_000)],
            subtitlesPath: "/tmp/dir:with colon/subtitles.ass",
            includeAudio: true
        )

        XCTAssertTrue(arguments[1].contains("ass=/tmp/dir\\:with colon/subtitles.ass"))
    }

    func testMissingAudioStreamDetection() {
        XCTAssertTrue(
            FFmpegExportArgumentsBuilder.indicatesMissingAudioStream(
                "Stream specifier ':a' in filtergraph description matches no streams."
            )
        )
        XCTAssertFalse(FFmpegExportArgumentsBuilder.indicatesMissingAudioStream("Unknown encoder 'libx264'"))
    }

    // MARK: - Fixtures

    private func makeProject(editTimeline: EditTimeline?, mediaDurationMs: Int = 10_000) -> Project {
        Project(
            id: UUID(),
            name: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            mediaFile: MediaFile(
                id: UUID(),
                originalURL: URL(fileURLWithPath: "/tmp/video.mp4"),
                fileName: "video.mp4",
                fileExtension: "mp4",
                sizeBytes: 1,
                durationMs: mediaDurationMs
            ),
            sourceLanguage: "en",
            targetLanguage: "ru",
            subtitles: [],
            status: .ready,
            editTimeline: editTimeline
        )
    }
}
