import Combine
import ExportFeature
import Foundation
import TranscriptionPipeline
import VideoExport

@MainActor
final class CapabilityActivitySourceAdapter {
    let source: ProductActivitySource

    init(
        transcriptionActivity: any TranscriptionActivityTracking,
        videoExportQueue: any VideoExportQueue
    ) {
        let snapshots = transcriptionActivity.activitySnapshots
            .combineLatest(videoExportQueue.jobSnapshots)
            .map(Self.snapshot)
            .eraseToAnyPublisher()

        source = ProductActivitySource(
            snapshot: { Self.snapshot(transcriptionActivity.activity, videoExportQueue.jobs) },
            snapshots: { snapshots },
            dismiss: { id in
                if let activity = transcriptionActivity.activity,
                   id == "transcription-\(activity.id.uuidString)" {
                    transcriptionActivity.dismiss()
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
        _ transcription: TranscriptionActivity?,
        _ jobs: [VideoExportJob]
    ) -> ProductActivitySnapshot {
        var items: [ProductActivityItem] = []
        if let transcription {
            items.append(ProductActivityItem(
                id: "transcription-\(transcription.id.uuidString)",
                title: transcription.projectName,
                subtitle: transcription.statusText,
                progress: transcription.progress,
                status: transcription.status.productActivityStatus,
                errorMessage: transcription.status == .failed ? transcription.statusText : nil,
                canDismiss: transcription.isFinished
            ))
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

    private static func diagnosticText(for job: VideoExportJob) -> String? {
        let value = [job.errorMessage, job.debugOutput]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\nDebug output:\n")
        return value.isEmpty ? nil : value
    }
}

private extension TranscriptionActivityStatus {
    var productActivityStatus: ProductActivityStatus {
        switch self {
        case .running: .running
        case .succeeded: .succeeded
        case .failed: .failed
        }
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
