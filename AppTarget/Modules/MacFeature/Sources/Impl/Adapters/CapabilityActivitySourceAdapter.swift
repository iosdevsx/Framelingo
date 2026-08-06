import Combine
import ExportFeature
import Foundation
import ProjectSession
import TranscriptionPipeline
import VideoExport

@MainActor
final class CapabilityActivitySourceAdapter {
    let source: ProductActivitySource

    init(
        session: any ProjectSessionWorkspace,
        videoExportQueue: any VideoExportQueue
    ) {
        let snapshots = session.snapshots
            .combineLatest(videoExportQueue.jobSnapshots)
            .map(Self.snapshot)
            .eraseToAnyPublisher()

        source = ProductActivitySource(
            snapshot: { Self.snapshot(session.snapshot, videoExportQueue.jobs) },
            snapshots: { snapshots },
            dismiss: { id in
                if id.hasPrefix("transcription-") {
                    session.clearTranscriptionState()
                    return
                }
                guard let job = videoExportQueue.jobs.first(where: {
                    id == "video-export-\($0.id.uuidString)"
                }) else { return }
                videoExportQueue.removeFinishedJob(id: job.id)
            }
        )
    }

    private static func snapshot(
        _ session: ProjectSessionSnapshot,
        _ jobs: [VideoExportJob]
    ) -> ProductActivitySnapshot {
        var items: [ProductActivityItem] = []
        if let project = session.project,
           let transcription = transcriptionItem(
                state: session.effects.transcription,
                projectID: project.id,
                projectName: project.displayName
           ) {
            items.append(transcription)
        }
        items.append(contentsOf: jobs.map { job in
            ProductActivityItem(
                id: "video-export-\(job.id.uuidString)",
                title: job.projectName,
                subtitle: job.statusText,
                detail: job.outputURL.path,
                progress: job.progress,
                status: job.status.productActivityStatus,
                errorMessage: job.errorMessage,
                outputURL: job.status == .succeeded ? job.outputURL : nil,
                diagnosticText: diagnosticText(for: job),
                canDismiss: job.isFinished
            )
        })
        return ProductActivitySnapshot(items: items)
    }

    private static func transcriptionItem(
        state: ProjectSessionTranscriptionState,
        projectID: UUID,
        projectName: String
    ) -> ProductActivityItem? {
        let id = "transcription-\(projectID.uuidString)"
        switch state {
        case .idle:
            return nil
        case .running(let progress):
            return ProductActivityItem(
                id: id,
                title: projectName,
                subtitle: progress.map(status(for:)) ?? "Preparing transcription...",
                progress: progress?.fractionCompleted,
                status: .running,
                canDismiss: false
            )
        case .completed(let warning):
            let message = completionMessage(for: warning)
            return ProductActivityItem(
                id: id,
                title: projectName,
                subtitle: message ?? "Transcription complete",
                progress: 1,
                status: .succeeded,
                canDismiss: true
            )
        case .failed(let failure):
            let message = failure.diagnostic ?? "Transcription failed."
            return ProductActivityItem(
                id: id,
                title: projectName,
                subtitle: message,
                progress: nil,
                status: .failed,
                errorMessage: message,
                diagnosticText: failure.diagnostic,
                canDismiss: true
            )
        }
    }

    private static func status(for progress: TranscriptionPipelineProgress) -> String {
        if let detail = progress.providerDetail?.trimmingCharacters(in: .whitespacesAndNewlines),
           !detail.isEmpty { return detail }
        return switch progress.phase {
        case .extractingAudio: "Extracting audio..."
        case .transcribing: "Transcribing audio..."
        case .analyzingSpeakers: "Analyzing speakers..."
        case .aligningSubtitles: "Aligning subtitles..."
        }
    }

    private static func completionMessage(for warning: TranscriptionPipelineWarning?) -> String? {
        guard case .speakerAnalysisUnavailable(let providerDetail) = warning else { return nil }
        let message = "Transcription complete. Speaker analysis failed; subtitle timings were not refined."
        let detail = providerDetail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return detail.isEmpty ? message : "\(message) \(detail)"
    }

    private static func diagnosticText(for job: VideoExportJob) -> String? {
        let value = [job.errorMessage, job.debugOutput]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\nDebug output:\n")
        return value.isEmpty ? nil : value
    }
}

private extension VideoExportJobStatus {
    var productActivityStatus: ProductActivityStatus {
        switch self {
        case .queued, .preparing, .exporting, .writingSidecar: .running
        case .succeeded: .succeeded
        case .failed: .failed
        }
    }
}
