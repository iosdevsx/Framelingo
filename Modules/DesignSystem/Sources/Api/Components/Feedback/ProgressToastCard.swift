import SwiftUI

struct ProgressToastCard: View {
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
