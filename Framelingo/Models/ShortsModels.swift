import Foundation

/// Target platform preset for a vertical short. Duration limits and safe-area
/// insets are advisory preset data (used for warnings and text placement),
/// kept in one place because platforms change them over time.
enum ShortsPlatform: String, Codable, CaseIterable, Identifiable {
    case youtubeShorts
    case instagramReels
    case tiktok

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .youtubeShorts:
            return "YouTube Shorts"
        case .instagramReels:
            return "Instagram Reels"
        case .tiktok:
            return "TikTok"
        }
    }

    var durationLimitMs: Int {
        switch self {
        case .youtubeShorts:
            return 180_000
        case .instagramReels:
            return 180_000
        case .tiktok:
            return 600_000
        }
    }

    /// Fraction of the frame height covered by platform UI at the top.
    var topSafeAreaFraction: Double {
        switch self {
        case .youtubeShorts:
            return 0.10
        case .instagramReels:
            return 0.12
        case .tiktok:
            return 0.12
        }
    }

    /// Fraction of the frame height covered by platform UI at the bottom.
    var bottomSafeAreaFraction: Double {
        switch self {
        case .youtubeShorts:
            return 0.12
        case .instagramReels:
            return 0.20
        case .tiktok:
            return 0.22
        }
    }
}

enum ShortsReframing: String, Codable, CaseIterable, Identifiable {
    case blurPad
    case crop

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blurPad:
            return "Blurred background"
        case .crop:
            return "Crop"
        }
    }
}

/// A discrete crop position change in short-local time. Export and preview
/// hold the previous crop until the next point; no movement is animated.
struct ShortCropKeyframe: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var timeMs: Int
    var offsetX: Double

    init(id: UUID = UUID(), timeMs: Int, offsetX: Double) {
        self.id = id
        self.timeMs = max(0, timeMs)
        self.offsetX = min(max(offsetX, 0), 1)
    }
}

/// A named, non-destructive short range. Times are in edit-timeline time —
/// the same timebase as `project.subtitles` (equal to source time when the
/// project has no edit timeline).
struct ShortDefinition: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var startMs: Int
    var endMs: Int
    var reframing: ShortsReframing?
    var cropOffsetX: Double
    var cropKeyframes: [ShortCropKeyframe]
    var hookText: String
    var platformOverride: ShortsPlatform?

    var durationMs: Int {
        max(0, endMs - startMs)
    }

    var trimmedHookText: String {
        hookText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func effectivePlatform(default defaultPlatform: ShortsPlatform) -> ShortsPlatform {
        platformOverride ?? defaultPlatform
    }

    func effectiveReframing(default defaultReframing: ShortsReframing) -> ShortsReframing {
        reframing ?? defaultReframing
    }

    func cropOffset(atTimelineTimeMs timelineTimeMs: Int) -> Double {
        cropOffset(atLocalTimeMs: timelineTimeMs - startMs)
    }

    func cropOffset(atLocalTimeMs localTimeMs: Int) -> Double {
        cropKeyframes
            .filter { $0.timeMs <= max(0, localTimeMs) }
            .max { $0.timeMs < $1.timeMs }?
            .offsetX ?? min(max(cropOffsetX, 0), 1)
    }

    mutating func upsertCropKeyframe(localTimeMs: Int, offsetX: Double) {
        let timeMs = min(max(0, localTimeMs), durationMs)
        let offsetX = min(max(offsetX, 0), 1)
        if let index = cropKeyframes.firstIndex(where: { $0.timeMs == timeMs }) {
            cropKeyframes[index].offsetX = offsetX
        } else {
            cropKeyframes.append(ShortCropKeyframe(timeMs: timeMs, offsetX: offsetX))
        }
        cropKeyframes.sort { $0.timeMs < $1.timeMs }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startMs
        case endMs
        case reframing
        case cropOffsetX
        case cropKeyframes
        case hookText
        case platformOverride
    }

    init(
        id: UUID = UUID(),
        title: String,
        startMs: Int,
        endMs: Int,
        reframing: ShortsReframing? = nil,
        cropOffsetX: Double = 0.5,
        cropKeyframes: [ShortCropKeyframe] = [],
        hookText: String = "",
        platformOverride: ShortsPlatform? = nil
    ) {
        self.id = id
        self.title = title
        self.startMs = startMs
        self.endMs = endMs
        self.reframing = reframing
        self.cropOffsetX = cropOffsetX
        self.cropKeyframes = cropKeyframes.sorted { $0.timeMs < $1.timeMs }
        self.hookText = hookText
        self.platformOverride = platformOverride
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startMs = try container.decode(Int.self, forKey: .startMs)
        endMs = try container.decode(Int.self, forKey: .endMs)
        reframing = try container.decodeIfPresent(ShortsReframing.self, forKey: .reframing)
        cropOffsetX = try container.decodeIfPresent(Double.self, forKey: .cropOffsetX) ?? 0.5
        cropKeyframes = try container.decodeIfPresent([ShortCropKeyframe].self, forKey: .cropKeyframes) ?? []
        cropKeyframes.sort { $0.timeMs < $1.timeMs }
        hookText = try container.decodeIfPresent(String.self, forKey: .hookText) ?? ""
        platformOverride = try container.decodeIfPresent(ShortsPlatform.self, forKey: .platformOverride)
    }
}
