import Foundation
import Project
import Shorts
import Subtitles
import VideoRendering

@MainActor
public protocol ProjectSessionEffectCoordinating: AnyObject {
    func prepare() async
    func transcribe() async
    func clearTranscriptionState()
    func translate() async
    func previewSubtitleImport(from url: URL) async
    func clearSubtitleImportPreview()
    func applySubtitleImport(
        _ preview: SubtitleImportPreview,
        mode: SubtitleImportMode,
        destination: SubtitleImportDestination
    ) -> ProjectSessionEditResult
    func exportSubtitles(kind: SubtitleExportKind, to url: URL) async
    func exportProject(to url: URL) async
    func enqueueVideoExport(settings: VideoExportSettings, outputURL: URL)
    func enqueueShortsExport(shortIDs: [UUID], to directoryURL: URL)
}

@MainActor
public protocol ProjectSessionDisposing: AnyObject {
    func replace(with project: Project)
    func dispose()
}
