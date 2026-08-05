import Foundation
import SpeakerAnalysis
import Subtitles
import SwiftUI
import Timeline

@MainActor
public struct TimelineKeyboardActions {
    private let stepAction: (Int) -> Void
    private let deleteAction: (() -> Void)?

    public init(
        onStep: @escaping (Int) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.stepAction = onStep
        self.deleteAction = onDelete
    }

    public func step(_ direction: Int) { stepAction(direction) }
    public func delete() { deleteAction?() }
}

public struct SubtitleTimelineState {
    public let currentTimeMs: Int
    public let durationMs: Int
    public let waveformPeaks: [Double]
    public let speakers: [Speaker]
    public let shortsOverlay: TimelineShortsOverlay?

    public init(
        currentTimeMs: Int,
        durationMs: Int,
        waveformPeaks: [Double],
        speakers: [Speaker],
        shortsOverlay: TimelineShortsOverlay? = nil
    ) {
        self.currentTimeMs = currentTimeMs
        self.durationMs = durationMs
        self.waveformPeaks = waveformPeaks
        self.speakers = speakers
        self.shortsOverlay = shortsOverlay
    }
}

@MainActor
public struct SubtitleTimelineBindings {
    public let subtitles: Binding<[SubtitleSegment]>
    public let selectedSegmentID: Binding<UUID?>
    public let zoomFactor: Binding<Double>
    public let scrollToPlayheadRequest: Binding<Int>
    public let showsWaveform: Binding<Bool>

    public init(
        subtitles: Binding<[SubtitleSegment]>,
        selectedSegmentID: Binding<UUID?>,
        zoomFactor: Binding<Double>,
        scrollToPlayheadRequest: Binding<Int>,
        showsWaveform: Binding<Bool>
    ) {
        self.subtitles = subtitles
        self.selectedSegmentID = selectedSegmentID
        self.zoomFactor = zoomFactor
        self.scrollToPlayheadRequest = scrollToPlayheadRequest
        self.showsWaveform = showsWaveform
    }
}

@MainActor
public struct SubtitleTimelineActions {
    private let seekAction: (Int) -> Void
    private let beginTextEditingAction: (UUID) -> Void
    private let translatedTextChangeAction: (UUID, String) -> Void
    private let endTextEditingAction: () -> Void

    public init(
        seek: @escaping (Int) -> Void,
        beginTextEditing: @escaping (UUID) -> Void,
        translatedTextChange: @escaping (UUID, String) -> Void,
        endTextEditing: @escaping () -> Void
    ) {
        self.seekAction = seek
        self.beginTextEditingAction = beginTextEditing
        self.translatedTextChangeAction = translatedTextChange
        self.endTextEditingAction = endTextEditing
    }

    public func seek(to milliseconds: Int) { seekAction(milliseconds) }
    public func beginTextEditing(segmentID: UUID) { beginTextEditingAction(segmentID) }
    public func changeTranslatedText(segmentID: UUID, text: String) {
        translatedTextChangeAction(segmentID, text)
    }
    public func endTextEditing() { endTextEditingAction() }
}

@MainActor
public struct SubtitleTimelineRequest {
    public let state: SubtitleTimelineState
    public let bindings: SubtitleTimelineBindings
    public let actions: SubtitleTimelineActions
    public let keyboardActions: TimelineKeyboardActions

    public init(
        state: SubtitleTimelineState,
        bindings: SubtitleTimelineBindings,
        actions: SubtitleTimelineActions,
        keyboardActions: TimelineKeyboardActions
    ) {
        self.state = state
        self.bindings = bindings
        self.actions = actions
        self.keyboardActions = keyboardActions
    }
}

public struct EditTimelineState {
    public let timeline: EditTimeline
    public let subtitles: [SubtitleSegment]
    public let currentTimeMs: Int
    public let rangeStartMs: Int?
    public let rangeEndMs: Int?

    public init(
        timeline: EditTimeline,
        subtitles: [SubtitleSegment],
        currentTimeMs: Int,
        rangeStartMs: Int?,
        rangeEndMs: Int?
    ) {
        self.timeline = timeline
        self.subtitles = subtitles
        self.currentTimeMs = currentTimeMs
        self.rangeStartMs = rangeStartMs
        self.rangeEndMs = rangeEndMs
    }
}

@MainActor
public struct EditTimelineBindings {
    public let selectedClipID: Binding<UUID?>
    public let zoomFactor: Binding<Double>

    public init(selectedClipID: Binding<UUID?>, zoomFactor: Binding<Double>) {
        self.selectedClipID = selectedClipID
        self.zoomFactor = zoomFactor
    }
}

@MainActor
public struct EditTimelineActions {
    private let seekAction: (Int) -> Void
    private let selectClipAction: (UUID) -> Void

    public init(seek: @escaping (Int) -> Void, selectClip: @escaping (UUID) -> Void) {
        self.seekAction = seek
        self.selectClipAction = selectClip
    }

    public func seek(to milliseconds: Int) { seekAction(milliseconds) }
    public func selectClip(id: UUID) { selectClipAction(id) }
}

@MainActor
public struct EditTimelineRequest {
    public let state: EditTimelineState
    public let bindings: EditTimelineBindings
    public let actions: EditTimelineActions
    public let keyboardActions: TimelineKeyboardActions

    public init(
        state: EditTimelineState,
        bindings: EditTimelineBindings,
        actions: EditTimelineActions,
        keyboardActions: TimelineKeyboardActions
    ) {
        self.state = state
        self.bindings = bindings
        self.actions = actions
        self.keyboardActions = keyboardActions
    }
}

@MainActor
public struct TimelineFeatureFactory {
    private let makeSubtitleTimelineAction: (SubtitleTimelineRequest) -> AnyView
    private let makeEditTimelineAction: (EditTimelineRequest) -> AnyView

    public init(
        makeSubtitleTimeline: @escaping (SubtitleTimelineRequest) -> AnyView,
        makeEditTimeline: @escaping (EditTimelineRequest) -> AnyView
    ) {
        self.makeSubtitleTimelineAction = makeSubtitleTimeline
        self.makeEditTimelineAction = makeEditTimeline
    }

    public func makeSubtitleTimeline(_ request: SubtitleTimelineRequest) -> AnyView {
        makeSubtitleTimelineAction(request)
    }

    public func makeEditTimeline(_ request: EditTimelineRequest) -> AnyView {
        makeEditTimelineAction(request)
    }
}
