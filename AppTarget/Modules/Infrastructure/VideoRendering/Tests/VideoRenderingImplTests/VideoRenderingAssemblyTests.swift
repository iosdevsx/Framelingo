import Testing
import VideoRendering
import VideoRenderingImpl

@Suite("VideoRendering assembly")
struct VideoRenderingAssemblyTests {
    @Test("Assembly exposes API-typed services")
    func apiTypedServices() {
        let service: any FFmpegService = VideoRenderingAssembly
            .makeDefaultService()
        let scripts: any SubtitleScriptGenerating = VideoRenderingAssembly
            .makeSubtitleScriptGenerator()
        _ = (service, scripts)
    }
}
