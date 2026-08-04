import Foundation
import Testing
@testable import Framelingo

struct ShortsClipPlannerTests {
    @Test
    func testShortWithoutEditTimelineMapsToSingleSourceRange() throws {
        let short = ShortDefinition(title: "One", startMs: 100_000, endMs: 140_000)

        let clips = try ShortsClipPlanner.clips(for: short, editTimeline: nil)

        #expect(clips == [ExportClipRange(sourceStartMs: 100_000, sourceEndMs: 140_000)])
    }

    @Test
    func testShortSpanningCutResolvesToTwoSourceRanges() throws {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 120_000,
                    timelineStartMs: 0,
                    timelineEndMs: 120_000
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 300_000,
                    sourceEndMs: 420_000,
                    timelineStartMs: 120_000,
                    timelineEndMs: 240_000
                )
            ],
            totalDurationMs: 240_000
        )
        let short = ShortDefinition(title: "Cut", startMs: 100_000, endMs: 140_000)

        let clips = try ShortsClipPlanner.clips(for: short, editTimeline: timeline)

        #expect(clips == [
            ExportClipRange(sourceStartMs: 100_000, sourceEndMs: 120_000),
            ExportClipRange(sourceStartMs: 300_000, sourceEndMs: 320_000)
        ])
    }

    @Test
    func testDegenerateShortThrowsEmptyPlan() {
        let short = ShortDefinition(title: "Empty", startMs: 5_000, endMs: 5_000)

        #expect(throws: ExportClipPlanError.emptyPlan) {
            try ShortsClipPlanner.clips(for: short, editTimeline: nil)
        }
    }

    @Test
    func testShortOutsideTimelineThrowsEmptyPlan() {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 60_000,
                    timelineStartMs: 0,
                    timelineEndMs: 60_000
                )
            ],
            totalDurationMs: 60_000
        )
        let short = ShortDefinition(title: "Beyond", startMs: 70_000, endMs: 80_000)

        #expect(throws: ExportClipPlanError.emptyPlan) {
            try ShortsClipPlanner.clips(for: short, editTimeline: timeline)
        }
    }

    @Test
    func testLocalizedSubtitlesClampAndShiftIntoShortTime() {
        let cues = [
            makeCue(index: 1, startMs: 0, endMs: 2_000, text: "before"),
            makeCue(index: 2, startMs: 3_000, endMs: 5_000, text: "clipped head"),
            makeCue(index: 3, startMs: 5_500, endMs: 9_000, text: "inside"),
            makeCue(index: 4, startMs: 10_000, endMs: 12_000, text: "clipped tail"),
            makeCue(index: 5, startMs: 12_000, endMs: 14_000, text: "after")
        ]
        let originalCues = cues
        let short = ShortDefinition(title: "Mid", startMs: 4_000, endMs: 11_000)

        let localized = ShortsClipPlanner.localizedSubtitles(cues, for: short)

        #expect(localized.count == 3)
        #expect(localized[0].originalText == "clipped head")
        #expect(localized[0].startMs == 0)
        #expect(localized[0].endMs == 1_000)
        #expect(localized[1].originalText == "inside")
        #expect(localized[1].startMs == 1_500)
        #expect(localized[1].endMs == 5_000)
        #expect(localized[2].originalText == "clipped tail")
        #expect(localized[2].startMs == 6_000)
        #expect(localized[2].endMs == 7_000)
        #expect(localized.map(\.index) == [1, 2, 3])
        #expect(cues == originalCues)
    }

    @Test
    func testSRTSidecarUsesLocalizedTimes() async throws {
        let cues = [makeCue(index: 7, startMs: 61_000, endMs: 63_500, text: "Hello")]
        let short = ShortDefinition(title: "SRT", startMs: 60_000, endMs: 70_000)
        let localized = ShortsClipPlanner.localizedSubtitles(cues, for: short)

        var project = MockData.project
        project.subtitles = localized

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShortsSRT-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("short.srt")

        try await FileSubtitleExportService().export(
            project: project,
            kind: .translatedSRT,
            destinationURL: destination
        )

        let content = try String(contentsOf: destination, encoding: .utf8)
        #expect(content.contains("00:00:01,000 --> 00:00:03,500"))
        #expect(content.contains("Hello"))
    }

    @Test
    func testSRTSidecarUsesShortsTextModeWithoutVisualMarkup() async throws {
        var project = MockData.project
        project.subtitles = [
            SubtitleSegment(
                id: UUID(),
                index: 1,
                startMs: 0,
                endMs: 2_000,
                originalText: "Original caption",
                translatedText: "Translated caption"
            )
        ]
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShortsTextMode-\(UUID().uuidString).srt")
        defer { try? FileManager.default.removeItem(at: destination) }

        var shortsStyle = ShortsExportSettings.defaultSubtitleStyle
        shortsStyle.subtitleTextMode = .translated
        shortsStyle.fontName = "Avenir Next"
        shortsStyle.backgroundEnabled = true

        try await FileSubtitleExportService().exportSRT(
            project: project,
            textMode: shortsStyle.subtitleTextMode,
            destinationURL: destination
        )

        let content = try String(contentsOf: destination, encoding: .utf8)
        #expect(!content.contains("Original caption"))
        #expect(content.contains("Translated caption"))
        #expect(!content.contains("Avenir Next"))
        #expect(!content.contains("Dialogue:"))
    }

    private func makeCue(index: Int, startMs: Int, endMs: Int, text: String) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: index,
            startMs: startMs,
            endMs: endMs,
            originalText: text,
            translatedText: ""
        )
    }
}
