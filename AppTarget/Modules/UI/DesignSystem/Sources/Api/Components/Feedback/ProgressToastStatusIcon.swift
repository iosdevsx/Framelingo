import SwiftUI

struct ProgressToastStatusIcon: View {
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
