import Shorts
import Subtitles
import VideoRendering

extension BurnedSubtitleLayoutHelper {
    static func makeVerticalCaptionLayout(
        for segment: SubtitleSegment,
        settings: VideoExportSettings,
        platform: ShortsPlatform
    ) -> BurnedSubtitleLayout? {
        makeVerticalCaptionLayout(
            for: segment,
            settings: settings,
            configuration: configuration(for: platform)
        )
    }

    static func makeVerticalPreviewCaptionLayout(
        for segment: SubtitleSegment,
        settings: VideoExportSettings,
        platform: ShortsPlatform
    ) -> BurnedSubtitleLayout? {
        makeVerticalPreviewCaptionLayout(
            for: segment,
            settings: settings,
            configuration: configuration(for: platform)
        )
    }

    static func makeVerticalHookLayout(
        text: String,
        style: VideoExportSettings,
        hookFontSize: Double,
        platform: ShortsPlatform
    ) -> BurnedSubtitleLayout? {
        makeVerticalHookLayout(
            text: text,
            style: style,
            hookFontSize: hookFontSize,
            configuration: configuration(for: platform)
        )
    }

    private static func configuration(
        for platform: ShortsPlatform
    ) -> VerticalCaptionConfiguration {
        VerticalCaptionConfiguration(
            topSafeAreaFraction: platform.topSafeAreaFraction,
            bottomSafeAreaFraction: platform.bottomSafeAreaFraction
        )
    }
}
