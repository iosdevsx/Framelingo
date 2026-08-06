#if os(macOS)
@_exported import ffmpegkit
#endif

public enum FFmpegModule {
    public static var isEmbeddedBackendAvailable: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}
