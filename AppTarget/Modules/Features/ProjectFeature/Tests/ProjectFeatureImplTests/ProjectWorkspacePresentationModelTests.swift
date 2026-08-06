import Foundation
import ProjectFeature
import SubtitleEditorFeature
import XCTest

@testable import ProjectFeatureImpl

@MainActor
final class ProjectWorkspacePresentationModelTests: XCTestCase {
    func testProjectsSnapshotAndDelegatesInteractionCommandsToSession() {
        let project = TestDoubles.project()
        let context = TestDoubles.appState(project: project)
        let model = ProjectWorkspacePresentationModel(
            dependencies: TestDoubles.projectFeatureDependencies(appState: context)
        )
        let cueID = project.subtitles[0].id

        model.selectSegment(id: cueID)
        model.seekTo(ms: 1_250)

        XCTAssertEqual(model.project?.id, project.id)
        XCTAssertEqual(context.session.snapshot.interaction.cueSelection.primaryCueID, cueID)
        XCTAssertEqual(context.session.snapshot.interaction.playback.playheadMs, 1_250)
    }

    func testMapsTypedTranslationValidationToPresentationMessage() async {
        let context = TestDoubles.appState(project: TestDoubles.project(subtitles: []))
        let model = ProjectWorkspacePresentationModel(
            dependencies: TestDoubles.projectFeatureDependencies(appState: context)
        )

        await model.translate()

        XCTAssertEqual(model.exportMessage, "No subtitles to translate.")
    }

    func testMapsPlatformPickerFailureWithoutCallingSessionImport() async throws {
        let context = TestDoubles.appState(project: TestDoubles.project())
        let model = ProjectWorkspacePresentationModel(dependencies: ProjectFeatureDependencies(
            session: context.session,
            subtitleDocumentPicker: SubtitleDocumentPicker { _ in
                .failed(SubtitleDocumentPickerFailure(message: "Picker unavailable."))
            }
        ))

        model.importSubtitlesFromFile()
        for _ in 0..<20 where model.subtitleImportErrorMessage == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(model.subtitleImportErrorMessage, "Picker unavailable.")
        XCTAssertEqual(context.session.snapshot.effects.subtitleImport, .idle)
    }
}
