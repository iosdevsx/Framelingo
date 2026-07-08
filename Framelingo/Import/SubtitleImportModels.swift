import Foundation

enum SubtitleFileFormat: String, CaseIterable, Identifiable, Equatable {
    case srt
    case vtt
    case ass
    case ssa
    case txt
    case sbv

    var id: String { rawValue }

    var readableName: String {
        switch self {
        case .srt:
            "SubRip SRT"
        case .vtt:
            "WebVTT"
        case .ass:
            "ASS"
        case .ssa:
            "SSA"
        case .txt:
            "Plain Text"
        case .sbv:
            "SBV"
        }
    }

    var supportedExtensions: [String] {
        [rawValue]
    }

    var isSupported: Bool {
        true
    }

    static var allSupportedExtensions: [String] {
        allCases.flatMap(\.supportedExtensions)
    }

    static func format(for fileURL: URL) throws -> SubtitleFileFormat {
        let fileExtension = fileURL.pathExtension.lowercased()
        guard let format = allCases.first(where: { $0.supportedExtensions.contains(fileExtension) }) else {
            throw SubtitleImportError.unsupportedFormat(fileExtension.isEmpty ? "unknown" : fileExtension)
        }

        return format
    }
}

enum SubtitleImportMode: String, CaseIterable, Identifiable {
    case replaceExisting
    case appendToExisting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .replaceExisting:
            "Replace existing subtitles"
        case .appendToExisting:
            "Append to existing subtitles"
        }
    }
}

enum SubtitleImportDestination: String, CaseIterable, Identifiable {
    case original
    case translated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            "Original text"
        case .translated:
            "Translated text"
        }
    }

    var description: String {
        switch self {
        case .original:
            "Imported subtitle text will be stored as source/original text."
        case .translated:
            "Imported subtitle text will be stored as translated text."
        }
    }
}

struct SubtitleImportPreview: Identifiable, Equatable {
    let id = UUID()
    let fileURL: URL
    let format: SubtitleFileFormat
    let detectedEncodingName: String?
    let segments: [SubtitleSegment]
    let warnings: [String]
}

enum SubtitleImportError: LocalizedError, Equatable {
    case unsupportedFormat(String)
    case fileReadFailed(String)
    case encodingDetectionFailed
    case emptyFile
    case parsingFailed(String)
    case noSegmentsFound
    case invalidTimecode(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let fileExtension):
            "Unsupported subtitle format: .\(fileExtension). Supported formats: srt, vtt, ass, ssa, txt, sbv."
        case .fileReadFailed(let message):
            "Could not read subtitle file. \(message)"
        case .encodingDetectionFailed:
            "Could not detect subtitle file encoding."
        case .emptyFile:
            "Subtitle file is empty."
        case .parsingFailed(let message):
            "Could not parse subtitle file. \(message)"
        case .noSegmentsFound:
            "No subtitle segments were found in this file."
        case .invalidTimecode(let value):
            "Invalid subtitle timecode: \(value)"
        case .userCancelled:
            "Subtitle import was cancelled."
        }
    }
}
