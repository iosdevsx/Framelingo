import AVFoundation
import AppKit
import SwiftUI

struct ProjectVideoPreview: View {
    let project: Project
    let player: AVPlayer?
    let isPlaying: Bool
    let currentTimeMs: Int
    let showsControls: Bool
    let videoSourceInfo: VideoSourceInfo?
    let onTogglePlayback: () -> Void
    let onUpdateSettings: (VideoExportSettings, Bool) -> Void

    @State private var subtitleDragStartPosition: CGPoint?

    var body: some View {
        let subtitleSettings = project.videoExportSettings
        let subtitleShape = RoundedRectangle(
            cornerRadius: max(0, subtitleSettings.backgroundCornerRadius)
        )

        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.black

                if let player {
                    MacVideoPlayerView(player: player)
                } else {
                    ContentUnavailableView("Video Unavailable", systemImage: "video.slash")
                        .foregroundStyle(.white)
                }

                GeometryReader { geometry in
                    let videoRect = VideoExportGeometry.aspectFitRect(
                        videoSize: videoSourceInfo?.displaySize ?? geometry.size,
                        in: CGRect(origin: .zero, size: geometry.size)
                    )

                    ZStack {
                        if let subtitleText = currentSubtitleText {
                            Text(subtitleText)
                                .font(.custom(subtitleSettings.fontName, size: subtitlePreviewFontSize(subtitleSettings.fontSize)).weight(.semibold))
                                .foregroundStyle(subtitleSwiftUIColor(subtitleSettings))
                                .multilineTextAlignment(.center)
                                .lineLimit(subtitleSettings.maxLines)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    subtitleSettings.backgroundEnabled
                                        ? subtitleBackgroundSwiftUIColor(subtitleSettings).opacity(subtitleSettings.backgroundOpacity)
                                        : Color.clear,
                                    in: subtitleShape
                                )
                                .overlay(
                                    subtitleShape.stroke(
                                        subtitleBorderSwiftUIColor(subtitleSettings),
                                        lineWidth: max(0, subtitleSettings.borderWidth)
                                    )
                                )
                                .frame(maxWidth: videoRect.width * 0.8)
                                .position(
                                    x: videoRect.width * subtitleSettings.subtitlePositionX,
                                    y: videoRect.height * subtitleSettings.subtitlePositionY
                                )
                                .gesture(
                                    subtitlePositionDragGesture(
                                        settings: subtitleSettings,
                                        size: videoRect.size
                                    )
                                )
                                .onHover { isHovering in
                                    if isHovering {
                                        NSCursor.openHand.set()
                                    } else {
                                        NSCursor.arrow.set()
                                    }
                                }
                        }
                    }
                    .frame(width: videoRect.width, height: videoRect.height)
                    .clipped()
                    .position(x: videoRect.midX, y: videoRect.midY)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if showsControls {
                HStack(spacing: 12) {
                    Button {
                        onTogglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 22)
                    }
                    .buttonStyle(.bordered)

                    Text(SubtitleTimeFormatter.format(milliseconds: currentTimeMs))
                        .monospacedDigit()
                        .font(.callout)

                    Text("/ \(durationText(project.mediaFile.durationMs))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }

            Spacer()
        }
        .padding(10)
    }

    private var currentSubtitleText: String? {
        guard let segment = project.subtitles.first(where: { segment in
            currentTimeMs >= segment.startMs && currentTimeMs <= segment.endMs
        }) else {
            return nil
        }

        let translatedText = segment.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalText = segment.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitleText = translatedText.isEmpty ? originalText : translatedText

        return subtitleText.isEmpty ? nil : subtitleText
    }

    private func subtitlePositionDragGesture(settings: VideoExportSettings, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if subtitleDragStartPosition == nil {
                    subtitleDragStartPosition = CGPoint(
                        x: settings.subtitlePositionX,
                        y: settings.subtitlePositionY
                    )
                }

                guard let start = subtitleDragStartPosition,
                      size.width > 0,
                      size.height > 0 else {
                    return
                }

                var updatedSettings = settings
                updatedSettings.subtitlePositionX = clampDouble(start.x + value.translation.width / size.width, 0...1)
                updatedSettings.subtitlePositionY = clampDouble(start.y + value.translation.height / size.height, 0...1)
                updatedSettings.subtitlePosition = nearestSubtitlePosition(for: updatedSettings.subtitlePositionY)
                onUpdateSettings(updatedSettings, false)
            }
            .onEnded { _ in
                subtitleDragStartPosition = nil
            }
    }

    private func nearestSubtitlePosition(for y: Double) -> SubtitlePosition {
        if y < 0.33 {
            return .top
        }

        if y > 0.66 {
            return .bottom
        }

        return .center
    }

    private func subtitlePreviewFontSize(_ exportFontSize: Double) -> Double {
        min(max(exportFontSize * 0.55, 12), 36)
    }

    private func subtitleSwiftUIColor(_ settings: VideoExportSettings) -> Color {
        Color(
            red: clampDouble(settings.textColorRed, 0...1),
            green: clampDouble(settings.textColorGreen, 0...1),
            blue: clampDouble(settings.textColorBlue, 0...1)
        )
    }

    private func subtitleBackgroundSwiftUIColor(_ settings: VideoExportSettings) -> Color {
        Color(
            red: clampDouble(settings.backgroundColorRed, 0...1),
            green: clampDouble(settings.backgroundColorGreen, 0...1),
            blue: clampDouble(settings.backgroundColorBlue, 0...1)
        )
    }

    private func subtitleBorderSwiftUIColor(_ settings: VideoExportSettings) -> Color {
        guard settings.backgroundEnabled, settings.borderEnabled else {
            return .clear
        }

        return Color(
            red: clampDouble(settings.borderColorRed, 0...1),
            green: clampDouble(settings.borderColorGreen, 0...1),
            blue: clampDouble(settings.borderColorBlue, 0...1)
        )
        .opacity(clampDouble(settings.borderOpacity, 0...1))
    }

    private func clampDouble(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func durationText(_ durationMs: Int?) -> String {
        guard let durationMs else {
            return "Unknown"
        }

        return SubtitleTimeFormatter.format(milliseconds: durationMs)
    }
}
