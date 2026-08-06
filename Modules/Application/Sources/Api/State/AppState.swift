import Combine
import Foundation
import Media
import Project
import Settings
import Shorts
import SpeakerAnalysis
import Subtitles
import Translation
import VideoRendering

@MainActor
public final class AppState: ObservableObject {
    @Published public var selectedProject: Project?
    @Published public var videoExportJobs: [VideoExportJob] = []
    @Published public var transcriptionActivity: TranscriptionActivity?

    public let subtitleExportService: any SubtitleExportService
    public let translationService: any TranslationOrchestrating
    public let speakerDiarizationEngine: any SpeakerDiarizationEngine
    public let subtitleAlignmentEngine: any SubtitleAlignmentEngine
    public let audioPreparationService: any AudioPreparationService

    private let makeFFmpegService: FFmpegServiceBuilder
    private let subtitleScriptGenerator: any SubtitleScriptGenerating
    private let fileManager: FileManager
    private let currentSettings: @MainActor () -> AppSettings
    private let revealVideoExport: @MainActor (URL) -> Void
    private let copyText: @MainActor (String) -> Void
    private var videoExportTask: Task<Void, Never>?
    private var videoExportPayloads: [UUID: VideoExportJobPayload] = [:]

    public init(
        selectedProject: Project?,
        subtitleExportService: any SubtitleExportService,
        translationService: any TranslationOrchestrating,
        speakerDiarizationEngine: any SpeakerDiarizationEngine,
        subtitleAlignmentEngine: any SubtitleAlignmentEngine,
        audioPreparationService: any AudioPreparationService,
        makeFFmpegService: @escaping FFmpegServiceBuilder,
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        fileManager: FileManager = .default,
        currentSettings: @escaping @MainActor () -> AppSettings,
        revealVideoExport: @escaping @MainActor (URL) -> Void,
        copyText: @escaping @MainActor (String) -> Void
    ) {
        self.selectedProject = selectedProject
        self.subtitleExportService = subtitleExportService
        self.translationService = translationService
        self.speakerDiarizationEngine = speakerDiarizationEngine
        self.subtitleAlignmentEngine = subtitleAlignmentEngine
        self.audioPreparationService = audioPreparationService
        self.makeFFmpegService = makeFFmpegService
        self.subtitleScriptGenerator = subtitleScriptGenerator
        self.fileManager = fileManager
        self.currentSettings = currentSettings
        self.revealVideoExport = revealVideoExport
        self.copyText = copyText
    }

    deinit {
        videoExportTask?.cancel()
    }

    public func enqueueVideoExport(
        project: Project,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        outputURL: URL
    ) {
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
            settings: settings,
            sourceInfo: sourceInfo
        )
        startNextVideoExportIfNeeded()
    }

    /// Enqueues one export job per short into the shared queue. Shorts whose
    /// range resolves to no content become immediately failed jobs; the rest
    /// export sequentially and independently.
    public func enqueueShortsExport(
        project: Project,
        shorts: [ShortDefinition],
        sourceInfo: VideoSourceInfo?,
        destinationDirectory: URL
    ) {
        let orderedShorts = shorts.sorted { $0.startMs < $1.startMs }
        guard !orderedShorts.isEmpty else {
            return
        }

        let shortsSettings = project.shortsExportSettings
        // Encoding comes from the project's export settings; resolution and
        // frame rate are owned by the vertical reframe target instead.
        var encodingSettings = project.videoExportSettings
        encodingSettings.resolution = .original
        encodingSettings.frameRate = .original

        var reservedPaths: Set<String> = []

        for (position, short) in orderedShorts.enumerated() {
            let baseName = ShortsFilenameTemplate.baseName(
                template: shortsSettings.filenameTemplate,
                projectName: project.displayName,
                index: position + 1,
                totalCount: orderedShorts.count,
                shortTitle: short.title
            )
            let outputURL = ShortsFilenameTemplate.availableURL(
                in: destinationDirectory,
                baseName: baseName,
                fileExtension: "mp4",
                reservedPaths: reservedPaths
            )
            reservedPaths.insert(outputURL.path)

            var job = VideoExportJob(
                id: UUID(),
                projectName: "\(project.displayName) — \(short.title)",
                outputURL: outputURL,
                status: .queued,
                statusText: "Queued",
                progress: nil,
                errorMessage: nil,
                debugOutput: nil
            )

            do {
                let clips = try ShortsClipPlanner.clips(for: short, editTimeline: project.editTimeline)
                let plan = ShortExportPlan(
                    clips: clips,
                    subtitles: ShortsClipPlanner.localizedSubtitles(project.subtitles, for: short),
                    subtitleStyle: shortsSettings.subtitleStyle,
                    platform: short.effectivePlatform(default: shortsSettings.platform),
                    reframe: ShortsReframeMapper.plan(
                        for: short,
                        defaults: shortsSettings,
                        sourceInfo: sourceInfo
                    ),
                    hookText: short.trimmedHookText,
                    hookFontSize: shortsSettings.hookFontSize,
                    durationMs: short.durationMs,
                    burnSubtitlesIntoVideo: shortsSettings.burnSubtitlesIntoVideo,
                    writeSRTSidecar: shortsSettings.exportSRTSidecar
                )
                videoExportJobs.insert(job, at: 0)
                videoExportPayloads[job.id] = VideoExportJobPayload(
                    project: project,
                    settings: encodingSettings,
                    sourceInfo: sourceInfo,
                    shortPlan: plan
                )
            } catch {
                job.status = .failed
                job.statusText = "Export failed"
                job.errorMessage = ApplicationExportError.editTimelineEmpty.errorDescription
                videoExportJobs.insert(job, at: 0)
            }
        }

        startNextVideoExportIfNeeded()
    }

    public func revealVideoExportInFinder(_ job: VideoExportJob) {
        revealVideoExport(job.outputURL)
    }

    public func removeVideoExportJob(_ job: VideoExportJob) {
        videoExportJobs.removeAll { $0.id == job.id && $0.isFinished }
    }

    public func copyVideoExportDebugOutput(_ job: VideoExportJob) {
        let text = [
            job.errorMessage,
            job.debugOutput
        ]
        .compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }
        .joined(separator: "\n\nDebug output:\n")

        copyText(text)
    }

    public func startTranscriptionActivity(projectName: String) {
        transcriptionActivity = TranscriptionActivity(
            id: UUID(),
            projectName: projectName,
            statusText: "Extracting audio...",
            progress: 0,
            status: .running
        )
    }

    public func updateTranscriptionActivity(statusText: String, progress: Double?) {
        guard transcriptionActivity != nil else {
            return
        }

        transcriptionActivity?.statusText = statusText
        if let progress {
            transcriptionActivity?.progress = min(max(progress, 0), 1)
        }
    }

    public func finishTranscriptionActivity(success: Bool, message: String? = nil) {
        guard transcriptionActivity != nil else {
            return
        }

        transcriptionActivity?.status = success ? .succeeded : .failed
        transcriptionActivity?.progress = success ? 1 : transcriptionActivity?.progress
        transcriptionActivity?.statusText = message ?? (success ? "Transcription complete" : "Transcription failed")
    }

    public func dismissTranscriptionActivity() {
        transcriptionActivity = nil
    }

    public func closeSelectedProject() {
        if let selectedProject {
            do {
                try audioPreparationService.removePreparedAudio(for: selectedProject.mediaFile.originalURL)
            } catch {
                assertionFailure("Failed to remove prepared audio cache: \(error.localizedDescription)")
            }
        }
        selectedProject = nil
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
        let ffmpegService = makeFFmpegService(currentSettings())
        let fileManager = fileManager
        let subtitleScriptGenerator = subtitleScriptGenerator
        let subtitleExportService = subtitleExportService

        job.status = .exporting
        job.statusText = "Preparing export..."
        job.progress = 0
        videoExportJobs[jobIndex] = job

        let projectSnapshot = payload.project
        let exportSettings = payload.settings
        let exportSourceInfo = payload.sourceInfo
        let shortPlan = payload.shortPlan
        let durationMs = shortPlan?.durationMs ?? Self.exportDurationMs(for: projectSnapshot)

        let appState = self
        // Detached: long-running FFmpeg export/IO must outlive and ignore the
        // triggering UI task's priority and cancellation — the export queue
        // continues even if the view that queued it disappears.
        videoExportTask = Task.detached(priority: .utility) {
            do {
                try await VideoExportWorker.run(
                    project: projectSnapshot,
                    settings: exportSettings,
                    sourceInfo: exportSourceInfo,
                    shortPlan: shortPlan,
                    outputURL: outputURL,
                    ffmpegService: ffmpegService,
                    subtitleScriptGenerator: subtitleScriptGenerator,
                    subtitleExportService: subtitleExportService,
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
        if project.hasEditedTimeline, let timeline = project.editTimeline, timeline.totalDurationMs > 0 {
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
