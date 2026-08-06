import Foundation
import Media

public enum MediaAssembly {
    public static func makeMetadataProvider() -> any MediaMetadataProviding {
        MediaMetadataService()
    }

    public static func makeWaveformLoader(
        appName: String = "Framelingo",
        cacheRootURL: URL? = nil
    ) -> any WaveformLoading {
        WaveformService(appName: appName, cacheRootURL: cacheRootURL)
    }

    public static func makePassthroughAudioPreparationService()
        -> any AudioPreparationService {
        PassthroughAudioPreparationService()
    }
}
