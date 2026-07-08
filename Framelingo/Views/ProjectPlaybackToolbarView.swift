import SwiftUI

struct ProjectPlaybackToolbarView: View {
    let mode: ProjectWorkspaceMode
    let currentTimeMs: Int
    let durationMs: Int?
    let isPlaying: Bool
    @ObservedObject var viewModel: ProjectViewModel
    let onSeekToStart: () -> Void
    let onTogglePlayback: () -> Void
    let onScrollToPlayhead: () -> Void
    let onRippleDelete: () -> Void
    let onCut: () -> Void
    let onDeleteClip: () -> Void
    let onZoomOut: () -> Void
    let onZoomIn: () -> Void
    let onFitZoom: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if mode == .edit {
                Button {
                    onSeekToStart()
                } label: {
                    Image(systemName: "backward.end.fill").frame(width: 16)
                }
            }

            Button {
                onTogglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill").frame(width: 16)
            }

            Text(SubtitleTimeFormatter.format(milliseconds: currentTimeMs))
                .monospacedDigit()

            Text("/ \(durationText(durationMs))")
                .foregroundStyle(.secondary)

            Divider().frame(height: 16)

            if mode == .edit {
                editClipControls
            } else {
                Button("Scroll to Playhead", action: onScrollToPlayhead)
            }

            Spacer()

            Button {
                onZoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")

            Button {
                onZoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")

            Button("Fit", action: onFitZoom)
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(red: 0.11, green: 0.115, blue: 0.13))
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var editClipControls: some View {
        Button("Set In") { viewModel.setEditRangeStartFromCurrentTime() }
        Button("Set Out") { viewModel.setEditRangeEndFromCurrentTime() }
        Button("Clear Range") { viewModel.clearEditRange() }
            .disabled(viewModel.editRangeStartMs == nil && viewModel.editRangeEndMs == nil)
        Button("Ripple Delete", role: .destructive, action: onRippleDelete)
            .disabled(editRangeDurationMs < 500)
        Divider()
        Button("Cut", action: onCut)
        Button("Delete Clip", role: .destructive, action: onDeleteClip)
            .disabled(viewModel.editModeSelectedClipID == nil)
        if let start = viewModel.editRangeStartMs, let end = viewModel.editRangeEndMs {
            Text("Range \(SubtitleTimeFormatter.format(milliseconds: min(start, end))) - \(SubtitleTimeFormatter.format(milliseconds: max(start, end)))")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var editRangeDurationMs: Int {
        guard let start = viewModel.editRangeStartMs,
              let end = viewModel.editRangeEndMs else {
            return 0
        }

        return abs(end - start)
    }

    private func durationText(_ durationMs: Int?) -> String {
        guard let durationMs else {
            return "Unknown"
        }

        return SubtitleTimeFormatter.format(milliseconds: durationMs)
    }
}
