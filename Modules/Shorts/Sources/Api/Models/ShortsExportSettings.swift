import Foundation
import VideoRendering

/// Project-level defaults for vertical shorts export. `subtitleStyle` is the
/// independent appearance source for the Shorts preview and output. Its
/// encoding fields are ignored — codec, quality, and preset continue to come
/// from the project's regular `videoExportSettings`.
public struct ShortsExportSettings: Codable, Equatable {
    public var platform: ShortsPlatform = .youtubeShorts
    public var reframing: ShortsReframing = .blurPad
    /// Project-level Shorts appearance; subtitle text and timings still come
    /// from the shared `Project.subtitles` collection.
    public var subtitleStyle: VideoExportSettings = ShortsExportSettings.defaultSubtitleStyle
    public var burnSubtitlesIntoVideo: Bool = true
    public var hookFontSize: Double = 72
    public var exportSRTSidecar: Bool = true
    public var filenameTemplate: String = "{project} — {index} {title}"
    public var snapToCues: Bool = true

    public static let verticalCanvasWidth = 1_080
    public static let verticalCanvasHeight = 1_920

    public static var defaultSubtitleStyle: VideoExportSettings {
        var style = VideoExportSettings()
        style.fontSize = 64
        style.maxLines = 3
        style.subtitlePositionX = 0.5
        style.subtitlePositionY = 0.68
        return style
    }

    enum CodingKeys: String, CodingKey {
        case platform
        case reframing
        case subtitleStyle
        case burnSubtitlesIntoVideo
        case hookFontSize
        case exportSRTSidecar
        case filenameTemplate
        case snapToCues
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let defaults = ShortsExportSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        platform = try container.decodeIfPresent(ShortsPlatform.self, forKey: .platform) ?? defaults.platform
        reframing = try container.decodeIfPresent(ShortsReframing.self, forKey: .reframing) ?? defaults.reframing
        subtitleStyle = try container.decodeIfPresent(VideoExportSettings.self, forKey: .subtitleStyle) ?? defaults.subtitleStyle
        burnSubtitlesIntoVideo = try container.decodeIfPresent(Bool.self, forKey: .burnSubtitlesIntoVideo) ?? defaults.burnSubtitlesIntoVideo
        hookFontSize = try container.decodeIfPresent(Double.self, forKey: .hookFontSize) ?? defaults.hookFontSize
        exportSRTSidecar = try container.decodeIfPresent(Bool.self, forKey: .exportSRTSidecar) ?? defaults.exportSRTSidecar
        filenameTemplate = try container.decodeIfPresent(String.self, forKey: .filenameTemplate) ?? defaults.filenameTemplate
        snapToCues = try container.decodeIfPresent(Bool.self, forKey: .snapToCues) ?? defaults.snapToCues
    }
}
