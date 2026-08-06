import ExportFeature
import PlayerFeature
import ShortsFeature
import SubtitleEditorFeature
import TimelineFeature

@MainActor
public struct ProjectFeatureComponents {
    public let player: PlayerFeatureFactory
    public let timeline: TimelineFeatureFactory
    public let subtitleEditor: SubtitleEditorFeatureFactory
    public let shorts: ShortsFeatureFactory
    public let export: ExportFeatureFactory

    public init(
        player: PlayerFeatureFactory,
        timeline: TimelineFeatureFactory,
        subtitleEditor: SubtitleEditorFeatureFactory,
        shorts: ShortsFeatureFactory,
        export: ExportFeatureFactory
    ) {
        self.player = player
        self.timeline = timeline
        self.subtitleEditor = subtitleEditor
        self.shorts = shorts
        self.export = export
    }
}
