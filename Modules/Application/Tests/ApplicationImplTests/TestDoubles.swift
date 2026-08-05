import Application
import ApplicationImpl
import Foundation
import Media
import Project
import Settings
import SpeakerAnalysis
import SpeechToText
import Subtitles
import Timeline
import Translation
import VideoRendering

enum TestDoubles {
    enum TestError: LocalizedError {
        case expected

        var errorDescription: String? { "Expected test failure." }
    }

    final class Repository: ProjectRepository {
        var projects: [UUID: Project] = [:]
        var savedProjects: [Project] = []

        func createProject(for mediaFile: MediaFile) async throws -> Project {
            throw TestError.expected
        }

        func saveProject(_ project: Project) async throws {
            projects[project.id] = project
            savedProjects.append(project)
        }

        func loadProject(id: UUID) async throws -> Project {
            guard let project = projects[id] else { throw TestError.expected }
            return project
        }

        func listProjects() async throws -> [Project] {
            Array(projects.values)
        }

        func deleteProject(id: UUID) async throws {
            projects[id] = nil
        }
    }

    struct TranslationService: TranslationOrchestrating {
        func translateSubtitles(
            _ input: SubtitleTranslationInput
        ) async throws -> SubtitleTranslationResult {
            SubtitleTranslationResult(segments: input.segments)
        }
    }

    struct DiarizationEngine: SpeakerDiarizationEngine {
        func diarize(audioURL: URL) async throws -> [SpeakerSegment] { [] }
    }

    struct AlignmentEngine: SubtitleAlignmentEngine {
        func align(
            words: [WordTiming],
            existingCues: [SubtitleAlignmentCue],
            speakerSegments: [SpeakerSegment],
            options: SubtitleAlignmentOptions
        ) async throws -> [SubtitleAlignmentCue] {
            existingCues
        }

        func align(
            existingCues: [SubtitleAlignmentCue],
            speakerSegments: [SpeakerSegment],
            options: SubtitleAlignmentOptions
        ) async throws -> [SubtitleAlignmentCue] {
            existingCues
        }
    }

    final class AudioPreparation: AudioPreparationService {
        func preparedAudioURL(for sourceVideoURL: URL) async throws -> URL {
            sourceVideoURL.deletingPathExtension().appendingPathExtension("wav")
        }

        func removePreparedAudio(for sourceVideoURL: URL) throws {}
    }

    struct SubtitleExporter: SubtitleExportService {
        func export(
            request: SubtitleExportRequest,
            kind: SubtitleExportKind,
            destinationURL: URL
        ) async throws {}

        func exportSRT(
            request: SubtitleExportRequest,
            textMode: SubtitleTextMode,
            destinationURL: URL
        ) async throws {}
    }

    struct FFmpeg: FFmpegService {
        func checkAvailability() async throws -> FFmpegInfo {
            FFmpegInfo(executableURL: URL(fileURLWithPath: "/usr/bin/true"), version: "test")
        }

        func extractAudio(
            from videoURL: URL,
            to outputURL: URL,
            clips: [ExportClipRange]?
        ) async throws -> URL {
            outputURL
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

    struct ScriptGenerator: SubtitleScriptGenerating {
        func generateASS(
            segments: [SubtitleSegment],
            settings: VideoExportSettings
        ) throws -> String { "" }

        func generateVerticalASS(_ request: VerticalSubtitleScriptRequest) -> String { "" }
    }

    struct SubtitleImporter: SubtitleImporting {
        func importSubtitles(from fileURL: URL) async throws -> SubtitleImportPreview {
            throw TestError.expected
        }
    }

    struct ProjectFileService: ProjectFileServicing {
        func exportProject(_ project: Project, to fileURL: URL) throws {}
        func importProject(from fileURL: URL) throws -> Project { throw TestError.expected }
    }

    struct EditTimelineService: EditTimelineEditing {
        func makeInitialTimeline(durationMs: Int) -> EditTimeline { fatalError("Unused") }
        func rippleDeleteRange(timeline: EditTimeline, range: VideoCutRange) throws -> EditTimeline { timeline }
        func splitAt(timeline: EditTimeline, timelineMs: Int) throws -> EditTimeline { timeline }
        func deleteClip(timeline: EditTimeline, clipID: UUID) throws -> EditTimeline { timeline }
        func sourceTime(forTimelineTime timelineMs: Int, in timeline: EditTimeline) -> Int? { nil }
        func clip(atTimelineTime timelineMs: Int, in timeline: EditTimeline) -> TimelineClip? { nil }
        func playbackAdvance(
            sourceTimeMs: Int,
            currentClipID: UUID?,
            lastKnownTimelineMs: Int,
            in timeline: EditTimeline,
            lookaheadMs: Int
        ) -> EditTimelinePlaybackAdvance { .paused }
        func recalculateTimelinePositions(clips: [TimelineClip]) -> EditTimeline { fatalError("Unused") }
    }

    struct MetadataProvider: MediaMetadataProviding {
        func durationMs(for url: URL) async throws -> Int? { 10_000 }
        func videoMetadata(for url: URL) async throws -> VideoMetadata {
            VideoMetadata(width: 1_920, height: 1_080, nominalFrameRate: 30)
        }
    }

    struct WaveformLoader: WaveformLoading {
        func loadWaveform(
            for request: WaveformRequest,
            audioProvider: @escaping WaveformAudioProvider,
            progressHandler: WaveformProgressHandler?
        ) async throws -> [Double] { [0.25, 0.75] }
    }

    struct SpeechProviderResolver: SpeechToTextProviderResolving {
        func resolve(
            configuration: SpeechToTextProviderConfiguration
        ) throws -> any SpeechToTextProvider {
            throw TestError.expected
        }
    }

    static func project(subtitles: [SubtitleSegment]? = nil) -> Project {
        let segment = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 0,
            endMs: 2_000,
            originalText: "Hello",
            translatedText: ""
        )
        return Project(
            id: UUID(),
            name: "Test",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            mediaFile: MediaFile(
                id: UUID(),
                originalURL: URL(fileURLWithPath: "/tmp/test.mp4"),
                fileName: "test.mp4",
                fileExtension: "mp4",
                sizeBytes: 1,
                durationMs: 10_000
            ),
            sourceLanguage: "English",
            targetLanguage: "Russian",
            subtitles: subtitles ?? [segment],
            status: .ready
        )
    }

    @MainActor
    static func appState(
        project: Project,
        repository: Repository = Repository(),
        subtitleExportService: any SubtitleExportService = SubtitleExporter(),
        speakerDiarizationEngine: any SpeakerDiarizationEngine = DiarizationEngine(),
        audioPreparationService: any AudioPreparationService = AudioPreparation(),
        makeFFmpegService: @escaping FFmpegServiceBuilder = { _ in FFmpeg() }
    ) -> AppState {
        AppState(
            recentProjects: [project],
            selectedProject: project,
            settings: .default,
            projectRepository: repository,
            subtitleExportService: subtitleExportService,
            translationService: TranslationService(),
            speakerDiarizationEngine: speakerDiarizationEngine,
            subtitleAlignmentEngine: AlignmentEngine(),
            audioPreparationService: audioPreparationService,
            makeFFmpegService: makeFFmpegService,
            subtitleScriptGenerator: ScriptGenerator(),
            saveSettings: { _ in },
            revealVideoExport: { _ in },
            copyText: { _ in }
        )
    }

    @MainActor
    static func projectViewModel(
        appState: AppState,
        editTimelineService: any EditTimelineEditing = EditTimelineService(),
        speechToTextProviderResolver: any SpeechToTextProviderResolving = SpeechProviderResolver(),
        makeFFmpegService: @escaping FFmpegServiceBuilder = { _ in FFmpeg() },
        projectPreparationWorkflow: (any ProjectPreparationWorkflow)? = nil,
        projectTranscriptionWorkflow: (any ProjectTranscriptionWorkflow)? = nil,
        projectTranslationWorkflow: (any ProjectTranslationWorkflow)? = nil
    ) -> ProjectViewModel {
        let preparationWorkflow = projectPreparationWorkflow
            ?? ApplicationWorkflowAssembly.makeProjectPreparationWorkflow(
                mediaMetadataProvider: MetadataProvider(),
                waveformLoader: WaveformLoader(),
                makeFFmpegService: makeFFmpegService
            )
        let transcriptionWorkflow = projectTranscriptionWorkflow
            ?? ApplicationWorkflowAssembly.makeProjectTranscriptionWorkflow(
                projectRepository: appState.projectRepository,
                speechToTextProviderResolver: speechToTextProviderResolver,
                speakerDiarizationEngine: appState.speakerDiarizationEngine,
                subtitleAlignmentEngine: appState.subtitleAlignmentEngine,
                makeFFmpegService: makeFFmpegService
            )
        let translationWorkflow = projectTranslationWorkflow
            ?? ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
                projectRepository: appState.projectRepository,
                translationService: appState.translationService
            )

        return ProjectViewModel(
            appState: appState,
            dependencies: ProjectViewModelDependencies(
                subtitleImporter: SubtitleImporter(),
                projectFileService: ProjectFileService(),
                editTimelineService: editTimelineService,
                projectPreparationWorkflow: preparationWorkflow,
                projectTranscriptionWorkflow: transcriptionWorkflow,
                projectTranslationWorkflow: translationWorkflow,
                pickSubtitleFile: { nil }
            )
        )
    }
}
