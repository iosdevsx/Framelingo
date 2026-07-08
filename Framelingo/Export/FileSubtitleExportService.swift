import Foundation

final class FileSubtitleExportService: SubtitleExportService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func export(project: Project, kind: SubtitleExportKind, destinationURL: URL) async throws {
        guard !project.subtitles.isEmpty else {
            throw SubtitleExportError.emptySubtitles
        }

        let content = try exportContent(
            for: project.subtitles,
            kind: kind,
            speakerLabels: project.speakerLabels,
            exportOptions: project.speakerExportOptions
        )
        let data = Data(content.utf8)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        guard fileManager.createFile(atPath: destinationURL.path, contents: data) else {
            throw AppError.exportFailed
        }
    }

    private func exportContent(
        for segments: [SubtitleSegment],
        kind: SubtitleExportKind,
        speakerLabels: [SpeakerLabel],
        exportOptions: SubtitleExportOptions
    ) throws -> String {
        switch kind {
        case .translatedSRT:
            subtitlesToSRT(
                segments,
                mode: .translatedFallbackToOriginal,
                speakerLabels: speakerLabels,
                exportOptions: exportOptions
            )
        case .originalSRT:
            subtitlesToSRT(
                segments,
                mode: .original,
                speakerLabels: speakerLabels,
                exportOptions: exportOptions
            )
        case .translatedVTT:
            subtitlesToVTT(
                segments,
                mode: .translatedFallbackToOriginal,
                speakerLabels: speakerLabels,
                exportOptions: exportOptions
            )
        case .originalVTT:
            subtitlesToVTT(
                segments,
                mode: .original,
                speakerLabels: speakerLabels,
                exportOptions: exportOptions
            )
        case .txt:
            subtitlesToTXT(segments)
        }
    }

    private func subtitlesToVTT(
        _ segments: [SubtitleSegment],
        mode: SubtitleTextMode,
        speakerLabels: [SpeakerLabel],
        exportOptions: SubtitleExportOptions
    ) -> String {
        let blocks = sortedSegments(segments)
            .map { segment in
                """
                \(formatVTTTimestamp(segment.startMs)) --> \(formatVTTTimestamp(segment.endMs))
                \(subtitleExportText(
                    for: segment,
                    mode: mode,
                    speakerLabels: speakerLabels,
                    exportOptions: exportOptions,
                    preferredFormat: .webVTTVoiceTags
                ))
                """
            }
            .joined(separator: "\n\n")

        return "WEBVTT\n\n\(blocks)"
    }

    private func subtitlesToTXT(_ segments: [SubtitleSegment]) -> String {
        sortedSegments(segments)
            .map { text(for: $0, mode: .translatedFallbackToOriginal) }
            .joined(separator: "\n")
    }

    private func sortedSegments(_ segments: [SubtitleSegment]) -> [SubtitleSegment] {
        segments.sorted { first, second in
            first.startMs == second.startMs ? first.index < second.index : first.startMs < second.startMs
        }
    }

    private func formatVTTTimestamp(_ milliseconds: Int) -> String {
        formatSRTTimestamp(milliseconds).replacingOccurrences(of: ",", with: ".")
    }

    private func text(for segment: SubtitleSegment, mode: SubtitleTextMode) -> String {
        switch mode {
        case .original:
            segment.originalText
        case .translated:
            segment.translatedText
        case .translatedFallbackToOriginal:
            segment.hasTranslation ? segment.translatedText : segment.originalText
        }
    }
}
