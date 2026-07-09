import AppKit
import Foundation
import Combine

struct TranscriptionActivity: Identifiable, Equatable {
    var id: UUID
    var projectName: String
    var statusText: String
    var progress: Double?
    var status: TranscriptionActivityStatus

    var isFinished: Bool {
        status == .succeeded || status == .failed
    }
}

enum TranscriptionActivityStatus: Equatable {
    case running
    case succeeded
    case failed
}

@MainActor
final class AppState: ObservableObject {
    @Published var recentProjects: [Project]
    @Published var selectedProject: Project?
    @Published var settings: AppSettings {
        didSet {
            AppSettingsPersistence.save(settings)
        }
    }
    @Published var videoExportJobs: [VideoExportJob] = []
    @Published var transcriptionActivity: TranscriptionActivity?
    let projectRepository: ProjectRepository
    let subtitleExportService: SubtitleExportService
    let speechToTextService: SpeechToTextService
    let translationService: TranslationService
    let ffmpegService: FFmpegService
    let speakerDiarizationEngine: SpeakerDiarizationEngine
    let subtitleAlignmentEngine: SubtitleAlignmentEngine
    let audioPreparationService: AudioPreparationService
    private var videoExportTask: Task<Void, Never>?
    private var videoExportPayloads: [UUID: VideoExportJobPayload] = [:]

    convenience init() {
        let ffmpegService = FFmpegServiceFactory.makeDefaultService(settings: .default)
        self.init(
            projectRepository: FileProjectRepository(),
            subtitleExportService: FileSubtitleExportService(),
            speechToTextService: SpeechToTextService(provider: MockSpeechToTextProvider()),
            translationService: TranslationService(provider: MockTranslationProvider()),
            ffmpegService: ffmpegService,
            speakerDiarizationEngine: FluidAudioSpeakerDiarizationEngine(),
            subtitleAlignmentEngine: WordLevelSubtitleAlignmentEngine(),
            audioPreparationService: FFmpegAudioPreparationService(ffmpegService: ffmpegService)
        )
    }

    init(
        projectRepository: ProjectRepository,
        subtitleExportService: SubtitleExportService,
        speechToTextService: SpeechToTextService,
        translationService: TranslationService,
        ffmpegService: FFmpegService,
        speakerDiarizationEngine: SpeakerDiarizationEngine = MockSpeakerDiarizationEngine(),
        subtitleAlignmentEngine: SubtitleAlignmentEngine = PassthroughSubtitleAlignmentEngine(),
        audioPreparationService: AudioPreparationService = PassthroughAudioPreparationService()
    ) {
        let project = MockData.project
        let settings = AppSettingsPersistence.load()

        self.projectRepository = projectRepository
        self.subtitleExportService = subtitleExportService
        self.speechToTextService = speechToTextService
        self.translationService = translationService
        self.ffmpegService = ffmpegService
        self.speakerDiarizationEngine = speakerDiarizationEngine
        self.subtitleAlignmentEngine = subtitleAlignmentEngine
        self.audioPreparationService = audioPreparationService
        recentProjects = [project]
        selectedProject = project
        self.settings = settings
    }

    init(
        recentProjects: [Project],
        selectedProject: Project?,
        settings: AppSettings,
        projectRepository: ProjectRepository,
        subtitleExportService: SubtitleExportService,
        speechToTextService: SpeechToTextService,
        translationService: TranslationService,
        ffmpegService: FFmpegService,
        speakerDiarizationEngine: SpeakerDiarizationEngine = MockSpeakerDiarizationEngine(),
        subtitleAlignmentEngine: SubtitleAlignmentEngine = PassthroughSubtitleAlignmentEngine(),
        audioPreparationService: AudioPreparationService = PassthroughAudioPreparationService()
    ) {
        self.projectRepository = projectRepository
        self.subtitleExportService = subtitleExportService
        self.speechToTextService = speechToTextService
        self.translationService = translationService
        self.ffmpegService = ffmpegService
        self.speakerDiarizationEngine = speakerDiarizationEngine
        self.subtitleAlignmentEngine = subtitleAlignmentEngine
        self.audioPreparationService = audioPreparationService
        self.recentProjects = recentProjects
        self.selectedProject = selectedProject
        self.settings = settings
    }

    deinit {
        videoExportTask?.cancel()
    }

    func enqueueVideoExport(project: Project, settings: VideoExportSettings, outputURL: URL) {
        let job = VideoExportJob(
            id: UUID(),
            projectName: project.displayName,
            outputURL: outputURL,
            status: .queued,
            statusText: "Queued",
            progress: nil,
            errorMessage: nil,
            debugOutput: nil
        )

        videoExportJobs.insert(job, at: 0)
        videoExportPayloads[job.id] = VideoExportJobPayload(
            project: project,
            settings: settings
        )
        startNextVideoExportIfNeeded()
    }

    func revealVideoExportInFinder(_ job: VideoExportJob) {
        NSWorkspace.shared.activateFileViewerSelecting([job.outputURL])
    }

    func removeVideoExportJob(_ job: VideoExportJob) {
        videoExportJobs.removeAll { $0.id == job.id && $0.isFinished }
    }

    func copyVideoExportDebugOutput(_ job: VideoExportJob) {
        let text = [
            job.errorMessage,
            job.debugOutput
        ]
        .compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }
        .joined(separator: "\n\nDebug output:\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func startTranscriptionActivity(projectName: String) {
        transcriptionActivity = TranscriptionActivity(
            id: UUID(),
            projectName: projectName,
            statusText: "Extracting audio...",
            progress: 0,
            status: .running
        )
    }

    func updateTranscriptionActivity(statusText: String, progress: Double?) {
        guard transcriptionActivity != nil else {
            return
        }

        transcriptionActivity?.statusText = statusText
        if let progress {
            transcriptionActivity?.progress = min(max(progress, 0), 1)
        }
    }

    func finishTranscriptionActivity(success: Bool, message: String? = nil) {
        guard transcriptionActivity != nil else {
            return
        }

        transcriptionActivity?.status = success ? .succeeded : .failed
        transcriptionActivity?.progress = success ? 1 : transcriptionActivity?.progress
        transcriptionActivity?.statusText = message ?? (success ? "Transcription complete" : "Transcription failed")
    }

    func dismissTranscriptionActivity() {
        transcriptionActivity = nil
    }

    func closeSelectedProject() {
        if let selectedProject {
            do {
                try audioPreparationService.removePreparedAudio(for: selectedProject.mediaFile.originalURL)
            } catch {
                assertionFailure("Failed to remove prepared audio cache: \(error.localizedDescription)")
            }
        }
        selectedProject = nil
    }

    func deleteProject(_ project: Project) async throws {
        try audioPreparationService.removePreparedAudio(for: project.mediaFile.originalURL)
        try await projectRepository.deleteProject(id: project.id)
        recentProjects.removeAll { $0.id == project.id }
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
    }

    private func startNextVideoExportIfNeeded() {
        guard videoExportTask == nil,
              let jobIndex = videoExportJobs.lastIndex(where: { $0.status == .queued }) else {
            return
        }

        var job = videoExportJobs[jobIndex]
        guard let payload = videoExportPayloads[job.id] else {
            job.status = .failed
            job.statusText = "Export failed"
            job.errorMessage = "Video export request was lost."
            videoExportJobs[jobIndex] = job
            startNextVideoExportIfNeeded()
            return
        }

        let jobID = job.id
        let outputURL = job.outputURL
        let ffmpegService = FFmpegServiceFactory.makeDefaultService(settings: settings)
        let fileManager = FileManager.default
        let assSubtitleExportService = ASSSubtitleExportService()

        job.status = .exporting
        job.statusText = "Preparing export..."
        job.progress = 0
        videoExportJobs[jobIndex] = job

        let projectSnapshot = payload.project
        let exportSettings = payload.settings
        let durationMs = Self.exportDurationMs(for: projectSnapshot)

        let appState = self
        // Detached: long-running FFmpeg export/IO must outlive and ignore the
        // triggering UI task's priority and cancellation — the export queue
        // continues even if the view that queued it disappears.
        videoExportTask = Task.detached(priority: .utility) {
            do {
                try await VideoExportWorker.run(
                    project: projectSnapshot,
                    settings: exportSettings,
                    outputURL: outputURL,
                    ffmpegService: ffmpegService,
                    assSubtitleExportService: assSubtitleExportService,
                    fileManager: fileManager,
                    statusHandler: { status in
                        await appState.updateVideoExportJob(jobID, statusText: status)
                    },
                    progressHandler: { processedTimeMs in
                        guard let durationMs, durationMs > 0 else {
                            return
                        }

                        let progress = min(max(Double(processedTimeMs) / Double(durationMs), 0), 0.995)
                        await appState.updateVideoExportJob(jobID, progress: progress)
                    }
                )

                await appState.finishVideoExportJob(jobID, result: .success(outputURL))
            } catch {
                let failure = VideoExportWorker.failureDetails(for: error)
                await appState.finishVideoExportJob(jobID, result: .failure(failure))
            }
        }
    }

    // Safe: nonisolated — reads only its `project` parameter, never AppState's
    // @Published or instance state, so it can be computed without a MainActor hop.
    private static nonisolated func exportDurationMs(for project: Project) -> Int? {
        if let timeline = project.editTimeline, timeline.hasVirtualCuts, timeline.totalDurationMs > 0 {
            return timeline.totalDurationMs
        }

        if let durationMs = project.mediaFile.durationMs, durationMs > 0 {
            return durationMs
        }

        let subtitleDurationMs = project.subtitles.map(\.endMs).max() ?? 0
        return subtitleDurationMs > 0 ? subtitleDurationMs : nil
    }

    private func updateVideoExportJob(_ id: UUID, statusText: String) {
        guard let index = videoExportJobs.firstIndex(where: { $0.id == id }) else {
            return
        }

        videoExportJobs[index].statusText = statusText
    }

    private func updateVideoExportJob(_ id: UUID, progress: Double) {
        guard let index = videoExportJobs.firstIndex(where: { $0.id == id }) else {
            return
        }

        let oldProgress = videoExportJobs[index].progress ?? 0
        guard progress >= oldProgress,
              progress - oldProgress >= 0.005 || progress >= 0.995 else {
            return
        }

        videoExportJobs[index].progress = progress
        videoExportJobs[index].statusText = "Exporting video... \(Int((progress * 100).rounded()))%"
    }

    private func finishVideoExportJob(_ id: UUID, result: Result<URL, VideoExportFailure>) {
        guard let index = videoExportJobs.firstIndex(where: { $0.id == id }) else {
            videoExportTask = nil
            startNextVideoExportIfNeeded()
            return
        }

        switch result {
        case .success:
            videoExportJobs[index].status = .succeeded
            videoExportJobs[index].statusText = "Export complete"
            videoExportJobs[index].progress = 1
        case .failure(let failure):
            videoExportJobs[index].status = .failed
            videoExportJobs[index].statusText = "Export failed"
            videoExportJobs[index].errorMessage = failure.message
            videoExportJobs[index].debugOutput = failure.debugOutput
        }

        videoExportPayloads[id] = nil
        videoExportTask = nil
        startNextVideoExportIfNeeded()
    }
}

private enum AppSettingsPersistence {
    private static let key = "Framelingo.AppSettings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }

        return settings
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct VideoExportJobPayload {
    var project: Project
    var settings: VideoExportSettings
}

private struct VideoExportFailure: Error, Equatable {
    var message: String
    var debugOutput: String?
}

private enum VideoExportWorker {
    static func run(
        project: Project,
        settings: VideoExportSettings,
        outputURL: URL,
        ffmpegService: FFmpegService,
        assSubtitleExportService: ASSSubtitleExportService,
        fileManager: FileManager,
        statusHandler: @escaping @Sendable (String) async -> Void,
        progressHandler: @escaping FFmpegProgressHandler
    ) async throws {
        guard !project.subtitles.isEmpty else {
            throw ExportVideoError.noSubtitles
        }

        guard fileManager.fileExists(atPath: project.mediaFile.originalURL.path) else {
            throw ExportVideoError.mediaFileMissing
        }

        let clips: [ExportClipRange]?
        do {
            clips = try ExportClipPlanResolver.clips(for: project)
        } catch {
            throw ExportVideoError.editTimelineEmpty
        }

        await statusHandler("Generating subtitles...")
        let workingDirectoryURL = try temporaryExportWorkingDirectory(
            projectID: project.id,
            fileManager: fileManager
        )
        let subtitlesURL = workingDirectoryURL.appendingPathComponent("subtitles.ass")

        do {
            let ass = try assSubtitleExportService.generateASS(
                segments: project.subtitles,
                settings: settings
            )
            try Data(ass.utf8).write(to: subtitlesURL, options: .atomic)
        } catch {
            throw ExportVideoError.assGenerationFailed
        }

        await statusHandler("Exporting video...")
        _ = try await ffmpegService.burnSubtitles(
            videoURL: project.mediaFile.originalURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: settings,
            clips: clips,
            progressHandler: progressHandler
        )
    }

    static func failureDetails(for error: Error) -> VideoExportFailure {
        switch error {
        case FFmpegServiceError.notFound:
            return VideoExportFailure(
                message: "Embedded FFmpegKit is unavailable, and no FFmpeg executable was found.",
                debugOutput: nil
            )
        case FFmpegServiceError.processFailed(_, _, let standardError):
            let output = standardError.isEmpty ? "FFmpeg did not return stderr output." : standardError
            return VideoExportFailure(
                message: userFacingFFmpegFailureMessage(for: output),
                debugOutput: output
            )
        case let exportError as ExportVideoError:
            return VideoExportFailure(
                message: exportError.errorDescription ?? "Video export failed.",
                debugOutput: nil
            )
        case let localizedError as LocalizedError:
            return VideoExportFailure(
                message: localizedError.errorDescription ?? "Video export failed.",
                debugOutput: nil
            )
        default:
            return VideoExportFailure(
                message: "Video export failed.",
                debugOutput: nil
            )
        }
    }

    private static func temporaryExportWorkingDirectory(
        projectID: UUID,
        fileManager: FileManager
    ) throws -> URL {
        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("VideoExport-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private static func userFacingFFmpegFailureMessage(for output: String) -> String {
        if output.contains("No such filter: 'ass'") || output.contains("No such filter: ass") {
            return "Embedded FFmpegKit was built without the ASS subtitle filter. Rebuild FFmpegKit with libass enabled."
        }

        if output.contains("Unknown encoder 'libx264'") || output.contains("Encoder not found") {
            return "Embedded FFmpegKit was built without the H.264 encoder. Rebuild FFmpegKit with libx264 enabled."
        }

        return "Video export failed."
    }
}
