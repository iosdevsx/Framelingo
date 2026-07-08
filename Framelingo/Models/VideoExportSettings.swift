import Foundation

struct VideoExportSettings: Codable, Equatable {
    var subtitleTextMode: SubtitleTextMode = .translatedFallbackToOriginal
    var fontName: String = "Arial"
    var fontSize: Double = 32
    var subtitlePosition: SubtitlePosition = .bottom
    var textColor: SubtitleColor = .white
    var textColorRed: Double = 1
    var textColorGreen: Double = 1
    var textColorBlue: Double = 1
    var backgroundEnabled: Bool = true
    var backgroundColorRed: Double = 0
    var backgroundColorGreen: Double = 0
    var backgroundColorBlue: Double = 0
    var backgroundOpacity: Double = 0.55
    var maxLines: Int = 2
    var subtitlePositionX: Double = 0.5
    var subtitlePositionY: Double = 0.86
    var codec: VideoExportCodec = .h264
    var quality: VideoExportQuality = .normal
    var preset: VideoExportPreset = .medium

    init(
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
        maxLines: Int = 2,
        subtitlePositionX: Double = 0.5,
        subtitlePositionY: Double = 0.86,
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
        self.maxLines = maxLines
        self.subtitlePositionX = subtitlePositionX
        self.subtitlePositionY = subtitlePositionY
        self.codec = codec
        self.quality = quality
        self.preset = preset
    }

    enum CodingKeys: String, CodingKey {
        case subtitleTextMode
        case fontName
        case fontSize
        case subtitlePosition
        case textColor
        case textColorRed
        case textColorGreen
        case textColorBlue
        case backgroundEnabled
        case backgroundColorRed
        case backgroundColorGreen
        case backgroundColorBlue
        case backgroundOpacity
        case maxLines
        case subtitlePositionX
        case subtitlePositionY
        case codec
        case quality
        case preset
    }

    init(from decoder: Decoder) throws {
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
        maxLines = try container.decodeIfPresent(Int.self, forKey: .maxLines) ?? defaults.maxLines
        subtitlePositionX = try container.decodeIfPresent(Double.self, forKey: .subtitlePositionX) ?? defaults.subtitlePositionX
        subtitlePositionY = try container.decodeIfPresent(Double.self, forKey: .subtitlePositionY) ?? defaults.subtitlePositionY
        codec = try container.decodeIfPresent(VideoExportCodec.self, forKey: .codec) ?? defaults.codec
        quality = try container.decodeIfPresent(VideoExportQuality.self, forKey: .quality) ?? defaults.quality
        preset = try container.decodeIfPresent(VideoExportPreset.self, forKey: .preset) ?? defaults.preset
    }
}

enum SubtitlePosition: String, Codable, CaseIterable, Identifiable {
    case bottom
    case center
    case top

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottom:
            return "Bottom"
        case .center:
            return "Center"
        case .top:
            return "Top"
        }
    }

    var defaultYOffset: Double {
        switch self {
        case .bottom:
            0.86
        case .center:
            0.5
        case .top:
            0.14
        }
    }
}

enum SubtitleColor: String, Codable, CaseIterable, Identifiable {
    case white
    case yellow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .white:
            return "White"
        case .yellow:
            return "Yellow"
        }
    }
}

enum VideoExportCodec: String, Codable, CaseIterable, Identifiable {
    case h264

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .h264:
            return "H.264"
        }
    }
}

enum VideoExportQuality: String, Codable, CaseIterable, Identifiable {
    case smallFile
    case normal
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .smallFile:
            return "Small file"
        case .normal:
            return "Normal"
        case .high:
            return "High"
        }
    }

    var crf: Int {
        switch self {
        case .smallFile:
            return 28
        case .normal:
            return 23
        case .high:
            return 18
        }
    }

    var mpeg4QualityScale: Int {
        switch self {
        case .smallFile:
            return 8
        case .normal:
            return 5
        case .high:
            return 2
        }
    }
}

enum VideoExportPreset: String, Codable, CaseIterable, Identifiable {
    case fast
    case medium
    case slow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fast:
            return "Fast"
        case .medium:
            return "Medium"
        case .slow:
            return "Slow"
        }
    }
}
