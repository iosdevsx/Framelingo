import Foundation

/// A named, non-destructive short range. Times are in edit-timeline time —
/// the same timebase as `project.subtitles` (equal to source time when the
/// project has no edit timeline).
public struct ShortDefinition: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var startMs: Int
    public var endMs: Int
    public var reframing: ShortsReframing?
    public var cropOffsetX: Double
    public var cropKeyframes: [ShortCropKeyframe]
    public var hookText: String
    public var platformOverride: ShortsPlatform?

    public var durationMs: Int {
        max(0, endMs - startMs)
    }

    public var trimmedHookText: String {
        hookText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func effectivePlatform(default defaultPlatform: ShortsPlatform) -> ShortsPlatform {
        platformOverride ?? defaultPlatform
    }

    public func effectiveReframing(default defaultReframing: ShortsReframing) -> ShortsReframing {
        reframing ?? defaultReframing
    }

    public func cropOffset(atTimelineTimeMs timelineTimeMs: Int) -> Double {
        cropOffset(atLocalTimeMs: timelineTimeMs - startMs)
    }

    public func cropOffset(atLocalTimeMs localTimeMs: Int) -> Double {
        cropKeyframes
            .filter { $0.timeMs <= max(0, localTimeMs) }
            .max { $0.timeMs < $1.timeMs }?
            .offsetX ?? min(max(cropOffsetX, 0), 1)
    }

    public mutating func upsertCropKeyframe(localTimeMs: Int, offsetX: Double) {
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

    public init(
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

    public init(from decoder: Decoder) throws {
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
