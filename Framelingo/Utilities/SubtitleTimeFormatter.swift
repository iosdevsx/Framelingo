import Foundation

enum SubtitleTimeFormatter {
    static func format(milliseconds: Int) -> String {
        formatSRTTimestamp(milliseconds)
    }

    static func parse(_ value: String) -> Int? {
        do {
            return try parseSRTTimestamp(value)
        } catch {
            return nil
        }
    }
}
