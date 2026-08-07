import Foundation

/// Target platform preset for a vertical short. Duration limits and safe-area
/// insets are advisory preset data (used for warnings and text placement),
/// kept in one place because platforms change them over time.
public enum ShortsPlatform: String, Codable, CaseIterable, Identifiable, Sendable {
    case youtubeShorts
    case instagramReels
    case tiktok

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .youtubeShorts:
            return "YouTube Shorts"
        case .instagramReels:
            return "Instagram Reels"
        case .tiktok:
            return "TikTok"
        }
    }

    public var durationLimitMs: Int {
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
    public var topSafeAreaFraction: Double {
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
    public var bottomSafeAreaFraction: Double {
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
