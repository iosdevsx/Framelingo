import Foundation
import Subtitles
import VideoExport
import VideoRendering

@MainActor
public enum VideoExportAssembly {
    public static func makeQueue(
        makeFFmpegService: @escaping @MainActor () -> any FFmpegService,
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        subtitleExportService: any SubtitleExportService,
        fileManager: FileManager = .default
    ) -> any VideoExportQueue {
        VideoExportQueueImpl(
            worker: VideoExportWorker(
                subtitleScriptGenerator: subtitleScriptGenerator,
                subtitleExportService: subtitleExportService,
                fileManager: fileManager
            ),
            makeFFmpegService: makeFFmpegService
        )
    }
}
