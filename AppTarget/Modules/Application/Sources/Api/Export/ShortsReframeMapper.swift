import Shorts
import VideoRendering

enum ShortsReframeMapper {
    static func plan(
        for short: ShortDefinition,
        defaults: ShortsExportSettings,
        sourceInfo: VideoSourceInfo?
    ) -> VerticalReframePlan {
        VerticalReframePlan(
            mode: short.effectiveReframing(default: defaults.reframing) == .crop ? .crop : .blurPad,
            cropOffsetX: short.cropOffsetX,
            cropKeyframes: short.cropKeyframes.map {
                VideoCropKeyframe(id: $0.id, timeMs: $0.timeMs, offsetX: $0.offsetX)
            },
            sourceWidth: sourceInfo?.width,
            sourceHeight: sourceInfo?.height
        )
    }
}
