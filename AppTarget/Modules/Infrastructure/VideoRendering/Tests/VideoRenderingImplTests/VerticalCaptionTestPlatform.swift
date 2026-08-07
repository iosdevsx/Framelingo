import VideoRendering

enum VerticalCaptionTestPlatform: CaseIterable {
    case youtubeShorts
    case instagramReels
    case tiktok

    var topSafeAreaFraction: Double {
        switch self {
        case .youtubeShorts: 0.10
        case .instagramReels, .tiktok: 0.12
        }
    }

    var bottomSafeAreaFraction: Double {
        switch self {
        case .youtubeShorts: 0.12
        case .instagramReels: 0.20
        case .tiktok: 0.22
        }
    }

    var configuration: VerticalCaptionConfiguration {
        VerticalCaptionConfiguration(
            topSafeAreaFraction: topSafeAreaFraction,
            bottomSafeAreaFraction: bottomSafeAreaFraction
        )
    }
}
