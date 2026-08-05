import Application
import ApplicationImpl
import Foundation
import Media
import Project
import Shorts
import SpeakerAnalysis
import SpeechToText
import Subtitles
import Timeline
import VideoRendering
import XCTest

@testable import ProjectFeatureImpl

@MainActor
final class ProjectViewModelTests: XCTestCase {
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
        XCTAssertEqual(appState.selectedProject?.subtitles, rootSubtitles)
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
            appState.selectedProject?.subtitles.first?.translatedText,
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
        XCTAssertEqual(appState.selectedProject?.shorts.first?.title, "Updated")

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
        XCTAssertEqual(appState.selectedProject?.speakerExportOptions, options)

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

    func testRetranscriptionUsesEditedTimelineAudioForSpeechAndDiarization() async throws {
        var project = TestDoubles.project()
        project.editTimeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 1_000,
                    sourceEndMs: 3_000,
                    timelineStartMs: 0,
                    timelineEndMs: 2_000
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 7_000,
                    sourceEndMs: 9_000,
                    timelineStartMs: 2_000,
                    timelineEndMs: 4_000
                ),
            ],
            totalDurationMs: 4_000
        )

        let ffmpegService = RecordingFFmpegService()
        let speechProvider = RecordingSpeechProvider()
        let diarizationEngine = RecordingDiarizationEngine()
        let audioPreparationService = RecordingAudioPreparationService()
        let makeFFmpegService: FFmpegServiceBuilder = { _ in ffmpegService }
        let appState = TestDoubles.appState(
            project: project,
            speakerDiarizationEngine: diarizationEngine,
            audioPreparationService: audioPreparationService,
            makeFFmpegService: makeFFmpegService
        )
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            speechToTextProviderResolver: FixedSpeechProviderResolver(provider: speechProvider),
            makeFFmpegService: makeFFmpegService
        )

        await viewModel.transcribe()

        XCTAssertEqual(
            ffmpegService.receivedClips,
            [
                ExportClipRange(sourceStartMs: 1_000, sourceEndMs: 3_000),
                ExportClipRange(sourceStartMs: 7_000, sourceEndMs: 9_000),
            ]
        )
        let extractedAudioURL = try XCTUnwrap(ffmpegService.outputURL)
        XCTAssertEqual(speechProvider.receivedInput?.audioURL, extractedAudioURL)
        XCTAssertEqual(diarizationEngine.receivedAudioURL, extractedAudioURL)
        XCTAssertFalse(audioPreparationService.wasCalled)
        XCTAssertEqual(viewModel.project?.mediaFile.durationMs, 10_000)
        XCTAssertEqual(viewModel.project?.subtitles, speechProvider.result.segments)
    }

    func testTranscriptionWithoutEditTimelineStillUsesFullAudio() async throws {
        let project = TestDoubles.project()
        let ffmpegService = RecordingFFmpegService()
        let speechProvider = RecordingSpeechProvider()
        let diarizationEngine = RecordingDiarizationEngine()
        let makeFFmpegService: FFmpegServiceBuilder = { _ in ffmpegService }
        let appState = TestDoubles.appState(
            project: project,
            speakerDiarizationEngine: diarizationEngine,
            makeFFmpegService: makeFFmpegService
        )
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            speechToTextProviderResolver: FixedSpeechProviderResolver(provider: speechProvider),
            makeFFmpegService: makeFFmpegService
        )

        await viewModel.transcribe()

        XCTAssertNil(ffmpegService.receivedClips)
        let extractedAudioURL = try XCTUnwrap(ffmpegService.outputURL)
        XCTAssertEqual(speechProvider.receivedInput?.audioURL, extractedAudioURL)
        XCTAssertEqual(diarizationEngine.receivedAudioURL, extractedAudioURL)
        XCTAssertEqual(viewModel.project?.mediaFile.durationMs, speechProvider.result.durationMs)
    }

    func testEditedTimelineConstrainsGeneratedTimingToItsDuration() async throws {
        var project = TestDoubles.project()
        project.editTimeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 4_000,
                    timelineStartMs: 0,
                    timelineEndMs: 4_000
                ),
            ],
            totalDurationMs: 4_000
        )

        let speechProvider = OverflowingSpeechProvider()
        let diarizationEngine = RecordingDiarizationEngine(
            result: [
                SpeakerSegment(speakerId: 1, start: 3.8, end: 4.3),
                SpeakerSegment(speakerId: 2, start: 4.1, end: 4.4),
            ]
        )
        let ffmpegService = RecordingFFmpegService()
        let makeFFmpegService: FFmpegServiceBuilder = { _ in ffmpegService }
        let appState = TestDoubles.appState(
            project: project,
            speakerDiarizationEngine: diarizationEngine,
            makeFFmpegService: makeFFmpegService
        )
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            speechToTextProviderResolver: FixedSpeechProviderResolver(provider: speechProvider),
            makeFFmpegService: makeFFmpegService
        )

        await viewModel.transcribe()

        XCTAssertEqual(viewModel.project?.subtitles.count, 1)
        XCTAssertEqual(viewModel.project?.subtitles.first?.startMs, 3_500)
        XCTAssertEqual(viewModel.project?.subtitles.first?.endMs, 4_000)
        XCTAssertEqual(viewModel.project?.wordTimings.count, 1)
        XCTAssertEqual(viewModel.project?.wordTimings.first?.start, 3.9)
        XCTAssertEqual(viewModel.project?.wordTimings.first?.end, 4.0)
        XCTAssertEqual(viewModel.project?.speakerSegments.count, 1)
        XCTAssertEqual(viewModel.project?.speakerSegments.first?.start, 3.8)
        XCTAssertEqual(viewModel.project?.speakerSegments.first?.end, 4.0)
    }

    func testRetranscriptionRejectsTimelineWithoutRemainingClips() async {
        var project = TestDoubles.project()
        project.editTimeline = EditTimeline(clips: [], totalDurationMs: 0)
        let ffmpegService = RecordingFFmpegService()
        let makeFFmpegService: FFmpegServiceBuilder = { _ in ffmpegService }
        let appState = TestDoubles.appState(
            project: project,
            makeFFmpegService: makeFFmpegService
        )
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            makeFFmpegService: makeFFmpegService
        )

        await viewModel.transcribe()

        let message = "The edit timeline has no video to transcribe. Review your cuts in Edit mode."
        XCTAssertEqual(viewModel.project?.status, .failed(message))
        XCTAssertEqual(viewModel.exportMessage, message)
        XCTAssertNil(ffmpegService.outputURL)
    }

    func testPreparationResultDoesNotOverwriteNewlySelectedProject() async throws {
        let original = TestDoubles.project()
        var replacement = TestDoubles.project()
        replacement.name = "Replacement"
        let appState = TestDoubles.appState(project: original)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectPreparationWorkflow: DelayedPreparationWorkflow()
        )

        viewModel.prepareProjectForEditing()
        appState.selectedProject = replacement
        appState.recentProjects.append(replacement)
        viewModel.loadSelectedProject()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(viewModel.project?.id, replacement.id)
        XCTAssertEqual(viewModel.project?.name, "Replacement")
    }

    func testTranslationResultDoesNotOverwriteNewlySelectedProject() async throws {
        let original = TestDoubles.project()
        var replacement = TestDoubles.project()
        replacement.name = "Replacement"
        let appState = TestDoubles.appState(project: original)
        let viewModel = TestDoubles.projectViewModel(
            appState: appState,
            projectTranslationWorkflow: DelayedTranslationWorkflow()
        )

        let translationTask = Task { await viewModel.translate() }
        await Task.yield()
        appState.selectedProject = replacement
        appState.recentProjects.append(replacement)
        viewModel.loadSelectedProject()
        await translationTask.value

        XCTAssertEqual(viewModel.project?.id, replacement.id)
        XCTAssertEqual(viewModel.project?.name, "Replacement")
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

private final class RecordingFFmpegService: FFmpegService {
    var receivedClips: [ExportClipRange]?
    var outputURL: URL?

    func checkAvailability() async throws -> FFmpegInfo {
        FFmpegInfo(executableURL: URL(fileURLWithPath: "/usr/bin/true"), version: "test")
    }

    func extractAudio(
        from videoURL: URL,
        to outputURL: URL,
        clips: [ExportClipRange]?
    ) async throws -> URL {
        receivedClips = clips
        self.outputURL = outputURL
        return outputURL
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        clips: [ExportClipRange]?,
        verticalReframe: VerticalReframePlan?,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        outputURL
    }
}

private final class RecordingSpeechProvider: SpeechToTextProvider {
    var receivedInput: TranscriptionInput?
    let result = TranscriptionResult(
        segments: [
            SubtitleSegment(
                id: UUID(),
                index: 1,
                startMs: 0,
                endMs: 1_000,
                originalText: "Edited timeline",
                translatedText: ""
            ),
        ],
        words: [],
        detectedLanguage: nil,
        durationMs: 4_000
    )

    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        receivedInput = input
        return result
    }
}

private final class OverflowingSpeechProvider: SpeechToTextProvider {
    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        TranscriptionResult(
            segments: [
                SubtitleSegment(
                    id: UUID(),
                    index: 1,
                    startMs: 3_500,
                    endMs: 4_300,
                    originalText: "Inside",
                    translatedText: ""
                ),
                SubtitleSegment(
                    id: UUID(),
                    index: 2,
                    startMs: 4_100,
                    endMs: 4_500,
                    originalText: "Outside",
                    translatedText: ""
                ),
            ],
            words: [
                WordTiming(text: "Inside", start: 3.9, end: 4.2),
                WordTiming(text: "Outside", start: 4.1, end: 4.3),
            ],
            detectedLanguage: nil,
            durationMs: 4_300
        )
    }
}

private struct FixedSpeechProviderResolver: SpeechToTextProviderResolving {
    let provider: any SpeechToTextProvider

    func resolve(
        configuration: SpeechToTextProviderConfiguration
    ) throws -> any SpeechToTextProvider {
        provider
    }
}

private final class RecordingDiarizationEngine: SpeakerDiarizationEngine {
    var receivedAudioURL: URL?
    let result: [SpeakerSegment]

    init(result: [SpeakerSegment] = []) {
        self.result = result
    }

    func diarize(audioURL: URL) async throws -> [SpeakerSegment] {
        receivedAudioURL = audioURL
        return result
    }
}

private final class RecordingAudioPreparationService: AudioPreparationService {
    var wasCalled = false

    func preparedAudioURL(for sourceVideoURL: URL) async throws -> URL {
        wasCalled = true
        return sourceVideoURL
    }

    func removePreparedAudio(for sourceVideoURL: URL) throws {}
}

private struct DelayedPreparationWorkflow: ProjectPreparationWorkflow {
    func prepare(
        _ request: ProjectPreparationRequest,
        events: @escaping ProjectProcessingEventHandler
    ) async throws -> ProjectPreparationOutput {
        try await Task.sleep(for: .milliseconds(40))
        await events(.projectChanged(request.project))
        return ProjectPreparationOutput(
            project: request.project,
            waveformPeaks: [1],
            videoSourceInfo: nil,
            status: "Project ready"
        )
    }
}

private struct DelayedTranslationWorkflow: ProjectTranslationWorkflow {
    func translate(
        _ request: ProjectTranslationRequest,
        events: @escaping ProjectProcessingEventHandler
    ) async throws -> ProjectTranslationOutput {
        try await Task.sleep(for: .milliseconds(40))
        await events(.projectChanged(request.project))
        return ProjectTranslationOutput(project: request.project)
    }
}
