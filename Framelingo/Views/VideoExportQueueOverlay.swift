import SwiftUI

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
            status: activity.status.toastStatus,
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
            status: job.status.toastStatus,
            errorMessage: job.errorMessage,
            actions: actions,
            onDismiss: job.isFinished ? { appState.removeVideoExportJob(job) } : nil
        )
    }
}

private struct ProgressToastStack: View {
    let items: [ProgressToastItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(items) { item in
                    ProgressToastCard(item: item)
                }
            }
            .frame(width: 360, alignment: .trailing)
        }
    }
}

private struct ProgressToastCard: View {
    let item: ProgressToastItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressToastStatusIcon(status: item.status, progress: item.progress)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let onDismiss = item.onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .help("Dismiss")
                }
            }

            if let detail = item.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            if item.status == .running {
                if let progress = item.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if item.status == .failed, let errorMessage = item.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }

            if !item.actions.isEmpty {
                HStack {
                    ForEach(item.actions) { action in
                        Button(action.title, action: action.handler)
                    }
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
    }
}

private struct ProgressToastStatusIcon: View {
    let status: ProgressToastStatus
    let progress: Double?

    var body: some View {
        switch status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .running:
            if let progress {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

private struct ProgressToastItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String?
    let progress: Double?
    let status: ProgressToastStatus
    let errorMessage: String?
    let actions: [ProgressToastAction]
    let onDismiss: (() -> Void)?
}

private struct ProgressToastAction: Identifiable {
    let id = UUID()
    let title: String
    let handler: () -> Void
}

private enum ProgressToastStatus {
    case queued
    case running
    case succeeded
    case failed
}

private extension TranscriptionActivityStatus {
    var toastStatus: ProgressToastStatus {
        switch self {
        case .running:
            return .running
        case .succeeded:
            return .succeeded
        case .failed:
            return .failed
        }
    }
}

private extension VideoExportJobStatus {
    var toastStatus: ProgressToastStatus {
        switch self {
        case .queued:
            return .queued
        case .exporting:
            return .running
        case .succeeded:
            return .succeeded
        case .failed:
            return .failed
        }
    }
}
