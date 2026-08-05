import Application
import Shorts
import XCTest

@MainActor
final class ProjectViewModelTests: XCTestCase {
    func testSubtitleEditUsesProjectAsTheSingleSourceOfTruth() {
        let originalProject = TestDoubles.project()
        let appState = TestDoubles.appState(project: originalProject)
        let viewModel = TestDoubles.projectViewModel(appState: appState)
        let segmentID = try! XCTUnwrap(originalProject.subtitles.first?.id)

        viewModel.updateTimelineTranslatedText(segmentID: segmentID, text: "Привет")

        XCTAssertEqual(viewModel.project?.subtitles.first?.translatedText, "Привет")
        XCTAssertEqual(appState.selectedProject?.subtitles.first?.translatedText, "Привет")
        XCTAssertEqual(viewModel.project?.subtitles.count, 1)
    }

    func testUndoRedoRestoresProjectSelectionAndPlaybackState() throws {
        let originalProject = TestDoubles.project()
        let appState = TestDoubles.appState(project: originalProject)
        let viewModel = TestDoubles.projectViewModel(appState: appState)
        let segment = try XCTUnwrap(originalProject.subtitles.first)

        viewModel.selectSegment(id: segment.id)
        viewModel.seekTo(ms: 1_234)
        var edited = segment
        edited.translatedText = "Привет"
        viewModel.updateSubtitle(edited)

        viewModel.selectSegment(id: nil)
        viewModel.seekTo(ms: 5_000)
        viewModel.undo()

        XCTAssertEqual(viewModel.project?.subtitles, originalProject.subtitles)
        XCTAssertEqual(viewModel.selectedSegmentID, segment.id)
        XCTAssertEqual(viewModel.currentTimeMs, 1_234)

        viewModel.redo()
        XCTAssertEqual(viewModel.project?.subtitles.first?.translatedText, "Привет")
    }

    func testInvalidShortCreatesVisibleFailedExportJob() {
        let project = TestDoubles.project()
        let appState = TestDoubles.appState(project: project)
        let short = ShortDefinition(title: "Invalid", startMs: 1_000, endMs: 1_000)

        appState.enqueueShortsExport(
            project: project,
            shorts: [short],
            sourceInfo: nil,
            destinationDirectory: URL(fileURLWithPath: "/tmp")
        )

        XCTAssertEqual(appState.videoExportJobs.count, 1)
        XCTAssertEqual(appState.videoExportJobs.first?.status, .failed)
        XCTAssertEqual(
            appState.videoExportJobs.first?.errorMessage,
            "The edit timeline has no clips to export. Review your cuts in Edit mode."
        )
    }
}
