import Foundation

public enum SubtitleFileFormat: String, CaseIterable, Identifiable, Equatable {
    case srt
    case vtt
    case ass
    case ssa
    case txt
    case sbv

    public var id: String { rawValue }

    public var readableName: String {
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

    public var supportedExtensions: [String] {
        [rawValue]
    }

    public var isSupported: Bool {
        true
    }

    public static var allSupportedExtensions: [String] {
        allCases.flatMap(\.supportedExtensions)
    }

    public static func format(for fileURL: URL) throws -> SubtitleFileFormat {
        let fileExtension = fileURL.pathExtension.lowercased()
        guard let format = allCases.first(where: { $0.supportedExtensions.contains(fileExtension) }) else {
            throw SubtitleImportError.unsupportedFormat(fileExtension.isEmpty ? "unknown" : fileExtension)
        }

        return format
    }
}
