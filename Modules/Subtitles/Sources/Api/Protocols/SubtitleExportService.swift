import Foundation

public protocol SubtitleExportService {
    func export(
        request: SubtitleExportRequest,
        kind: SubtitleExportKind,
        destinationURL: URL
    ) async throws

    func exportSRT(
        request: SubtitleExportRequest,
        textMode: SubtitleTextMode,
        destinationURL: URL
    ) async throws
}
