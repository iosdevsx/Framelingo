import Foundation
import Subtitles

public struct VideoExportSettings: Codable, Equatable, Sendable {
    public var subtitleTextMode: SubtitleTextMode = .translatedFallbackToOriginal
    public var fontName: String = "Arial"
    public var fontSize: Double = 32
    public var subtitlePosition: SubtitlePosition = .bottom
    public var textColor: SubtitleColor = .white
    public var textColorRed: Double = 1
    public var textColorGreen: Double = 1
    public var textColorBlue: Double = 1
    public var backgroundEnabled: Bool = true
    public var backgroundColorRed: Double = 0
    public var backgroundColorGreen: Double = 0
    public var backgroundColorBlue: Double = 0
    public var backgroundOpacity: Double = 0.55
    public var borderEnabled: Bool = true
    public var borderColorRed: Double = 1
    public var borderColorGreen: Double = 1
    public var borderColorBlue: Double = 1
    public var borderOpacity: Double = 0.35
    public var borderWidth: Double = 1
    public var backgroundCornerRadius: Double = 8
    public var maxLines: Int = 2
    public var subtitlePositionX: Double = 0.5
    public var subtitlePositionY: Double = 0.86
    public var resolution: VideoExportResolution = .original
    public var frameRate: VideoExportFrameRate = .original
    public var codec: VideoExportCodec = .h264
    public var quality: VideoExportQuality = .normal
    public var preset: VideoExportPreset = .medium

    public init(
        subtitleTextMode: SubtitleTextMode = .translatedFallbackToOriginal,
        fontName: String = "Arial",
        fontSize: Double = 32,
        subtitlePosition: SubtitlePosition = .bottom,
        textColor: SubtitleColor = .white,
        textColorRed: Double = 1,
        textColorGreen: Double = 1,
        textColorBlue: Double = 1,
        backgroundEnabled: Bool = true,
        backgroundColorRed: Double = 0,
        backgroundColorGreen: Double = 0,
        backgroundColorBlue: Double = 0,
        backgroundOpacity: Double = 0.55,
        borderEnabled: Bool = true,
        borderColorRed: Double = 1,
        borderColorGreen: Double = 1,
        borderColorBlue: Double = 1,
        borderOpacity: Double = 0.35,
        borderWidth: Double = 1,
        backgroundCornerRadius: Double = 8,
        maxLines: Int = 2,
        subtitlePositionX: Double = 0.5,
        subtitlePositionY: Double = 0.86,
        resolution: VideoExportResolution = .original,
        frameRate: VideoExportFrameRate = .original,
        codec: VideoExportCodec = .h264,
        quality: VideoExportQuality = .normal,
        preset: VideoExportPreset = .medium
    ) {
        self.subtitleTextMode = subtitleTextMode
        self.fontName = fontName
        self.fontSize = fontSize
        self.subtitlePosition = subtitlePosition
        self.textColor = textColor
        self.textColorRed = textColorRed
        self.textColorGreen = textColorGreen
        self.textColorBlue = textColorBlue
        self.backgroundEnabled = backgroundEnabled
        self.backgroundColorRed = backgroundColorRed
        self.backgroundColorGreen = backgroundColorGreen
        self.backgroundColorBlue = backgroundColorBlue
        self.backgroundOpacity = backgroundOpacity
        self.borderEnabled = borderEnabled
        self.borderColorRed = borderColorRed
        self.borderColorGreen = borderColorGreen
        self.borderColorBlue = borderColorBlue
        self.borderOpacity = borderOpacity
        self.borderWidth = borderWidth
        self.backgroundCornerRadius = backgroundCornerRadius
        self.maxLines = maxLines
        self.subtitlePositionX = subtitlePositionX
        self.subtitlePositionY = subtitlePositionY
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.quality = quality
        self.preset = preset
    }

    enum CodingKeys: String, CodingKey {
        case subtitleTextMode, fontName, fontSize, subtitlePosition, textColor
        case textColorRed, textColorGreen, textColorBlue, backgroundEnabled
        case backgroundColorRed, backgroundColorGreen, backgroundColorBlue
        case backgroundOpacity, borderEnabled, borderColorRed, borderColorGreen
        case borderColorBlue, borderOpacity, borderWidth, backgroundCornerRadius
        case maxLines, subtitlePositionX, subtitlePositionY, resolution, frameRate
        case codec, quality, preset
    }

    public init(from decoder: Decoder) throws {
        let defaults = VideoExportSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subtitleTextMode = try container.decodeIfPresent(SubtitleTextMode.self, forKey: .subtitleTextMode) ?? defaults.subtitleTextMode
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? defaults.fontName
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? defaults.fontSize
        subtitlePosition = try container.decodeIfPresent(SubtitlePosition.self, forKey: .subtitlePosition) ?? defaults.subtitlePosition
        textColor = try container.decodeIfPresent(SubtitleColor.self, forKey: .textColor) ?? defaults.textColor
        textColorRed = try container.decodeIfPresent(Double.self, forKey: .textColorRed) ?? defaults.textColorRed
        textColorGreen = try container.decodeIfPresent(Double.self, forKey: .textColorGreen) ?? defaults.textColorGreen
        textColorBlue = try container.decodeIfPresent(Double.self, forKey: .textColorBlue) ?? defaults.textColorBlue
        backgroundEnabled = try container.decodeIfPresent(Bool.self, forKey: .backgroundEnabled) ?? defaults.backgroundEnabled
        backgroundColorRed = try container.decodeIfPresent(Double.self, forKey: .backgroundColorRed) ?? defaults.backgroundColorRed
        backgroundColorGreen = try container.decodeIfPresent(Double.self, forKey: .backgroundColorGreen) ?? defaults.backgroundColorGreen
        backgroundColorBlue = try container.decodeIfPresent(Double.self, forKey: .backgroundColorBlue) ?? defaults.backgroundColorBlue
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? defaults.backgroundOpacity
        borderEnabled = try container.decodeIfPresent(Bool.self, forKey: .borderEnabled) ?? defaults.borderEnabled
        borderColorRed = try container.decodeIfPresent(Double.self, forKey: .borderColorRed) ?? defaults.borderColorRed
        borderColorGreen = try container.decodeIfPresent(Double.self, forKey: .borderColorGreen) ?? defaults.borderColorGreen
        borderColorBlue = try container.decodeIfPresent(Double.self, forKey: .borderColorBlue) ?? defaults.borderColorBlue
        borderOpacity = try container.decodeIfPresent(Double.self, forKey: .borderOpacity) ?? defaults.borderOpacity
        borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? defaults.borderWidth
        backgroundCornerRadius = try container.decodeIfPresent(Double.self, forKey: .backgroundCornerRadius) ?? defaults.backgroundCornerRadius
        maxLines = try container.decodeIfPresent(Int.self, forKey: .maxLines) ?? defaults.maxLines
        subtitlePositionX = try container.decodeIfPresent(Double.self, forKey: .subtitlePositionX) ?? defaults.subtitlePositionX
        subtitlePositionY = try container.decodeIfPresent(Double.self, forKey: .subtitlePositionY) ?? defaults.subtitlePositionY
        resolution = try container.decodeIfPresent(VideoExportResolution.self, forKey: .resolution) ?? defaults.resolution
        frameRate = try container.decodeIfPresent(VideoExportFrameRate.self, forKey: .frameRate) ?? defaults.frameRate
        codec = try container.decodeIfPresent(VideoExportCodec.self, forKey: .codec) ?? defaults.codec
        quality = try container.decodeIfPresent(VideoExportQuality.self, forKey: .quality) ?? defaults.quality
        preset = try container.decodeIfPresent(VideoExportPreset.self, forKey: .preset) ?? defaults.preset
    }
}
