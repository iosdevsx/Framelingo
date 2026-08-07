import Foundation
import Shorts
import SpeakerAnalysis
import Subtitles
import SwiftUI
import Timeline
import TimelineFeature

@MainActor
public enum TimelineFeatureAssembly {
    public static func makeFactory() -> TimelineFeatureFactory {
        TimelineFeatureFactory(
            makeSubtitleTimeline: { request in
                AnyView(
                    SubtitleTimelineView(
                        subtitles: request.bindings.subtitles,
                        selectedSegmentID: request.bindings.selectedSegmentID,
                        currentTimeMs: request.state.currentTimeMs,
                        durationMs: request.state.durationMs,
                        waveformPeaks: request.state.waveformPeaks,
                        speakers: request.state.speakers,
                        presentation: request.state.presentation,
                        zoomFactor: request.bindings.zoomFactor,
                        scrollToPlayheadRequest: request.bindings.scrollToPlayheadRequest,
                        showsWaveform: request.bindings.showsWaveform,
                        onSeek: request.actions.seek,
                        onBeginTextEditing: request.actions.beginTextEditing,
                        onTranslatedTextChange: request.actions.changeTranslatedText,
                        onEndTextEditing: request.actions.endTextEditing,
                        shortsOverlay: request.state.shortsOverlay.map {
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
                    .timelineKeyboardCommands(
                        onStep: request.keyboardActions.step,
                        onDelete: request.keyboardActions.delete
                    )
                )
            },
            makeEditTimeline: { request in
                AnyView(
                    EditTimelineView(
                        timeline: request.state.timeline,
                        subtitles: request.state.subtitles,
                        selectedClipID: request.bindings.selectedClipID,
                        currentTimeMs: request.state.currentTimeMs,
                        rangeStartMs: request.state.rangeStartMs,
                        rangeEndMs: request.state.rangeEndMs,
                        onSeek: request.actions.seek,
                        onSelectClip: request.actions.selectClip,
                        zoomFactor: request.bindings.zoomFactor
                    )
                    .timelineKeyboardCommands(
                        onStep: request.keyboardActions.step,
                        onDelete: request.keyboardActions.delete
                    )
                )
            }
        )
    }
}
