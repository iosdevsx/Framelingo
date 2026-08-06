import Application
import ApplicationImpl
import Project
import Translation
import XCTest

final class ProjectProcessingWorkflowTests: XCTestCase {
    func testTranslationSuccessAndStatusOrder() async throws {
        let repository = TestDoubles.Repository()
        let workflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
            projectRepository: repository,
            translationService: WorkflowTranslation()
        )

        let output = try await workflow.translate(
            ProjectTranslationRequest(project: TestDoubles.project()),
            events: { _ in }
        )

        XCTAssertEqual(output.project.subtitles.first?.translatedText, "Translated")
        XCTAssertEqual(repository.savedProjects.map(\.status), [.translating, .ready])
    }

    func testTranslationValidatesInputResultAndLocalizedFailure() async {
        let emptyWorkflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
            projectRepository: TestDoubles.Repository(),
            translationService: WorkflowTranslation()
        )
        var emptyProject = TestDoubles.project()
        emptyProject.subtitles = []
        await assertError(.noSubtitles, workflow: emptyWorkflow, project: emptyProject)

        let mismatchWorkflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
            projectRepository: TestDoubles.Repository(),
            translationService: WorkflowTranslation(result: SubtitleTranslationResult(segments: []))
        )
        await assertError(.segmentCountMismatch, workflow: mismatchWorkflow, project: TestDoubles.project())

        let failureWorkflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
            projectRepository: TestDoubles.Repository(),
            translationService: WorkflowTranslation(error: WorkflowError.translation)
        )
        await assertError(.failed("Translation provider unavailable."), workflow: failureWorkflow, project: TestDoubles.project())
    }

    func testTranslationCancellationDoesNotPersistFailedState() async {
        let repository = TestDoubles.Repository()
        let workflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
            projectRepository: repository,
            translationService: WorkflowTranslation(error: CancellationError())
        )
        do {
            _ = try await workflow.translate(
                ProjectTranslationRequest(project: TestDoubles.project()),
                events: { _ in }
            )
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(repository.savedProjects.map(\.status), [.translating])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func assertError(
        _ expected: ProjectTranslationError,
        workflow: any ProjectTranslationWorkflow,
        project: Project
    ) async {
        do {
            _ = try await workflow.translate(ProjectTranslationRequest(project: project), events: { _ in })
            XCTFail("Expected \(expected)")
        } catch let error as ProjectTranslationError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private enum WorkflowError: LocalizedError {
    case translation

    var errorDescription: String? { "Translation provider unavailable." }
}

private struct WorkflowTranslation: TranslationOrchestrating {
    let result: SubtitleTranslationResult?
    let error: Error?

    init(result: SubtitleTranslationResult? = nil, error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func translateSubtitles(_ input: SubtitleTranslationInput) async throws -> SubtitleTranslationResult {
        if let error { throw error }
        if let result { return result }
        return SubtitleTranslationResult(
            segments: input.segments.map { segment in
                var segment = segment
                segment.translatedText = "Translated"
                return segment
            }
        )
    }
}
