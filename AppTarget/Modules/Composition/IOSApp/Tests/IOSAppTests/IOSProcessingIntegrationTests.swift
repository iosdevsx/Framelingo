import Foundation
@testable import IOSApp
import Project
import XCTest

@MainActor
final class IOSProcessingIntegrationTests: XCTestCase {
    func testControlledTranscriptionAndTranslationCommitThroughSharedSession() async {
        let model = IOSAppComposition.makeModel(repository: ProcessingRepository())
        model.open(processingProject())

        await model.transcribe()

        XCTAssertEqual(model.snapshot.project?.subtitles.count, 2)
        XCTAssertEqual(model.subtitleEditorState.subtitles, model.snapshot.project?.subtitles)
        XCTAssertEqual(model.processingPresentation.title, "Ready")

        await model.translate()

        XCTAssertTrue(
            model.snapshot.project?.subtitles.allSatisfy {
                $0.translatedText.hasPrefix("[Mock] ")
            } == true
        )
        XCTAssertEqual(model.subtitleEditorState.subtitles, model.snapshot.project?.subtitles)

        await model.closeWorkspace()
    }

    func testTypedProcessingFailureMapsToUnderstandablePresentation() async {
        let options = IOSControlledProcessingOptions(
            delay: .zero,
            preparationFailure: nil,
            transcriptionFailure: "Controlled provider failed",
            translationFailure: nil
        )
        let model = IOSAppComposition.makeModel(
            repository: ProcessingRepository(),
            processingOptions: options
        )
        model.open(processingProject())

        await model.transcribe()

        XCTAssertEqual(model.processingPresentation.title, "Processing failed")
        XCTAssertEqual(model.processingPresentation.detail, "Controlled provider failed")
        XCTAssertFalse(model.processingPresentation.isRunning)

        await model.closeWorkspace()
    }

    func testReplacingWorkspaceCancelsStaleProcessingCommit() async {
        let options = IOSControlledProcessingOptions(
            delay: .milliseconds(250),
            preparationFailure: nil,
            transcriptionFailure: nil,
            translationFailure: nil
        )
        let model = IOSAppComposition.makeModel(
            repository: ProcessingRepository(),
            processingOptions: options
        )
        let first = processingProject(name: "First")
        let second = processingProject(name: "Second")
        model.open(first)

        let task = Task { @MainActor in
            await model.transcribe()
        }
        await Task.yield()
        model.open(second)
        await task.value

        XCTAssertEqual(model.snapshot.project?.id, second.id)
        XCTAssertTrue(model.snapshot.project?.subtitles.isEmpty == true)

        await model.closeWorkspace()
    }

    func testClosingSceneCancelsStaleProcessingAndReleasesWorkspace() async {
        let options = IOSControlledProcessingOptions(
            delay: .milliseconds(250),
            preparationFailure: nil,
            transcriptionFailure: nil,
            translationFailure: nil
        )
        let model = IOSAppComposition.makeModel(
            repository: ProcessingRepository(),
            processingOptions: options
        )
        model.open(processingProject())

        let task = Task { @MainActor in
            await model.transcribe()
        }
        await Task.yield()
        await model.sceneDidClose()
        await task.value

        XCTAssertNil(model.snapshot.project)
        XCTAssertNil(model.player)
        XCTAssertFalse(model.processingPresentation.isRunning)
    }
}

private final class ProcessingRepository: ProjectRepository {
    func createProject(for mediaFile: MediaFile) async throws -> Project { processingProject() }
    func saveProject(_ project: Project) async throws {}
    func loadProject(id: UUID) async throws -> Project { processingProject(id: id) }
    func listProjects() async throws -> [Project] { [] }
    func deleteProject(id: UUID) async throws {}
}

private func processingProject(
    id: UUID = UUID(),
    name: String = "Processing Project"
) -> Project {
    Project(
        id: id,
        name: name,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        mediaFile: MediaFile(
            id: UUID(),
            originalURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("processing-video.mov"),
            fileName: "processing-video.mov",
            fileExtension: "mov",
            sizeBytes: 1,
            durationMs: 8_000
        ),
        sourceLanguage: "English",
        targetLanguage: "Russian",
        subtitles: [],
        status: .idle
    )
}
