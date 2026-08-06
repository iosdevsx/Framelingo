import ProjectFeature
import Subtitles
import SwiftUI

struct ProjectPlaybackToolbarView: View {
    let mode: ProjectWorkspaceMode
    let currentTimeMs: Int
    let durationMs: Int?
    let isPlaying: Bool
    let editRangeStartMs: Int?
    let editRangeEndMs: Int?
    let hasSelectedEditClip: Bool
    let pendingShortStartMs: Int?
    let selectedShortDurationMs: Int?
    let onSeekToStart: () -> Void
    let onTogglePlayback: () -> Void
    let onScrollToPlayhead: () -> Void
    let onRippleDelete: () -> Void
    let onCut: () -> Void
    let onDeleteClip: () -> Void
    let onSetEditRangeStart: () -> Void
    let onSetEditRangeEnd: () -> Void
    let onClearEditRange: () -> Void
    let onSetShortStart: () -> Void
    let onSetShortEnd: () -> Void
    let onClearPendingShortRange: () -> Void
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
            } else if mode == .shorts {
                shortsRangeControls
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
        Button("Set In", action: onSetEditRangeStart)
        Button("Set Out", action: onSetEditRangeEnd)
        Button("Clear Range", action: onClearEditRange)
            .disabled(editRangeStartMs == nil && editRangeEndMs == nil)
        Button("Ripple Delete", role: .destructive, action: onRippleDelete)
            .disabled(editRangeDurationMs < 500)
        Divider()
        Button("Cut", action: onCut)
        Button("Delete Clip", role: .destructive, action: onDeleteClip)
            .disabled(!hasSelectedEditClip)
        if let start = editRangeStartMs, let end = editRangeEndMs {
            Text("Range \(SubtitleTimeFormatter.format(milliseconds: min(start, end))) - \(SubtitleTimeFormatter.format(milliseconds: max(start, end)))")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var editRangeDurationMs: Int {
        guard let start = editRangeStartMs,
              let end = editRangeEndMs else {
            return 0
        }

        return abs(end - start)
    }

    @ViewBuilder
    private var shortsRangeControls: some View {
        Button("Set Start", action: onSetShortStart)
        .help("Edit the selected short when the playhead is inside it; otherwise begin a new short")

        Button("Set End", action: onSetShortEnd)
        .disabled(pendingShortStartMs == nil && selectedShortDurationMs == nil)
        .help("Finish the new short or set the selected short end")

        if let pendingStartMs = pendingShortStartMs {
            Text("New start \(SubtitleTimeFormatter.format(milliseconds: pendingStartMs))")
                .foregroundStyle(.orange)
                .monospacedDigit()

            Button("Clear", action: onClearPendingShortRange)
        } else if let selectedShortDurationMs {
            Text("Duration \(SubtitleTimeFormatter.format(milliseconds: selectedShortDurationMs))")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func durationText(_ durationMs: Int?) -> String {
        guard let durationMs else {
            return "Unknown"
        }

        return SubtitleTimeFormatter.format(milliseconds: durationMs)
    }
}
