import Foundation

public struct SubtitleImportPreview: Identifiable, Equatable {
    public let id = UUID()
    public let fileURL: URL
    public let format: SubtitleFileFormat
    public let detectedEncodingName: String?
    public let segments: [SubtitleSegment]
    public let warnings: [String]

    public init(
        fileURL: URL,
        format: SubtitleFileFormat,
        detectedEncodingName: String?,
        segments: [SubtitleSegment],
        warnings: [String]
    ) {
        self.fileURL = fileURL
        self.format = format
        self.detectedEncodingName = detectedEncodingName
        self.segments = segments
        self.warnings = warnings
    }
}
