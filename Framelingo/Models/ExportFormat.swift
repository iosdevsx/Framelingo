import Foundation

enum ExportFormat: String, CaseIterable, Codable, Identifiable {
    case srt
    case vtt
    case txt

    var id: String { rawValue }

    var displayName: String {
        rawValue.uppercased()
    }
}
