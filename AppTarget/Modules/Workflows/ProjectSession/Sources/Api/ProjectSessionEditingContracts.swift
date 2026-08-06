import Foundation
import Project
import Shorts
import Subtitles
import Timeline
import VideoRendering

public struct ProjectSessionEditResult: Equatable {
    public let didChange: Bool
    public let selectedID: UUID?
    public let message: String?

    public init(didChange: Bool, selectedID: UUID? = nil, message: String? = nil) {
        self.didChange = didChange
        self.selectedID = selectedID
        self.message = message
    }

    public static var unchanged: Self { Self(didChange: false) }
}

@MainActor
public protocol ProjectSessionSubtitleEditing: AnyObject {
    func updateSubtitle(_ segment: SubtitleSegment) -> ProjectSessionEditResult
    func updateSegmentTiming(id: UUID, startMs: Int, endMs: Int) -> ProjectSessionEditResult
    func moveSegment(id: UUID, deltaMs: Int) -> ProjectSessionEditResult
    func replaceSubtitlesFromTimeline(_ subtitles: [SubtitleSegment]) -> ProjectSessionEditResult
    func updateTranslatedText(segmentID: UUID, text: String) -> ProjectSessionEditResult
    func splitSegment(id: UUID) -> ProjectSessionEditResult
    func mergeWithNextSegment(id: UUID) -> ProjectSessionEditResult
    func deleteSegment(id: UUID) -> ProjectSessionEditResult
    func addSegmentAfter(id: UUID) -> ProjectSessionEditResult
    func updateSpeakerLabel(id: Int, displayName: String) -> ProjectSessionEditResult
    func updateSourceLanguage(_ language: String) -> ProjectSessionEditResult
    func updateTargetLanguage(_ language: String) -> ProjectSessionEditResult
    func updateSpeakerExportOptions(_ options: SubtitleExportOptions) -> ProjectSessionEditResult
    func updateVideoExportSettings(_ settings: VideoExportSettings, undoable: Bool) -> ProjectSessionEditResult
}

@MainActor
public protocol ProjectSessionSelectionPlaybackEditing: AnyObject {
    func selectCue(id: UUID?, extending: Bool, toggling: Bool)
    func seek(to milliseconds: Int)
}

@MainActor
public protocol ProjectSessionTimelineEditing: AnyObject {
    func ensureTimeline() -> ProjectSessionEditResult
    func setTimelineClipSelection(_ id: UUID?)
    func setEditRangeStartFromPlayhead()
    func setEditRangeEndFromPlayhead()
    func setEditRange(startMs: Int?, endMs: Int?)
    func clearEditRange()
    func rippleDeleteSelectedRange() -> ProjectSessionEditResult
    func splitAtPlayhead() -> ProjectSessionEditResult
    func deleteSelectedClip() -> ProjectSessionEditResult
    func sourceTime(forTimelineTime milliseconds: Int) -> Int?
    func clip(atTimelineTime milliseconds: Int) -> TimelineClip?
    func playbackAdvance(sourceTimeMs: Int, currentClipID: UUID?) -> EditTimelinePlaybackAdvance?
    func seekTimeline(to milliseconds: Int)
    func setTimelinePlaybackEnabled(_ enabled: Bool)
    func timelineDurationMs() -> Int
    func resolvedTimeline() -> EditTimeline?
}

@MainActor
public protocol ProjectSessionShortsEditing: AnyObject {
    func selectShort(id: UUID?)
    func addShort(startMs: Int, endMs: Int, title: String?) -> ProjectSessionEditResult
    func addShortAtPlayhead() -> ProjectSessionEditResult
    func createShortFromSelectedCues() -> ProjectSessionEditResult
    func replaceShort(_ short: ShortDefinition) -> ProjectSessionEditResult
    func updateShortRange(id: UUID, startMs: Int, endMs: Int) -> ProjectSessionEditResult
    func setSelectedShortStartToPlayhead() -> ProjectSessionEditResult
    func setSelectedShortEndToPlayhead() -> ProjectSessionEditResult
    func setShortStartFromPlayhead() -> ProjectSessionEditResult
    func setShortEndFromPlayhead() -> ProjectSessionEditResult
    func clearPendingShortRange()
    func deleteShort(id: UUID) -> ProjectSessionEditResult
    func addCropPointAtPlayhead(shortID: UUID) -> ProjectSessionEditResult
    func updateShortCropOffset(id: UUID, timelineTimeMs: Int, offsetX: Double) -> ProjectSessionEditResult
    func deleteShortCropKeyframe(shortID: UUID, keyframeID: UUID) -> ProjectSessionEditResult
    func updateShortsExportSettings(_ settings: ShortsExportSettings) -> ProjectSessionEditResult
    func updateShortsSubtitleStyle(_ style: VideoExportSettings, undoable: Bool) -> ProjectSessionEditResult
    func generateShortsSuggestions()
    func acceptShortSuggestion(id: UUID) -> ProjectSessionEditResult
    func dismissShortSuggestion(id: UUID)
}

@MainActor
public protocol ProjectSessionEditing:
    ProjectSessionSubtitleEditing,
    ProjectSessionSelectionPlaybackEditing,
    ProjectSessionTimelineEditing,
    ProjectSessionShortsEditing
{}

@MainActor
public protocol ProjectSessionWorkspace: ProjectSession, ProjectSessionEditing {}
