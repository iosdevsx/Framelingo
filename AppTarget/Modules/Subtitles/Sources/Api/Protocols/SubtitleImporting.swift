import Foundation

public protocol SubtitleImporting {
    func importSubtitles(from fileURL: URL) async throws -> SubtitleImportPreview
}
