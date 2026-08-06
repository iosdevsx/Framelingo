import Foundation
import Shorts
import Subtitles
import Testing
import Timeline
import VideoRendering

struct ShortsExportPlannerTests {
    @Test
    func batchIsOrderedReservesNamesAndKeepsInvalidSiblings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShortsExportPlanner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data().write(to: directory.appendingPathComponent("Project — 01 Same.mp4"))

        let later = ShortDefinition(title: "Same", startMs: 5_000, endMs: 8_000)
        let invalid = ShortDefinition(title: "Same", startMs: 2_000, endMs: 2_000)
        let earlier = ShortDefinition(title: "Same", startMs: 1_000, endMs: 4_000)
        let items = ShortsExportPlanner().plan(input(
            shorts: [later, invalid, earlier],
            destinationDirectory: directory
        ))

        #expect(items.map(\.shortID) == [earlier.id, invalid.id, later.id])
        #expect(items.map { $0.outputURL.lastPathComponent } == [
            "Project — 01 Same 2.mp4",
            "Project — 02 Same.mp4",
            "Project — 03 Same.mp4"
        ])
        guard case .invalid(.emptyClipPlan) = items[1].outcome else {
            Issue.record("Expected the degenerate Short to remain visible as an invalid item")
            return
        }
        #expect(items.count == 3)
    }

    @Test
    func planNormalizesRenderingOverridesSubtitlesHookAndEncoding() throws {
        let keyframeID = UUID()
        let short = ShortDefinition(
            title: "Portrait",
            startMs: 2_000,
            endMs: 7_000,
            reframing: .crop,
            cropOffsetX: 0.25,
            cropKeyframes: [ShortCropKeyframe(id: keyframeID, timeMs: 1_000, offsetX: 0.75)],
            hookText: "  Watch this  ",
            platformOverride: .instagramReels
        )
        var settings = ShortsExportSettings()
        settings.reframing = .blurPad
        settings.hookFontSize = 80
        settings.burnSubtitlesIntoVideo = false
        settings.exportSRTSidecar = true
        var encoding = VideoExportSettings()
        encoding.codec = .h264
        encoding.quality = .high
        encoding.preset = .slow
        encoding.resolution = .p720
        encoding.frameRate = .fps30
        let cue = SubtitleSegment(
            id: UUID(),
            index: 9,
            startMs: 1_000,
            endMs: 3_000,
            originalText: "Hello",
            translatedText: "Привет"
        )
        let sourceInfo = VideoSourceInfo(width: 3_840, height: 2_160, nominalFrameRate: 60)

        let item = try #require(ShortsExportPlanner().plan(ShortsExportPlanningInput(
            projectName: "Project",
            shorts: [short],
            settings: settings,
            encodingSettings: encoding,
            editTimeline: nil,
            subtitles: [cue],
            sourceInfo: sourceInfo,
            destinationDirectory: URL(fileURLWithPath: "/tmp")
        )).first)

        #expect(item.encodingSettings.codec == .h264)
        #expect(item.encodingSettings.quality == .high)
        #expect(item.encodingSettings.preset == .slow)
        #expect(item.encodingSettings.resolution == .original)
        #expect(item.encodingSettings.frameRate == .original)
        guard case .valid(let plan) = item.outcome else {
            Issue.record("Expected a normalized valid plan")
            return
        }
        #expect(plan.subtitles.map(\.index) == [1])
        #expect(plan.subtitles.first?.startMs == 0)
        #expect(plan.subtitles.first?.endMs == 1_000)
        #expect(plan.platform == .instagramReels)
        #expect(plan.reframe.mode == .crop)
        #expect(plan.reframe.cropOffsetX == 0.25)
        #expect(plan.reframe.cropKeyframes == [VideoCropKeyframe(id: keyframeID, timeMs: 1_000, offsetX: 0.75)])
        #expect(plan.reframe.sourceWidth == 3_840)
        #expect(plan.reframe.sourceHeight == 2_160)
        #expect(plan.hookText == "Watch this")
        #expect(plan.hookFontSize == 80)
        #expect(!plan.burnSubtitlesIntoVideo)
        #expect(plan.writeSRTSidecar)
    }

    @Test
    func editedTimelineAndEmptyBatchStayDeterministic() throws {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 10_000,
                    sourceEndMs: 12_000,
                    timelineStartMs: 0,
                    timelineEndMs: 2_000
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 20_000,
                    sourceEndMs: 24_000,
                    timelineStartMs: 2_000,
                    timelineEndMs: 6_000
                )
            ],
            totalDurationMs: 6_000
        )
        let short = ShortDefinition(title: "Across cut", startMs: 1_000, endMs: 4_000)
        let item = try #require(ShortsExportPlanner().plan(input(
            shorts: [short],
            editTimeline: timeline
        )).first)
        guard case .valid(let plan) = item.outcome else {
            Issue.record("Expected valid edited plan")
            return
        }

        #expect(plan.clips == [
            ExportClipRange(sourceStartMs: 11_000, sourceEndMs: 12_000),
            ExportClipRange(sourceStartMs: 20_000, sourceEndMs: 22_000)
        ])
        #expect(ShortsExportPlanner().plan(input(shorts: [])).isEmpty)
    }

    private func input(
        shorts: [ShortDefinition],
        editTimeline: EditTimeline? = nil,
        destinationDirectory: URL = URL(fileURLWithPath: "/tmp")
    ) -> ShortsExportPlanningInput {
        ShortsExportPlanningInput(
            projectName: "Project",
            shorts: shorts,
            settings: ShortsExportSettings(),
            encodingSettings: VideoExportSettings(),
            editTimeline: editTimeline,
            subtitles: [],
            sourceInfo: nil,
            destinationDirectory: destinationDirectory
        )
    }
}
