import SwiftUI

struct EditTimelineView: View {
    let timeline: EditTimeline
    let subtitles: [SubtitleSegment]
    @Binding var selectedClipID: UUID?
    let currentTimeMs: Int
    let rangeStartMs: Int?
    let rangeEndMs: Int?
    let onSeek: (Int) -> Void
    let onSelectClip: (UUID) -> Void

    @Binding var zoomFactor: Double
    @State private var timelineScrollOffsetX: CGFloat = 0

    private let basePxPerMs: CGFloat = 0.08
    private let rulerHeight: CGFloat = 30
    private let clipTrackHeight: CGFloat = 58
    private let subtitleTrackHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                if timeline.isEmpty {
                    emptyState
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    let durationMs = max(timeline.totalDurationMs, 1)
                    let width = max(
                        geometry.size.width,
                        CGFloat(durationMs) * basePxPerMs * zoomFactor
                    )
                    let pxPerMs = width / CGFloat(durationMs)
                    let visibleRange = TimelineVisibleRange.visible(
                        scrollOffsetX: timelineScrollOffsetX,
                        viewportWidth: geometry.size.width,
                        pxPerMs: pxPerMs,
                        durationMs: durationMs
                    ) ?? .full(durationMs: durationMs)
                    let visibleClips = timeline.clips.filter {
                        visibleRange.intersects(startMs: $0.timelineStartMs, endMs: $0.timelineEndMs)
                    }
                    let visibleSubtitles = Array(TimelinePerformance.visibleSegments(
                        in: subtitles,
                        range: visibleRange
                    ))

                    ScrollView(.horizontal) {
                        ZStack(alignment: .topLeading) {
                            TimelineRulerView(durationMs: durationMs, pxPerMs: pxPerMs)
                                .frame(width: width, height: rulerHeight)

                            clipTrack(width: width, pxPerMs: pxPerMs, visibleClips: visibleClips)
                                .offset(y: rulerHeight + 10)

                            subtitleTrack(width: width, pxPerMs: pxPerMs, visibleSubtitles: visibleSubtitles)
                                .offset(y: rulerHeight + clipTrackHeight + 20)

                            if let rangeRect = cutRangeRect(pxPerMs: pxPerMs) {
                                Rectangle()
                                    .fill(Color.red.opacity(0.28))
                                    .frame(width: rangeRect.width, height: rulerHeight + clipTrackHeight + subtitleTrackHeight + 30)
                                    .offset(x: rangeRect.minX)
                            }

                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: rulerHeight + clipTrackHeight + subtitleTrackHeight + 30)
                                .offset(x: CGFloat(min(max(currentTimeMs, 0), durationMs)) * pxPerMs)
                                .shadow(color: .red.opacity(0.55), radius: 4)
                        }
                        .frame(width: width, height: rulerHeight + clipTrackHeight + subtitleTrackHeight + 38, alignment: .topLeading)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    onSeek(milliseconds(forX: value.location.x, pxPerMs: pxPerMs, durationMs: durationMs))
                                }
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.x
                    } action: { _, newValue in
                        timelineScrollOffsetX = max(0, newValue)
                    }
                }
            }
        }
        .background(Color(red: 0.08, green: 0.085, blue: 0.095))
        .foregroundStyle(.white)
    }

    private func clipTrack(width: CGFloat, pxPerMs: CGFloat, visibleClips: [TimelineClip]) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.12, green: 0.125, blue: 0.14))
                .frame(width: width, height: clipTrackHeight)

            ForEach(visibleClips) { clip in
                let clipWidth = max(CGFloat(clip.timelineDurationMs) * pxPerMs, 18)
                Button {
                    selectedClipID = clip.id
                    onSelectClip(clip.id)
                    onSeek(clip.timelineStartMs)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Clip \(clipNumber(clip))")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("\(formatTime(clip.sourceStartMs)) - \(formatTime(clip.sourceEndMs))")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .background(clipFillColor(clip), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selectedClipID == clip.id ? Color.white : Color.white.opacity(0.3), lineWidth: selectedClipID == clip.id ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .frame(width: clipWidth, height: clipTrackHeight - 10)
                .offset(x: CGFloat(clip.timelineStartMs) * pxPerMs, y: 5)
            }
        }
    }

    private func subtitleTrack(width: CGFloat, pxPerMs: CGFloat, visibleSubtitles: [SubtitleSegment]) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.10, green: 0.105, blue: 0.12))
                .frame(width: width, height: subtitleTrackHeight)

            ForEach(visibleSubtitles) { segment in
                let subtitleWidth = max(CGFloat(segment.durationMs) * pxPerMs, 10)
                Text(subtitleText(segment))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .frame(width: subtitleWidth, height: subtitleTrackHeight - 12, alignment: .leading)
                    .background(Color.accentColor.opacity(0.58), in: RoundedRectangle(cornerRadius: 4))
                    .offset(x: CGFloat(segment.startMs) * pxPerMs, y: 6)
            }
        }
    }

    private func cutRangeRect(pxPerMs: CGFloat) -> CGRect? {
        guard let rangeStartMs, let rangeEndMs, rangeStartMs != rangeEndMs else {
            return nil
        }

        let start = min(rangeStartMs, rangeEndMs)
        let end = max(rangeStartMs, rangeEndMs)
        return CGRect(
            x: CGFloat(start) * pxPerMs,
            y: 0,
            width: max(CGFloat(end - start) * pxPerMs, 2),
            height: 1
        )
    }

    private var emptyState: some View {
        Text("Video duration is unknown. Open the video first.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func milliseconds(forX x: CGFloat, pxPerMs: CGFloat, durationMs: Int) -> Int {
        min(max(Int((x / pxPerMs).rounded()), 0), durationMs)
    }

    private func clipFillColor(_ clip: TimelineClip) -> Color {
        if selectedClipID == clip.id {
            return Color(red: 0.20, green: 0.36, blue: 0.64)
        }

        if currentTimeMs >= clip.timelineStartMs && currentTimeMs < clip.timelineEndMs {
            return Color(red: 0.24, green: 0.32, blue: 0.46)
        }

        return Color(red: 0.18, green: 0.22, blue: 0.30)
    }

    private func clipNumber(_ clip: TimelineClip) -> Int {
        (timeline.clips.firstIndex(where: { $0.id == clip.id }) ?? 0) + 1
    }

    private func subtitleText(_ segment: SubtitleSegment) -> String {
        let translated = segment.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !translated.isEmpty {
            return translated
        }

        let original = segment.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        return original.isEmpty ? "Subtitle" : original
    }

    private func formatTime(_ milliseconds: Int) -> String {
        SubtitleTimeFormatter.format(milliseconds: milliseconds)
    }
}
