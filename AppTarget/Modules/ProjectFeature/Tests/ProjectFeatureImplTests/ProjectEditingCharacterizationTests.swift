import Foundation
import Project
import Shorts
import Subtitles
import Timeline
import XCTest

@testable import ProjectFeatureImpl

@MainActor
final class ProjectEditingCharacterizationTests: XCTestCase {
    func testSubtitleStructuralCommandsPreserveCurrentBehavior() throws {
        let original = segment(
            index: 7,
            startMs: 1_000,
            endMs: 5_000,
            originalText: "one two three",
            translatedText: "один два три",
            speaker: "Host",
            speakerId: 4,
            confidence: 0.82
        )
        let viewModel = makeViewModel(subtitles: [original])

        _ = try XCTUnwrap(viewModel.splitSegment(id: original.id))
        let split = try XCTUnwrap(viewModel.project?.subtitles)
        XCTAssertEqual(split.map(\.index), [1, 2])
        XCTAssertEqual(split.map(\.startMs), [1_000, 3_000])
        XCTAssertEqual(split.map(\.endMs), [3_000, 5_000])
        XCTAssertEqual(split.map(\.originalText), ["one", "two three"])
        XCTAssertEqual(split.map(\.translatedText), ["один", "два три"])
        XCTAssertEqual(split[1].speaker, "Host")
        XCTAssertEqual(split[1].speakerId, 4)
        XCTAssertEqual(split[1].confidence, 0.82)

        let mergedID = try XCTUnwrap(viewModel.mergeWithNextSegment(id: original.id))
        XCTAssertEqual(mergedID, original.id)
        XCTAssertEqual(viewModel.project?.subtitles.first?.originalText, "one two three")
        XCTAssertEqual(viewModel.project?.subtitles.first?.translatedText, "один два три")

        let addedID = try XCTUnwrap(viewModel.addSegmentAfter(id: mergedID))
        let added = try XCTUnwrap(viewModel.project?.subtitles.last)
        XCTAssertEqual(added.id, addedID)
        XCTAssertEqual(added.startMs, 5_000)
        XCTAssertEqual(added.endMs, 7_000)
        XCTAssertEqual(added.index, 2)

        let selectedAfterDelete = viewModel.deleteSegment(id: mergedID)
        XCTAssertEqual(selectedAfterDelete, addedID)
        XCTAssertEqual(viewModel.project?.subtitles.map(\.index), [1])
    }

    func testTimingAdjustmentKeepsGapAndPublishesExistingMessage() throws {
        let first = segment(index: 1, startMs: 0, endMs: 1_000)
        var second = segment(index: 2, startMs: 2_000, endMs: 3_000)
        let viewModel = makeViewModel(subtitles: [first, second])

        second.startMs = 900
        second.endMs = 1_100
        viewModel.updateSubtitle(second)

        let updated = try XCTUnwrap(viewModel.project?.subtitles[1])
        XCTAssertEqual(updated.startMs, 1_050)
        XCTAssertEqual(updated.endMs, 1_550)
        XCTAssertEqual(
            viewModel.autosaveErrorMessage,
            "Timing adjusted to keep a minimum 500ms duration and 50ms gap between subtitles."
        )
    }

    func testSubtitleImportModesAndDestinationsPreserveCurrentMergeRules() throws {
        let existing = [
            segment(index: 1, startMs: 0, endMs: 1_000, originalText: "A", translatedText: "TA"),
            segment(index: 2, startMs: 2_000, endMs: 3_000, originalText: "B", translatedText: "TB"),
        ]
        let imported = [
            segment(index: 10, startMs: 4_000, endMs: 5_000, originalText: "I1"),
            segment(index: 11, startMs: 6_000, endMs: 7_000, originalText: "I2"),
            segment(index: 12, startMs: 8_000, endMs: 9_000, originalText: "I3"),
        ]
        let preview = SubtitleImportPreview(
            fileURL: URL(fileURLWithPath: "/tmp/import.srt"),
            format: .srt,
            detectedEncodingName: "UTF-8",
            segments: imported,
            warnings: []
        )

        let originalReplace = makeViewModel(subtitles: existing)
        originalReplace.applySubtitleImport(preview, mode: .replaceExisting, destination: .original)
        XCTAssertEqual(originalReplace.project?.subtitles.map(\.originalText), ["I1", "I2", "I3"])

        let originalAppend = makeViewModel(subtitles: existing)
        originalAppend.applySubtitleImport(preview, mode: .appendToExisting, destination: .original)
        XCTAssertEqual(originalAppend.project?.subtitles.map(\.originalText), ["A", "B", "I1", "I2", "I3"])

        let translatedReplace = makeViewModel(subtitles: existing)
        translatedReplace.applySubtitleImport(preview, mode: .replaceExisting, destination: .translated)
        XCTAssertEqual(translatedReplace.project?.subtitles.map(\.originalText), ["A", "B", ""])
        XCTAssertEqual(translatedReplace.project?.subtitles.map(\.translatedText), ["I1", "I2", "I3"])

        let translatedAppend = makeViewModel(subtitles: existing)
        translatedAppend.applySubtitleImport(preview, mode: .appendToExisting, destination: .translated)
        XCTAssertEqual(translatedAppend.project?.subtitles.map(\.originalText), ["A", "B", "", "", ""])
        XCTAssertEqual(translatedAppend.project?.subtitles.map(\.translatedText), ["TA", "TB", "I1", "I2", "I3"])
    }

    func testRippleDeleteComposesTimelineSubtitleAndShortChangesInOneUndoStep() throws {
        let firstClip = TimelineClip(
            id: UUID(), sourceStartMs: 0, sourceEndMs: 2_000,
            timelineStartMs: 0, timelineEndMs: 2_000
        )
        let secondClip = TimelineClip(
            id: UUID(), sourceStartMs: 4_000, sourceEndMs: 10_000,
            timelineStartMs: 2_000, timelineEndMs: 8_000
        )
        let resultTimeline = EditTimeline(clips: [firstClip, secondClip], totalDurationMs: 8_000)
        var project = TestDoubles.project(subtitles: [segment(index: 1, startMs: 5_000, endMs: 7_000)])
        project.editTimeline = EditTimeline(
            clips: [TimelineClip(id: UUID(), sourceStartMs: 0, sourceEndMs: 10_000, timelineStartMs: 0, timelineEndMs: 10_000)],
            totalDurationMs: 10_000
        )
        project.shorts = [ShortDefinition(title: "Later", startMs: 6_000, endMs: 9_000)]
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            editTimelineService: PresetTimelineService(rippleResult: resultTimeline)
        )
        viewModel.editRangeStartMs = 2_000
        viewModel.editRangeEndMs = 4_000

        viewModel.rippleDeleteSelectedRange()

        XCTAssertEqual(viewModel.project?.editTimeline, resultTimeline)
        XCTAssertEqual(viewModel.project?.subtitles.first?.startMs, 3_000)
        XCTAssertEqual(viewModel.project?.shorts.first?.startMs, 4_000)
        XCTAssertTrue(viewModel.canUndo)
        viewModel.undo()
        XCTAssertEqual(viewModel.project?.editTimeline?.totalDurationMs, 10_000)
        XCTAssertFalse(viewModel.canUndo)
    }

    func testTimelineCommandsEachScheduleOneAutosaveAndOneUndoStep() async throws {
        let baseClip = TimelineClip(
            id: UUID(), sourceStartMs: 0, sourceEndMs: 10_000,
            timelineStartMs: 0, timelineEndMs: 10_000
        )
        let baseTimeline = EditTimeline(clips: [baseClip], totalDurationMs: 10_000)
        let leftClip = TimelineClip(
            id: baseClip.id, sourceStartMs: 0, sourceEndMs: 5_000,
            timelineStartMs: 0, timelineEndMs: 5_000
        )
        let rightClip = TimelineClip(
            id: UUID(), sourceStartMs: 5_000, sourceEndMs: 10_000,
            timelineStartMs: 5_000, timelineEndMs: 10_000
        )
        let splitTimeline = EditTimeline(clips: [leftClip, rightClip], totalDurationMs: 10_000)
        let deletedTimeline = EditTimeline(clips: [rightClip], totalDurationMs: 5_000)

        let rippleRepository = TestDoubles.Repository()
        let rippleProject = TestDoubles.project()
        let rippleState = TestDoubles.appState(project: rippleProject, repository: rippleRepository)
        let rippleViewModel = TestDoubles.projectViewModel(
            appState: rippleState,
            editTimelineService: PresetTimelineService(rippleResult: deletedTimeline)
        )
        rippleViewModel.editRangeStartMs = 2_000
        rippleViewModel.editRangeEndMs = 4_000
        rippleViewModel.rippleDeleteSelectedRange()
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(rippleRepository.savedProjects.count, 1)
        rippleViewModel.undo()
        XCTAssertFalse(rippleViewModel.canUndo)

        var splitProject = TestDoubles.project()
        splitProject.editTimeline = baseTimeline
        let splitRepository = TestDoubles.Repository()
        let splitState = TestDoubles.appState(project: splitProject, repository: splitRepository)
        let splitViewModel = TestDoubles.projectViewModel(
            appState: splitState,
            editTimelineService: PresetTimelineService(
                rippleResult: baseTimeline,
                splitResult: splitTimeline
            )
        )
        splitViewModel.seekTo(ms: 5_000)
        splitViewModel.splitAtCurrentTime()
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(splitRepository.savedProjects.count, 1)
        splitViewModel.undo()
        XCTAssertFalse(splitViewModel.canUndo)

        var deleteProject = TestDoubles.project()
        deleteProject.editTimeline = splitTimeline
        let deleteRepository = TestDoubles.Repository()
        let deleteState = TestDoubles.appState(project: deleteProject, repository: deleteRepository)
        let deleteViewModel = TestDoubles.projectViewModel(
            appState: deleteState,
            editTimelineService: PresetTimelineService(
                rippleResult: baseTimeline,
                deleteResult: deletedTimeline
            )
        )
        deleteViewModel.editModeSelectedClipID = leftClip.id
        deleteViewModel.deleteSelectedClip()
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(deleteRepository.savedProjects.count, 1)
        deleteViewModel.undo()
        XCTAssertFalse(deleteViewModel.canUndo)
    }

    func testShortRangeAndCropKeyframesPreserveCurrentBehavior() throws {
        let keptID = UUID()
        let removedID = UUID()
        let short = ShortDefinition(
            title: "Range",
            startMs: 1_000,
            endMs: 6_000,
            cropOffsetX: 0.4,
            cropKeyframes: [
                ShortCropKeyframe(id: removedID, timeMs: 500, offsetX: 0.2),
                ShortCropKeyframe(id: keptID, timeMs: 3_000, offsetX: 0.8),
            ]
        )
        var project = TestDoubles.project()
        project.shorts = [short]
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(appState: appState)

        viewModel.updateShortRange(id: short.id, startMs: 2_000, endMs: 5_000)

        let updated = try XCTUnwrap(viewModel.project?.shorts.first)
        XCTAssertEqual(updated.startMs, 2_000)
        XCTAssertEqual(updated.endMs, 5_000)
        XCTAssertEqual(updated.cropKeyframes.map(\.id), [keptID])
        XCTAssertEqual(updated.cropKeyframes.map(\.timeMs), [2_000])

        viewModel.seekTo(ms: 3_000)
        viewModel.addCropPointAtPlayhead(shortID: short.id)
        XCTAssertEqual(viewModel.project?.shorts.first?.cropKeyframes.map(\.timeMs), [1_000, 2_000])
        viewModel.deleteShortCropKeyframe(shortID: short.id, keyframeID: keptID)
        XCTAssertEqual(viewModel.project?.shorts.first?.cropKeyframes.map(\.timeMs), [1_000])
    }

    private func makeViewModel(subtitles: [SubtitleSegment]) -> ProjectViewModel {
        let appState = TestDoubles.appState(project: TestDoubles.project(subtitles: subtitles))
        return TestDoubles.projectViewModel(appState: appState)
    }

    private func segment(
        index: Int,
        startMs: Int,
        endMs: Int,
        originalText: String = "text",
        translatedText: String = "",
        speaker: String? = nil,
        speakerId: Int? = nil,
        confidence: Double? = nil
    ) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(), index: index, startMs: startMs, endMs: endMs,
            originalText: originalText, translatedText: translatedText,
            speaker: speaker, speakerId: speakerId, confidence: confidence
        )
    }
}

private struct PresetTimelineService: EditTimelineEditing {
    let rippleResult: EditTimeline
    var splitResult: EditTimeline?
    var deleteResult: EditTimeline?

    init(
        rippleResult: EditTimeline,
        splitResult: EditTimeline? = nil,
        deleteResult: EditTimeline? = nil
    ) {
        self.rippleResult = rippleResult
        self.splitResult = splitResult
        self.deleteResult = deleteResult
    }

    func makeInitialTimeline(durationMs: Int) -> EditTimeline { rippleResult }
    func rippleDeleteRange(timeline: EditTimeline, range: VideoCutRange) throws -> EditTimeline { rippleResult }
    func splitAt(timeline: EditTimeline, timelineMs: Int) throws -> EditTimeline { splitResult ?? timeline }
    func deleteClip(timeline: EditTimeline, clipID: UUID) throws -> EditTimeline { deleteResult ?? timeline }
    func sourceTime(forTimelineTime timelineMs: Int, in timeline: EditTimeline) -> Int? { nil }
    func clip(atTimelineTime timelineMs: Int, in timeline: EditTimeline) -> TimelineClip? {
        timeline.clips.first { timelineMs >= $0.timelineStartMs && timelineMs <= $0.timelineEndMs }
    }
    func playbackAdvance(
        sourceTimeMs: Int,
        currentClipID: UUID?,
        lastKnownTimelineMs: Int,
        in timeline: EditTimeline,
        lookaheadMs: Int
    ) -> EditTimelinePlaybackAdvance { .paused }
    func recalculateTimelinePositions(clips: [TimelineClip]) -> EditTimeline { rippleResult }
}
