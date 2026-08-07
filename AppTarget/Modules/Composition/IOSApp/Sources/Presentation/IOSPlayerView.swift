import AVKit
import PlayerFeature
import Subtitles
import SwiftUI

struct IOSPlayerView: View {
    let request: ProjectVideoPreviewRequest

    private var durationMs: Int {
        max(request.state.project.mediaFile.durationMs ?? 0, 1)
    }

    private var currentSubtitle: SubtitleSegment? {
        request.state.project.subtitles.first {
            request.state.currentTimeMs >= $0.startMs && request.state.currentTimeMs < $0.endMs
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            VideoPlayer(player: request.state.player) {
                if let currentSubtitle {
                    Text(currentSubtitle.hasTranslation
                         ? currentSubtitle.translatedText
                         : currentSubtitle.originalText)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.72), in: .rect(cornerRadius: 8))
                        .padding()
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .background(.black)
            .clipShape(.rect(cornerRadius: 12))

            HStack(spacing: 12) {
                Button(
                    request.state.isPlaying ? "Pause" : "Play",
                    systemImage: request.state.isPlaying ? "pause.fill" : "play.fill",
                    action: request.actions.togglePlayback
                )
                .labelStyle(.iconOnly)
                .accessibilityLabel(request.state.isPlaying ? "Pause video" : "Play video")

                Slider(
                    value: Binding(
                        get: { Double(request.state.currentTimeMs) },
                        set: { request.actions.seek(to: Int($0.rounded())) }
                    ),
                    in: 0...Double(durationMs)
                )
                .accessibilityLabel("Video position")
                .accessibilityValue(timeLabel(request.state.currentTimeMs))

                Text(timeLabel(request.state.currentTimeMs))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func timeLabel(_ milliseconds: Int) -> String {
        let totalSeconds = max(milliseconds, 0) / 1_000
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
