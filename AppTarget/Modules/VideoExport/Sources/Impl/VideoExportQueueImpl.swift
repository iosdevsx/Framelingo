import Combine
import Foundation
import Shorts
import VideoExport
import VideoRendering

@MainActor
final class VideoExportQueueImpl: VideoExportQueue {
    private(set) var jobs: [VideoExport.VideoExportJob] = [] {
        didSet { snapshots.send(jobs) }
    }
    var jobSnapshots: AnyPublisher<[VideoExport.VideoExportJob], Never> {
        snapshots.eraseToAnyPublisher()
    }

    private let snapshots = CurrentValueSubject<[VideoExport.VideoExportJob], Never>([])
    private let worker: VideoExportWorker
    private let makeFFmpegService: @MainActor () -> any FFmpegService
    private var requests: [UUID: VideoExportRequest] = [:]
    private var pendingIDs: [UUID] = []
    private var activeTask: Task<Void, Never>?

    init(
        worker: VideoExportWorker,
        makeFFmpegService: @escaping @MainActor () -> any FFmpegService
    ) {
        self.worker = worker
        self.makeFFmpegService = makeFFmpegService
    }

    deinit {
        activeTask?.cancel()
    }

    func enqueue(_ request: VideoExportRequest) {
        let job = VideoExport.VideoExportJob(
            id: request.id,
            projectName: request.projectName,
            outputURL: request.outputURL,
            status: .queued,
            statusText: "Queued",
            progress: nil
        )
        accept(job, request: request)
    }

    func accept(
        _ job: VideoExport.VideoExportJob,
        request: VideoExportRequest?
    ) {
        jobs.insert(job, at: 0)
        if let request {
            requests[job.id] = request
        }
        pendingIDs.append(job.id)
        startNextIfNeeded()
    }

    func enqueue(_ batch: ShortsVideoExportBatchRequest) {
        for item in batch.items {
            switch item.outcome {
            case .valid(let plan):
                enqueue(.short(ShortVideoExportRequest(
                    id: item.id,
                    projectID: batch.projectID,
                    projectName: item.displayName,
                    mediaURL: batch.mediaURL,
                    settings: item.encodingSettings,
                    sourceInfo: item.sourceInfo,
                    outputURL: item.outputURL,
                    plan: plan,
                    speakerLabels: batch.speakerLabels,
                    speakerExportOptions: batch.speakerExportOptions
                )))
            case .invalid(let planningFailure):
                jobs.insert(VideoExport.VideoExportJob(
                    id: item.id,
                    projectName: item.displayName,
                    outputURL: item.outputURL,
                    status: .failed,
                    statusText: "Export failed",
                    progress: nil,
                    failure: VideoExportFailure(
                        code: .emptyTimeline,
                        message: planningFailure.errorDescription ?? "The Short cannot be exported."
                    )
                ), at: 0)
            }
        }
    }

    func removeFinishedJob(id: UUID) {
        jobs.removeAll { $0.id == id && $0.isFinished }
    }

    private func startNextIfNeeded() {
        guard activeTask == nil, !pendingIDs.isEmpty else { return }
        let id = pendingIDs.removeFirst()
        guard let request = requests[id] else {
            finish(
                id: id,
                result: .failure(VideoExportFailure(
                    code: .lostRequest,
                    message: "Video export request was lost."
                ))
            )
            return
        }

        update(id: id) { job in
            job.status = .preparing
            job.statusText = "Preparing export..."
            job.progress = 0
        }
        let ffmpegService = makeFFmpegService()
        let worker = self.worker
        activeTask = Task { [weak self, worker] in
            let result = await worker.run(
                request: request,
                ffmpegService: ffmpegService,
                events: { [weak self] event in
                    await self?.receive(event, for: id, durationMs: request.durationMs)
                }
            )
            self?.finish(id: id, result: result)
        }
    }

    private func receive(_ event: VideoExportWorkerEvent, for id: UUID, durationMs: Int?) {
        switch event {
        case .status(let status, let text):
            update(id: id) { job in
                job.status = status
                job.statusText = text
            }
        case .progress(let processedTimeMs):
            guard let durationMs, durationMs > 0 else { return }
            let progress = min(max(Double(processedTimeMs) / Double(durationMs), 0), 0.995)
            update(id: id) { job in
                let oldProgress: Double = job.progress ?? 0
                guard progress >= oldProgress,
                      progress - oldProgress >= 0.005 || progress >= 0.995 else {
                    return
                }
                job.progress = progress
                job.statusText = "Exporting video... \(Int((progress * 100).rounded()))%"
            }
        }
    }

    private func finish(id: UUID, result: Result<Void, VideoExportFailure>) {
        update(id: id) { job in
            switch result {
            case .success:
                job.status = .succeeded
                job.statusText = "Export complete"
                job.progress = 1
            case .failure(let failure):
                job.status = .failed
                job.statusText = "Export failed"
                job.failure = failure
            }
        }
        requests[id] = nil
        activeTask = nil
        startNextIfNeeded()
    }

    private func update(id: UUID, mutation: (inout VideoExport.VideoExportJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutation(&jobs[index])
    }
}
