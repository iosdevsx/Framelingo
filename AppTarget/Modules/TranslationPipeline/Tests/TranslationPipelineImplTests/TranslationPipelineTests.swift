import Project
import Subtitles
import Translation
import TranslationPipeline
import TranslationPipelineImpl
import XCTest

final class TranslationPipelineTests: XCTestCase {
    func testEmptyInputRejectsBeforeProviderEventsOrPersistence() async {
        let recorder = Recorder()
        let repository = Repository(recorder: recorder)
        let provider = TranslationDouble()
        var project = makeProject()
        project.subtitles = []

        await assertPipelineError(
            .noSubtitles,
            translator: makeTranslator(repository: repository, provider: provider),
            project: project,
            recorder: recorder
        )

        XCTAssertTrue(provider.inputs.isEmpty)
        XCTAssertTrue(repository.savedProjects.isEmpty)
        XCTAssertTrue(recorder.entries.isEmpty)
    }

    func testSuccessPreservesProviderInputSegmentFieldsAndOrdering() async throws {
        let recorder = Recorder()
        let repository = Repository(recorder: recorder)
        let project = makeProject()
        let providerSegments = project.subtitles.enumerated().map { index, segment in
            SubtitleSegment(
                id: UUID(),
                index: 100 + index,
                startMs: 90_000,
                endMs: 99_000,
                originalText: "Provider replacement",
                translatedText: "Translation \(index + 1)",
                speaker: "Provider",
                speakerId: 99,
                confidence: 0.01,
                warnings: [.noSpeakerDetected]
            )
        }
        let provider = TranslationDouble(result: SubtitleTranslationResult(segments: providerSegments))

        let output = try await makeTranslator(repository: repository, provider: provider).translate(
            TranslationPipelineRequest(project: project),
            events: eventHandler(recorder: recorder)
        )

        let input = try XCTUnwrap(provider.inputs.first)
        XCTAssertEqual(provider.inputs.count, 1)
        XCTAssertEqual(input.segments, project.subtitles)
        XCTAssertEqual(input.sourceLanguage, project.sourceLanguage)
        XCTAssertEqual(input.targetLanguage, project.targetLanguage)
        XCTAssertEqual(input.style, .natural)
        XCTAssertEqual(output.project.status, .ready)
        XCTAssertGreaterThan(output.project.updatedAt, project.updatedAt)
        XCTAssertEqual(output.project.subtitles.map(\.translatedText), ["Translation 1", "Translation 2"])

        let clearedTranslations = output.project.subtitles.enumerated().map { index, translated in
            var segment = translated
            segment.translatedText = project.subtitles[index].translatedText
            return segment
        }
        XCTAssertEqual(clearedTranslations, project.subtitles)
        XCTAssertEqual(repository.savedProjects.map(\.status), [.translating, .ready])
        XCTAssertEqual(recorder.entries, [
            "event:translating", "save:translating",
            "event:ready", "save:ready",
        ])
    }

    func testSegmentMismatchDoesNotPartiallyApplyProviderOutput() async {
        let recorder = Recorder()
        let repository = Repository(recorder: recorder)
        let project = makeProject()
        let provider = TranslationDouble(result: SubtitleTranslationResult(segments: [project.subtitles[0]]))

        await assertPipelineError(
            .segmentCountMismatch,
            translator: makeTranslator(repository: repository, provider: provider),
            project: project,
            recorder: recorder
        )

        XCTAssertEqual(repository.savedProjects.map(\.status), [
            .translating,
            .failed("Translation provider returned a different number of subtitle segments."),
        ])
        XCTAssertEqual(repository.savedProjects.last?.subtitles, project.subtitles)
        XCTAssertEqual(recorder.entries, [
            "event:translating", "save:translating",
            "event:failed", "save:failed",
        ])
    }

    func testProviderFailureIsTypedAndPersistsUnderstandableFailedState() async {
        let recorder = Recorder()
        let repository = Repository(recorder: recorder)
        let provider = TranslationDouble(error: TestError.provider)

        await assertPipelineError(
            .providerFailed(message: "Translation provider unavailable."),
            translator: makeTranslator(repository: repository, provider: provider),
            project: makeProject(),
            recorder: recorder
        )

        XCTAssertEqual(repository.savedProjects.map(\.status), [
            .translating,
            .failed("Translation provider unavailable."),
        ])
    }

    func testFailedStatePersistenceErrorPreservesOperationAndPersistenceDiagnostics() async {
        let recorder = Recorder()
        let repository = Repository(recorder: recorder, failingSaveNumbers: [2])
        let provider = TranslationDouble(error: TestError.provider)

        await assertPipelineError(
            .persistenceFailed(
                operation: "Translation provider unavailable.",
                persistence: "Project save failed."
            ),
            translator: makeTranslator(repository: repository, provider: provider),
            project: makeProject(),
            recorder: recorder
        )

        XCTAssertEqual(repository.savedProjects.map(\.status), [.translating])
        XCTAssertEqual(recorder.entries, [
            "event:translating", "save:translating",
            "event:failed", "save:failed",
        ])
    }

    func testCancellationPropagatesWithoutFailedEventOrSave() async {
        let recorder = Recorder()
        let repository = Repository(recorder: recorder)
        let provider = TranslationDouble(error: CancellationError())
        let translator = makeTranslator(repository: repository, provider: provider)

        do {
            _ = try await translator.translate(
                TranslationPipelineRequest(project: makeProject()),
                events: eventHandler(recorder: recorder)
            )
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(repository.savedProjects.map(\.status), [.translating])
            XCTAssertEqual(recorder.entries, ["event:translating", "save:translating"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBlankProviderDiagnosticUsesTranslationFallback() async {
        let recorder = Recorder()
        let repository = Repository(recorder: recorder)
        let provider = TranslationDouble(error: TestError.blank)

        await assertPipelineError(
            .providerFailed(message: "Translation failed."),
            translator: makeTranslator(repository: repository, provider: provider),
            project: makeProject(),
            recorder: recorder
        )
    }

    func testTranslatingPersistenceFailureIsTypedAsOperationFailureAndCanPersistFailedState() async {
        let recorder = Recorder()
        let repository = Repository(recorder: recorder, failingSaveNumbers: [1])
        let provider = TranslationDouble()

        await assertPipelineError(
            .operationFailed(message: "Project save failed."),
            translator: makeTranslator(repository: repository, provider: provider),
            project: makeProject(),
            recorder: recorder
        )

        XCTAssertTrue(provider.inputs.isEmpty)
        XCTAssertEqual(repository.savedProjects.map(\.status), [.failed("Project save failed.")])
    }

    private func makeTranslator(
        repository: Repository,
        provider: TranslationDouble
    ) -> any TranslatingProject {
        TranslationPipelineAssembly.makeTranslator(
            projectRepository: repository,
            translationService: provider
        )
    }

    private func eventHandler(recorder: Recorder) -> TranslationPipelineEventHandler {
        { event in
            switch event {
            case .translating:
                recorder.entries.append("event:translating")
            case .ready:
                recorder.entries.append("event:ready")
            case .failed:
                recorder.entries.append("event:failed")
            }
        }
    }

    private func assertPipelineError(
        _ expected: TranslationPipelineError,
        translator: any TranslatingProject,
        project: Project,
        recorder: Recorder
    ) async {
        do {
            _ = try await translator.translate(
                TranslationPipelineRequest(project: project),
                events: eventHandler(recorder: recorder)
            )
            XCTFail("Expected \(expected)")
        } catch let error as TranslationPipelineError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class Recorder {
    var entries: [String] = []
}

private final class Repository: ProjectRepository {
    private let recorder: Recorder
    private let failingSaveNumbers: Set<Int>
    private var saveCount = 0
    private(set) var savedProjects: [Project] = []

    init(recorder: Recorder, failingSaveNumbers: Set<Int> = []) {
        self.recorder = recorder
        self.failingSaveNumbers = failingSaveNumbers
    }

    func createProject(for mediaFile: MediaFile) async throws -> Project {
        throw TestError.unexpected
    }

    func saveProject(_ project: Project) async throws {
        saveCount += 1
        recorder.entries.append("save:\(statusName(project.status))")
        if failingSaveNumbers.contains(saveCount) {
            throw TestError.persistence
        }
        savedProjects.append(project)
    }

    func loadProject(id: UUID) async throws -> Project {
        throw TestError.unexpected
    }

    func listProjects() async throws -> [Project] {
        savedProjects
    }

    func deleteProject(id: UUID) async throws {}

    private func statusName(_ status: ProcessingStatus) -> String {
        switch status {
        case .translating: "translating"
        case .ready: "ready"
        case .failed: "failed"
        default: "other"
        }
    }
}

private final class TranslationDouble: TranslationOrchestrating {
    let result: SubtitleTranslationResult?
    let error: Error?
    private(set) var inputs: [SubtitleTranslationInput] = []

    init(result: SubtitleTranslationResult? = nil, error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func translateSubtitles(_ input: SubtitleTranslationInput) async throws -> SubtitleTranslationResult {
        inputs.append(input)
        if let error {
            throw error
        }
        if let result {
            return result
        }
        return SubtitleTranslationResult(segments: input.segments)
    }
}

private enum TestError: LocalizedError {
    case provider
    case persistence
    case blank
    case unexpected

    var errorDescription: String? {
        switch self {
        case .provider: "Translation provider unavailable."
        case .persistence: "Project save failed."
        case .blank: " "
        case .unexpected: "Unexpected test call."
        }
    }
}

private func makeProject() -> Project {
    let first = SubtitleSegment(
        id: UUID(),
        index: 4,
        startMs: 120,
        endMs: 2_340,
        originalText: "Hello",
        translatedText: "Old one",
        speaker: "Host",
        speakerId: 7,
        confidence: 0.82,
        warnings: [.tooLong]
    )
    let second = SubtitleSegment(
        id: UUID(),
        index: 8,
        startMs: 2_500,
        endMs: 4_000,
        originalText: "World",
        translatedText: "Old two",
        speaker: "Guest",
        speakerId: 9,
        confidence: 0.74,
        warnings: [.overlappingSpeakers]
    )
    return Project(
        id: UUID(),
        name: "Translation fixture",
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        mediaFile: MediaFile(
            id: UUID(),
            originalURL: URL(fileURLWithPath: "/tmp/translation fixture.mp4"),
            fileName: "translation fixture.mp4",
            fileExtension: "mp4",
            sizeBytes: 1_024,
            durationMs: 10_000
        ),
        sourceLanguage: "English",
        targetLanguage: "Russian",
        subtitles: [first, second],
        status: .ready
    )
}
