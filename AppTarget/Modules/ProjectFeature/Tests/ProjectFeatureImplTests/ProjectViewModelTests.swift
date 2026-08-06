import Application
import ExportFeature
import Foundation
import Media
import Project
import ProjectPreparation
import Settings
import Shorts
import SpeakerAnalysis
import SpeechToText
import Subtitles
import SubtitleEditorFeature
import Timeline
import TranscriptionPipeline
import TranslationPipeline
import VideoRendering
import VideoExport
import XCTest

@testable import ProjectFeatureImpl

@MainActor
final class ProjectViewModelTests: XCTestCase {
    func testPreparationPresentationMapsTypedProgressAndOutcomes() {
        XCTAssertEqual(
            ProjectPreparationPresentation.status(for: ProjectPreparationProgress(
                phase: .readingDuration,
                fractionCompleted: 0.06
            )),
            "Reading video duration..."
        )
        XCTAssertEqual(
            ProjectPreparationPresentation.status(for: ProjectPreparationProgress(
                phase: .preparingWaveform,
                fractionCompleted: 0.5,
                providerDetail: "Loading cached waveform..."
            )),
            "Loading cached waveform..."
        )
        XCTAssertEqual(
            ProjectPreparationPresentation.status(
                for: .degraded(.waveformUnavailableAndCleanupFailed(message: "Cleanup failed."))
            ),
            "Project ready. Waveform unavailable; temporary audio cleanup failed."
        )
    }

    func testSubtitlePickerCancellationDoesNotStartImportOrShowError() async {
        let appState = TestDoubles.appState(project: TestDoubles.project())
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            subtitleDocumentPicker: SubtitleDocumentPicker { _ in .cancelled }
        )

        viewModel.importSubtitlesFromFile()
        await Task.yield()

        XCTAssertFalse(viewModel.isImportingSubtitles)
        XCTAssertNil(viewModel.subtitleImportPreview)
        XCTAssertNil(viewModel.subtitleImportErrorMessage)
    }

    func testSubtitlePickerFailureIsPresentedWithoutStartingImport() async throws {
        let appState = TestDoubles.appState(project: TestDoubles.project())
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            subtitleDocumentPicker: SubtitleDocumentPicker { _ in
                .failed(SubtitleDocumentPickerFailure(message: "Picker unavailable"))
            }
        )

        viewModel.importSubtitlesFromFile()
        try await Task.sleep(for: .milliseconds(20))

        XCTAssertFalse(viewModel.isImportingSubtitles)
        XCTAssertNil(viewModel.subtitleImportPreview)
        XCTAssertEqual(viewModel.subtitleImportErrorMessage, "Picker unavailable")
    }

    func testVideoExportCancellationDoesNotMutateProjectOrQueue() {
        let project = TestDoubles.project()
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(appState: appState)
        _ = VideoExportPresentationActions(submit: viewModel.submitVideoExport)

        XCTAssertEqual(viewModel.project?.videoExportSettings, project.videoExportSettings)
        XCTAssertTrue(TestDoubles.videoExportQueue(for: appState)?.jobs.isEmpty == true)
    }

    func testVideoExportSubmissionPersistsSettingsAndQueuesExactlyOnce() {
        let project = TestDoubles.project()
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(appState: appState)
        var settings = project.videoExportSettings
        settings.fontSize = 48
        let outputURL = URL(fileURLWithPath: "/tmp/contract-export.mp4")
        let actions = VideoExportPresentationActions(submit: viewModel.submitVideoExport)

        actions.submit(
            VideoExportSubmission(
                project: project,
                settings: settings,
                sourceInfo: nil,
                outputURL: outputURL
            )
        )

        XCTAssertEqual(viewModel.project?.videoExportSettings, settings)
        XCTAssertEqual(TestDoubles.selectedProject(for: appState)?.videoExportSettings, settings)
        XCTAssertEqual(TestDoubles.videoExportQueue(for: appState)?.jobs.count, 1)
        XCTAssertEqual(TestDoubles.videoExportQueue(for: appState)?.jobs.first?.outputURL, outputURL)
    }

    func testEditorAndTimelineEditsReachExportThroughTheSameProjectArray() async throws {
        let exporter = RecordingSubtitleExporter()
        let originalProject = TestDoubles.project()
        let appState = TestDoubles.appState(
            project: originalProject,
            subtitleExportService: exporter
        )
        let viewModel = TestDoubles.projectViewModel(appState: appState)
        var editorSegment = try XCTUnwrap(viewModel.project?.subtitles.first)
        editorSegment.translatedText = "Shared root text"

        viewModel.updateSubtitle(editorSegment)

        var timelineSubtitles = try XCTUnwrap(viewModel.project?.subtitles)
        timelineSubtitles[0].endMs = 2_500
        viewModel.updateSubtitlesFromTimeline(timelineSubtitles)
        await viewModel.exportSubtitles(
            kind: .translatedSRT,
            to: URL(fileURLWithPath: "/tmp/shared-root.srt")
        )

        let rootSubtitles = try XCTUnwrap(viewModel.project?.subtitles)
        XCTAssertEqual(TestDoubles.selectedProject(for: appState)?.subtitles, rootSubtitles)
        XCTAssertEqual(exporter.request?.segments, rootSubtitles)
        XCTAssertEqual(exporter.request?.segments.first?.translatedText, "Shared root text")
        XCTAssertEqual(exporter.request?.segments.first?.endMs, 2_500)
    }

    func testSingleSubtitleEditCreatesOneUndoStepAndAutosavesUpdatedRoot() async throws {
        let repository = TestDoubles.Repository()
        let originalProject = TestDoubles.project()
        let appState = TestDoubles.appState(project: originalProject, repository: repository)
        let viewModel = TestDoubles.projectViewModel(appState: appState)
        var segment = try XCTUnwrap(originalProject.subtitles.first)
        segment.translatedText = "Autosaved"

        viewModel.updateSubtitle(segment)

        XCTAssertTrue(viewModel.canUndo)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(repository.savedProjects.last?.subtitles.first?.translatedText, "Autosaved")
        XCTAssertEqual(
            TestDoubles.catalog(for: appState)?.registeredProjects.last?.subtitles.first?.translatedText,
            "Autosaved"
        )

        viewModel.undo()

        XCTAssertEqual(viewModel.project?.subtitles, originalProject.subtitles)
        XCTAssertFalse(viewModel.canUndo)
    }

    func testSubtitleSelectionAndEditStayVisibleThroughRootProjectState() throws {
        let originalProject = TestDoubles.project()
        let appState = TestDoubles.appState(project: originalProject)
        let viewModel = TestDoubles.projectViewModel(appState: appState)
        let segment = try XCTUnwrap(originalProject.subtitles.first)

        viewModel.selectSegment(id: segment.id)
        var edited = segment
        edited.startMs = 250
        edited.translatedText = "Edited through subtitle workspace"
        viewModel.updateSubtitle(edited)

        XCTAssertEqual(viewModel.selectedSegmentID, segment.id)
        XCTAssertEqual(viewModel.selectedCueIDs, [segment.id])
        XCTAssertEqual(viewModel.project?.subtitles.first?.startMs, 250)
        XCTAssertEqual(
            TestDoubles.selectedProject(for: appState)?.subtitles.first?.translatedText,
            "Edited through subtitle workspace"
        )
    }

    func testShortsWorkspaceMutationUpdatesRootProjectAndSupportsUndo() throws {
        var project = TestDoubles.project()
        let short = ShortDefinition(title: "Original", startMs: 1_000, endMs: 4_000)
        project.shorts = [short]
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(appState: appState)
        viewModel.shortsSelectedShortID = short.id

        viewModel.updateShort(id: short.id, undoActionName: "Rename Short") {
            $0.title = "Updated"
        }

        XCTAssertEqual(viewModel.selectedShort?.title, "Updated")
        XCTAssertEqual(TestDoubles.selectedProject(for: appState)?.shorts.first?.title, "Updated")

        viewModel.undo()

        XCTAssertEqual(viewModel.project?.shorts.first?.title, "Original")
        XCTAssertEqual(viewModel.shortsSelectedShortID, short.id)
    }

    func testSubtitleExportOptionsUpdateRootProjectAndSupportUndo() {
        let project = TestDoubles.project()
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(appState: appState)
        var options = project.speakerExportOptions
        options.includeSpeakerLabels = true
        options.speakerFormat = .squareBrackets

        viewModel.updateSpeakerExportOptions(options)

        XCTAssertEqual(viewModel.project?.speakerExportOptions, options)
        XCTAssertEqual(TestDoubles.selectedProject(for: appState)?.speakerExportOptions, options)

        viewModel.undo()

        XCTAssertEqual(viewModel.project?.speakerExportOptions, project.speakerExportOptions)
    }

    func testSubtitleEditUsesProjectAsTheSingleSourceOfTruth() {
        let originalProject = TestDoubles.project()
        let appState = TestDoubles.appState(project: originalProject)
        let viewModel = TestDoubles.projectViewModel(appState: appState)
        let segmentID = try! XCTUnwrap(originalProject.subtitles.first?.id)

        viewModel.updateTimelineTranslatedText(segmentID: segmentID, text: "Привет")

        XCTAssertEqual(viewModel.project?.subtitles.first?.translatedText, "Привет")
        XCTAssertEqual(TestDoubles.selectedProject(for: appState)?.subtitles.first?.translatedText, "Привет")
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

        let viewModel = TestDoubles.projectViewModel(appState: appState)
        viewModel.exportShorts([short], to: URL(fileURLWithPath: "/tmp"))

        let jobs = TestDoubles.videoExportQueue(for: appState)?.jobs
        XCTAssertEqual(jobs?.count, 1)
        XCTAssertEqual(jobs?.first?.status, .failed)
        XCTAssertEqual(
            jobs?.first?.errorMessage,
            "The edit timeline has no clips to export. Review your cuts in Edit mode."
        )
    }

    func testTranscriptionMapsFocusedSettingsAndTypedProgress() async throws {
        let project = TestDoubles.project()
        var completedProject = project
        completedProject.status = .ready
        let transcriber = TestDoubles.Transcriber(events: [
            .progress(TranscriptionPipelineProgress(
                phase: .analyzingSpeakers,
                fractionCompleted: 0.95
            )),
        ])
        transcriber.output = TranscriptionPipelineOutput(
            project: completedProject,
            warning: .speakerAnalysisUnavailable(detail: "Speaker engine unavailable.")
        )
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranscriber: transcriber
        )

        await viewModel.transcribe()

        let request = try XCTUnwrap(transcriber.requests.first)
        XCTAssertEqual(request.project.id, project.id)
        XCTAssertEqual(request.configuration.ffmpegExecutablePath, AppSettings.default.ffmpegPath)
        XCTAssertEqual(request.configuration.speechToText.providerName, AppSettings.default.speechToTextProviderName)
        XCTAssertEqual(request.configuration.speechToText.whisperModelName, AppSettings.default.whisperModelName)
        XCTAssertEqual(request.configuration.speechToText.whisperVADEnabled, AppSettings.default.whisperVADEnabled)
        XCTAssertEqual(appState.transcriptionActivity?.status, .succeeded)
        XCTAssertEqual(
            appState.transcriptionActivity?.statusText,
            "Transcription complete. Speaker analysis failed; subtitle timings were not refined. Speaker engine unavailable."
        )
    }

    func testTranscriptionPresentationMapsPathsAndWarning() {
        var settings = AppSettings.default
        settings.whisperExecutablePath = " /tmp/whisper "
        settings.whisperModelPath = "/tmp/model.bin"
        settings.whisperVADModelPath = "/tmp/vad.bin"
        settings.whisperVADEnabled = false
        let configuration = TranscriptionPipelinePresentation.configuration(from: settings)

        XCTAssertEqual(configuration.speechToText.whisperExecutableURL?.path, "/tmp/whisper")
        XCTAssertEqual(configuration.speechToText.whisperModelURL?.path, "/tmp/model.bin")
        XCTAssertEqual(configuration.speechToText.whisperVADModelURL?.path, "/tmp/vad.bin")
        XCTAssertFalse(configuration.speechToText.whisperVADEnabled)
        settings.whisperExecutablePath = " "
        settings.whisperModelPath = ""
        settings.whisperVADModelPath = "  "
        let emptyPaths = TranscriptionPipelinePresentation.configuration(from: settings)
        XCTAssertNil(emptyPaths.speechToText.whisperExecutableURL)
        XCTAssertNil(emptyPaths.speechToText.whisperModelURL)
        XCTAssertNil(emptyPaths.speechToText.whisperVADModelURL)
        XCTAssertEqual(
            TranscriptionPipelinePresentation.completionMessage(
                for: .speakerAnalysisUnavailable(detail: "Speaker engine unavailable.")
            ),
            "Transcription complete. Speaker analysis failed; subtitle timings were not refined. Speaker engine unavailable."
        )
    }

    func testTranscriptionFailureAndCancellationMapToActivity() async {
        let project = TestDoubles.project()
        let failure = TestDoubles.Transcriber(
            error: TranscriptionPipelineError.emptyEditTimeline
        )
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranscriber: failure
        )

        await viewModel.transcribe()
        XCTAssertEqual(viewModel.exportMessage, TranscriptionPipelineError.emptyEditTimeline.errorDescription)
        XCTAssertEqual(appState.transcriptionActivity?.status, .failed)

        let cancellation = TestDoubles.Transcriber(error: CancellationError())
        let cancelledViewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranscriber: cancellation
        )
        await cancelledViewModel.transcribe()
        XCTAssertNil(appState.transcriptionActivity)
    }

    func testPreparationResultDoesNotOverwriteNewlySelectedProject() async throws {
        let original = TestDoubles.project()
        var replacement = TestDoubles.project()
        replacement.name = "Replacement"
        let appState = TestDoubles.appState(project: original)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectPreparer: DelayedPreparer()
        )

        viewModel.prepareProjectForEditing()
        TestDoubles.select(replacement, for: appState)
        viewModel.loadSelectedProject()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(viewModel.project?.id, replacement.id)
        XCTAssertEqual(viewModel.project?.name, "Replacement")
    }

    func testTranscriptionEventsAndResultDoNotOverwriteNewlySelectedProject() async {
        let original = TestDoubles.project()
        var replacement = TestDoubles.project()
        replacement.name = "Replacement"
        let appState = TestDoubles.appState(project: original)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranscriber: DelayedTranscriber()
        )

        let transcriptionTask = Task { await viewModel.transcribe() }
        await Task.yield()
        TestDoubles.select(replacement, for: appState)
        viewModel.loadSelectedProject()
        await transcriptionTask.value

        XCTAssertEqual(viewModel.project?.id, replacement.id)
        XCTAssertEqual(viewModel.project?.name, "Replacement")
        XCTAssertNil(appState.transcriptionActivity)
    }

    func testTranslationResultDoesNotOverwriteNewlySelectedProject() async throws {
        let original = TestDoubles.project()
        var replacement = TestDoubles.project()
        replacement.name = "Replacement"
        let appState = TestDoubles.appState(project: original)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranslator: DelayedTranslator()
        )

        let translationTask = Task { await viewModel.translate() }
        await Task.yield()
        TestDoubles.select(replacement, for: appState)
        viewModel.loadSelectedProject()
        await translationTask.value

        XCTAssertEqual(viewModel.project?.id, replacement.id)
        XCTAssertEqual(viewModel.project?.name, "Replacement")
    }

    func testTranslationSuccessAppliesTypedEventsAndOutput() async throws {
        let project = TestDoubles.project()
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranslator: SuccessfulTranslator()
        )

        await viewModel.translate()

        XCTAssertEqual(viewModel.project?.status, .ready)
        XCTAssertEqual(viewModel.project?.subtitles.first?.translatedText, "Translated")
        XCTAssertFalse(viewModel.isTranslating)
        XCTAssertNil(viewModel.exportMessage)
    }

    func testTranslationFailureMapsTypedEventAndErrorToPresentation() async throws {
        let project = TestDoubles.project()
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranslator: FailingTranslator()
        )

        await viewModel.translate()

        XCTAssertEqual(viewModel.project?.status, .failed("Translation provider unavailable."))
        XCTAssertEqual(viewModel.exportMessage, "Translation provider unavailable.")
        XCTAssertFalse(viewModel.isTranslating)
    }

    func testTranslationCancellationLeavesProjectAndPresentationUnchanged() async throws {
        let project = TestDoubles.project()
        let appState = TestDoubles.appState(project: project)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranslator: CancellingTranslator()
        )

        await viewModel.translate()

        XCTAssertEqual(viewModel.project, project)
        XCTAssertNil(viewModel.exportMessage)
        XCTAssertFalse(viewModel.isTranslating)
    }

    func testTranslationCanRetryAfterFailure() async throws {
        let project = TestDoubles.project()
        let appState = TestDoubles.appState(project: project)
        let translator = RetryTranslator()
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranslator: translator
        )

        await viewModel.translate()
        XCTAssertEqual(viewModel.exportMessage, "Translation provider unavailable.")

        viewModel.exportMessage = nil
        await viewModel.translate()

        XCTAssertEqual(translator.callCount, 2)
        XCTAssertEqual(viewModel.project?.status, .ready)
        XCTAssertEqual(viewModel.project?.subtitles.first?.translatedText, "Translated on retry")
        XCTAssertNil(viewModel.exportMessage)
    }
}

private final class RecordingSubtitleExporter: SubtitleExportService {
    var request: SubtitleExportRequest?

    func export(
        request: SubtitleExportRequest,
        kind _: SubtitleExportKind,
        destinationURL _: URL
    ) async throws {
        self.request = request
    }

    func exportSRT(
        request: SubtitleExportRequest,
        textMode _: SubtitleTextMode,
        destinationURL _: URL
    ) async throws {
        self.request = request
    }
}

private struct DelayedPreparer: ProjectPreparing {
    func prepare(
        _ request: ProjectPreparationRequest,
        events: @escaping ProjectPreparationEventHandler
    ) async throws -> ProjectPreparationOutput {
        try await Task.sleep(for: .milliseconds(40))
        await events(.projectChanged(request.project))
        return ProjectPreparationOutput(
            project: request.project,
            waveformPeaks: [1],
            videoSourceInfo: nil,
            outcome: .ready
        )
    }
}

private struct DelayedTranscriber: TranscribingProject {
    func transcribe(
        _ request: TranscriptionPipelineRequest,
        events: @escaping TranscriptionPipelineEventHandler
    ) async throws -> TranscriptionPipelineOutput {
        try await Task.sleep(for: .milliseconds(40))
        var completed = request.project
        completed.name = "Stale transcription"
        await events(.projectChanged(completed))
        return TranscriptionPipelineOutput(project: completed, warning: nil)
    }
}

private struct DelayedTranslator: TranslatingProject {
    func translate(
        _ request: TranslationPipelineRequest,
        events: @escaping TranslationPipelineEventHandler
    ) async throws -> TranslationPipelineOutput {
        try await Task.sleep(for: .milliseconds(40))
        await events(.ready(request.project))
        return TranslationPipelineOutput(project: request.project)
    }
}

private struct SuccessfulTranslator: TranslatingProject {
    func translate(
        _ request: TranslationPipelineRequest,
        events: @escaping TranslationPipelineEventHandler
    ) async throws -> TranslationPipelineOutput {
        var project = request.project
        project.status = .translating
        await events(.translating(project))
        project.subtitles[0].translatedText = "Translated"
        project.status = .ready
        await events(.ready(project))
        return TranslationPipelineOutput(project: project)
    }
}

private struct FailingTranslator: TranslatingProject {
    func translate(
        _ request: TranslationPipelineRequest,
        events: @escaping TranslationPipelineEventHandler
    ) async throws -> TranslationPipelineOutput {
        var project = request.project
        project.status = .failed("Translation provider unavailable.")
        await events(.failed(project))
        throw TranslationPipelineError.providerFailed(message: "Translation provider unavailable.")
    }
}

private struct CancellingTranslator: TranslatingProject {
    func translate(
        _ request: TranslationPipelineRequest,
        events: @escaping TranslationPipelineEventHandler
    ) async throws -> TranslationPipelineOutput {
        throw CancellationError()
    }
}

private final class RetryTranslator: TranslatingProject {
    private(set) var callCount = 0

    func translate(
        _ request: TranslationPipelineRequest,
        events: @escaping TranslationPipelineEventHandler
    ) async throws -> TranslationPipelineOutput {
        callCount += 1
        if callCount == 1 {
            throw TranslationPipelineError.providerFailed(message: "Translation provider unavailable.")
        }

        var project = request.project
        project.subtitles[0].translatedText = "Translated on retry"
        project.status = .ready
        await events(.ready(project))
        return TranslationPipelineOutput(project: project)
    }
}
