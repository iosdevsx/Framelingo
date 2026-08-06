import FFmpeg
import Testing

struct FFmpegModuleTests {
    @Test
    func embeddedBackendAvailabilityMatchesPlatform() {
        #if os(macOS)
        #expect(FFmpegModule.isEmbeddedBackendAvailable)
        #else
        #expect(!FFmpegModule.isEmbeddedBackendAvailable)
        #endif
    }
}
