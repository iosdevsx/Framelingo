import Foundation
import Shorts
import SpeakerAnalysis
import Subtitles
import SwiftUI
import Timeline
import TimelineFeature

@MainActor
public enum TimelineFeatureAssembly {
    public static func makeSubtitleTimeline(
        subtitles: Binding<[SubtitleSegment]>,
        selectedSegmentID: Binding<UUID?>,
        currentTimeMs: Int,
        durationMs: Int,
        waveformPeaks: [Double],
        speakers: [Speaker],
        zoomFactor: Binding<Double>,
        scrollToPlayheadRequest: Binding<Int>,
        showsWaveform: Binding<Bool>,
        onSeek: @escaping (Int) -> Void,
        onBeginTextEditing: @escaping (UUID) -> Void,
        onTranslatedTextChange: @escaping (UUID, String) -> Void,
        onEndTextEditing: @escaping () -> Void,
        shortsOverlay: TimelineShortsOverlay? = nil
    ) -> AnyView {
        AnyView(
            SubtitleTimelineView(
                subtitles: subtitles,
                selectedSegmentID: selectedSegmentID,
                currentTimeMs: currentTimeMs,
                durationMs: durationMs,
                waveformPeaks: waveformPeaks,
                speakers: speakers,
                zoomFactor: zoomFactor,
                scrollToPlayheadRequest: scrollToPlayheadRequest,
                showsWaveform: showsWaveform,
                onSeek: onSeek,
                onBeginTextEditing: onBeginTextEditing,
                onTranslatedTextChange: onTranslatedTextChange,
                onEndTextEditing: onEndTextEditing,
                shortsOverlay: shortsOverlay.map {
                    ShortsTimelineOverlayConfig(
                        shorts: $0.shorts,
                        selectedShortID: $0.selectedShortID,
                        snapToCues: $0.snapToCues,
                        onSelect: $0.onSelect,
                        onCommitRange: $0.onCommitRange,
                        onCreate: $0.onCreate
                    )
                }
            )
        )
    }

    public static func makeEditTimeline(
        timeline: EditTimeline,
        subtitles: [SubtitleSegment],
        selectedClipID: Binding<UUID?>,
        currentTimeMs: Int,
        rangeStartMs: Int?,
        rangeEndMs: Int?,
        onSeek: @escaping (Int) -> Void,
        onSelectClip: @escaping (UUID) -> Void,
        zoomFactor: Binding<Double>
    ) -> AnyView {
        AnyView(
            EditTimelineView(
                timeline: timeline,
                subtitles: subtitles,
                selectedClipID: selectedClipID,
                currentTimeMs: currentTimeMs,
                rangeStartMs: rangeStartMs,
                rangeEndMs: rangeEndMs,
                onSeek: onSeek,
                onSelectClip: onSelectClip,
                zoomFactor: zoomFactor
            )
        )
    }
}
