import Application
import DesignSystem
import SwiftUI
import VideoRendering

struct ActivityToastOverlay: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ProgressToastStack(items: toastItems)
    }

    private var toastItems: [ProgressToastItem] {
        var items: [ProgressToastItem] = []

        if let activity = appState.transcriptionActivity {
            items.append(transcriptionToastItem(activity))
        }

        items.append(contentsOf: appState.videoExportJobs.prefix(3).map(videoExportToastItem))
        return items
    }

    private func transcriptionToastItem(_ activity: TranscriptionActivity) -> ProgressToastItem {
        ProgressToastItem(
            id: "transcription-\(activity.id.uuidString)",
            title: activity.projectName,
            subtitle: activity.statusText,
            detail: nil,
            progress: activity.progress,
            status: activity.status.progressToastStatus,
            errorMessage: activity.status == .failed ? activity.statusText : nil,
            actions: [],
            onDismiss: activity.isFinished ? { appState.dismissTranscriptionActivity() } : nil
        )
    }

    private func videoExportToastItem(_ job: VideoExportJob) -> ProgressToastItem {
        var actions: [ProgressToastAction] = []

        if job.status == .succeeded {
            actions.append(
                ProgressToastAction(title: "Reveal in Finder") {
                    appState.revealVideoExportInFinder(job)
                }
            )
        }

        if job.debugOutput != nil {
            actions.append(
                ProgressToastAction(title: "Copy Debug") {
                    appState.copyVideoExportDebugOutput(job)
                }
            )
        }

        return ProgressToastItem(
            id: "video-export-\(job.id.uuidString)",
            title: job.projectName,
            subtitle: job.statusText,
            detail: job.outputURL.path,
            progress: job.progress,
            status: job.status.progressToastStatus,
            errorMessage: job.errorMessage,
            actions: actions,
            onDismiss: job.isFinished ? { appState.removeVideoExportJob(job) } : nil
        )
    }
}
