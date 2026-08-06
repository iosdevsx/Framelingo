import Foundation
import Project
import Shorts
import Subtitles
import Timeline

public struct ProjectSessionSubtitleEditorProjection: Equatable {
    public let subtitles: [SubtitleSegment]
    public let selection: ProjectSessionCueSelectionState
}

public struct ProjectSessionTimelineProjection: Equatable {
    public let subtitles: [SubtitleSegment]
    public let timeline: EditTimeline?
    public let interaction: ProjectSessionTimelineInteractionState
    public let playback: ProjectSessionPlaybackState
}

public struct ProjectSessionPlayerProjection: Equatable {
    public let playback: ProjectSessionPlaybackState
    public let selectedCueID: UUID?
}

public struct ProjectSessionShortsProjection: Equatable {
    public let shorts: [ShortDefinition]
    public let settings: ShortsExportSettings
    public let interaction: ProjectSessionShortsInteractionState
}

public struct ProjectSessionExportOptionsProjection: Equatable {
    public let subtitleOptions: SubtitleExportOptions
}

public extension ProjectSessionSnapshot {
    var subtitleEditorProjection: ProjectSessionSubtitleEditorProjection? {
        project.map { .init(subtitles: $0.subtitles, selection: interaction.cueSelection) }
    }

    var timelineProjection: ProjectSessionTimelineProjection? {
        project.map {
            .init(
                subtitles: $0.subtitles,
                timeline: $0.editTimeline,
                interaction: interaction.timeline,
                playback: interaction.playback
            )
        }
    }

    var playerProjection: ProjectSessionPlayerProjection? {
        guard project != nil else { return nil }
        return .init(playback: interaction.playback, selectedCueID: interaction.cueSelection.primaryCueID)
    }

    var shortsProjection: ProjectSessionShortsProjection? {
        project.map { .init(shorts: $0.shorts, settings: $0.shortsExportSettings, interaction: interaction.shorts) }
    }

    var exportOptionsProjection: ProjectSessionExportOptionsProjection? {
        project.map { .init(subtitleOptions: $0.speakerExportOptions) }
    }
}
