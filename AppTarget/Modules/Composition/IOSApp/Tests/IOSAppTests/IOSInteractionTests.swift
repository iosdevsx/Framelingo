import Foundation
@testable import IOSApp
import Project
import Subtitles
import XCTest

@MainActor
final class IOSInteractionTests: XCTestCase {
    func testSeekAndPlaybackStateUseTheOpenedWorkspace() async {
        let model = IOSAppComposition.makeModel(repository: InteractionRepository())
        model.open(interactionProject())

        model.seek(to: 1_500)
        XCTAssertEqual(model.currentTimeMs, 1_500)
        XCTAssertEqual(model.snapshot.interaction.playback.playheadMs, 1_500)

        model.togglePlayback()
        XCTAssertTrue(model.isPlaying)
        model.togglePlayback()
        XCTAssertFalse(model.isPlaying)

        await model.closeWorkspace()
    }

    func testSubtitleSelectionAndTextEditMutateCanonicalProjectOnly() async throws {
        let model = IOSAppComposition.makeModel(repository: InteractionRepository())
        let project = interactionProject()
        let segment = try XCTUnwrap(project.subtitles.first)
        model.open(project)

        let actions = model.subtitleEditorActions
        actions.selectSegment(id: segment.id)
        var edited = segment
        edited.translatedText = "Отредактировано"
        let result = actions.updateSubtitle(edited)

        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(model.snapshot.interaction.cueSelection.primaryCueID, segment.id)
        XCTAssertEqual(
            model.snapshot.project?.subtitles.first?.translatedText,
            "Отредактировано"
        )
        XCTAssertEqual(model.subtitleEditorState.subtitles, model.snapshot.project?.subtitles)

        await model.closeWorkspace()
    }

    func testInvalidTimingKeepsCanonicalSubtitleAndReportsUnderstandableError() async throws {
        let model = IOSAppComposition.makeModel(repository: InteractionRepository())
        let project = interactionProject()
        var segment = try XCTUnwrap(project.subtitles.first)
        model.open(project)
        segment.endMs = segment.startMs

        let result = model.subtitleEditorActions.updateSubtitle(segment)

        XCTAssertEqual(result.errorMessage, "End time must be greater than start time.")
        XCTAssertEqual(model.snapshot.project?.subtitles.first?.endMs, 2_000)
        XCTAssertEqual(model.errorMessage, "End time must be greater than start time.")

        await model.closeWorkspace()
    }

    func testPlaybackWithoutWorkspaceReportsUnderstandableError() {
        let model = IOSAppComposition.makeModel(repository: InteractionRepository())

        model.togglePlayback()

        XCTAssertEqual(model.errorMessage, "The project video is unavailable.")
    }
}

private final class InteractionRepository: ProjectRepository {
    func createProject(for mediaFile: MediaFile) async throws -> Project { interactionProject() }
    func saveProject(_ project: Project) async throws {}
    func loadProject(id: UUID) async throws -> Project { interactionProject(id: id) }
    func listProjects() async throws -> [Project] { [] }
    func deleteProject(id: UUID) async throws {}
}

private func interactionProject(id: UUID = UUID()) -> Project {
    Project(
        id: id,
        name: "Interaction Project",
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        mediaFile: MediaFile(
            id: UUID(),
            originalURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("interaction-video.mov"),
            fileName: "interaction-video.mov",
            fileExtension: "mov",
            sizeBytes: 1,
            durationMs: 4_000
        ),
        sourceLanguage: "English",
        targetLanguage: "Russian",
        subtitles: [
            SubtitleSegment(
                id: UUID(),
                index: 1,
                startMs: 1_000,
                endMs: 2_000,
                originalText: "Hello",
                translatedText: "Привет"
            ),
            SubtitleSegment(
                id: UUID(),
                index: 2,
                startMs: 2_200,
                endMs: 3_200,
                originalText: "World",
                translatedText: "Мир"
            ),
        ],
        status: .ready
    )
}
