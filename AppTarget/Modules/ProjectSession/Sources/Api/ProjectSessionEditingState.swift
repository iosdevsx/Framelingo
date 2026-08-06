import Foundation
import Shorts

public struct ProjectSessionCueSelectionState: Equatable, Sendable {
    public let primaryCueID: UUID?
    public let selectedCueIDs: Set<UUID>
    public let anchorCueID: UUID?

    public init(
        primaryCueID: UUID? = nil,
        selectedCueIDs: Set<UUID> = [],
        anchorCueID: UUID? = nil
    ) {
        self.primaryCueID = primaryCueID
        self.selectedCueIDs = selectedCueIDs
        self.anchorCueID = anchorCueID
    }

    public static var empty: Self { Self() }
}

public struct ProjectSessionPlaybackState: Equatable, Sendable {
    public let playheadMs: Int
    public let activeCueID: UUID?

    public init(playheadMs: Int = 0, activeCueID: UUID? = nil) {
        self.playheadMs = max(playheadMs, 0)
        self.activeCueID = activeCueID
    }

    public static var empty: Self { Self() }
}

public struct ProjectSessionTimelineInteractionState: Equatable, Sendable {
    public let selectedClipID: UUID?
    public let rangeStartMs: Int?
    public let rangeEndMs: Int?
    public let isPlaybackEnabled: Bool

    public init(
        selectedClipID: UUID? = nil,
        rangeStartMs: Int? = nil,
        rangeEndMs: Int? = nil,
        isPlaybackEnabled: Bool = false
    ) {
        self.selectedClipID = selectedClipID
        self.rangeStartMs = rangeStartMs
        self.rangeEndMs = rangeEndMs
        self.isPlaybackEnabled = isPlaybackEnabled
    }

    public static var empty: Self { Self() }
}

public enum ProjectSessionSuggestionStatus: Equatable, Sendable {
    case idle
    case available
    case empty
    case exhausted
}

public struct ProjectSessionShortsInteractionState: Equatable {
    public let selectedShortID: UUID?
    public let pendingRangeStartMs: Int?
    public let suggestions: [ShortSuggestion]
    public let suggestionStatus: ProjectSessionSuggestionStatus

    public init(
        selectedShortID: UUID? = nil,
        pendingRangeStartMs: Int? = nil,
        suggestions: [ShortSuggestion] = [],
        suggestionStatus: ProjectSessionSuggestionStatus = .idle
    ) {
        self.selectedShortID = selectedShortID
        self.pendingRangeStartMs = pendingRangeStartMs
        self.suggestions = suggestions
        self.suggestionStatus = suggestionStatus
    }

    public static var empty: Self { Self() }
}

public struct ProjectSessionInteractionState: Equatable {
    public let cueSelection: ProjectSessionCueSelectionState
    public let playback: ProjectSessionPlaybackState
    public let timeline: ProjectSessionTimelineInteractionState
    public let shorts: ProjectSessionShortsInteractionState

    public init(
        cueSelection: ProjectSessionCueSelectionState = .empty,
        playback: ProjectSessionPlaybackState = .empty,
        timeline: ProjectSessionTimelineInteractionState = .empty,
        shorts: ProjectSessionShortsInteractionState = .empty
    ) {
        self.cueSelection = cueSelection
        self.playback = playback
        self.timeline = timeline
        self.shorts = shorts
    }

    public static var empty: Self { Self() }
}
