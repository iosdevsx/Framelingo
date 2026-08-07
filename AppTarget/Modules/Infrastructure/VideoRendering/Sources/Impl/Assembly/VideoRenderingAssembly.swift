import Foundation
import Media
import VideoRendering

public enum VideoRenderingAssembly {
    public static func makeDefaultService(
        preferredExecutableURL: URL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    ) -> any FFmpegService {
        #if os(macOS)
        FFmpegKitFFmpegService()
        #else
        UnavailableFFmpegService()
        #endif
    }

    #if os(macOS)
    public static func makeProcessService(
        preferredExecutableURL: URL
    ) -> any FFmpegService {
        ProcessFFmpegService(
            preferredExecutableURL: preferredExecutableURL
        )
    }
    #endif

    public static func makeAudioPreparationService(
        ffmpegService: any FFmpegService,
        appName: String = "Framelingo",
        cacheRootURL: URL? = nil
    ) -> any AudioPreparationService {
        FFmpegAudioPreparationService(
            ffmpegService: ffmpegService,
            appName: appName,
            cacheRootURL: cacheRootURL
        )
    }

    public static func makeSubtitleScriptGenerator()
        -> any SubtitleScriptGenerating {
        ASSSubtitleExportService()
    }

    public static var usesEmbeddedBackend: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}
