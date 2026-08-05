import Foundation

public enum SubtitleTimeFormatter {
    public static func format(milliseconds: Int) -> String {
        let clamped = max(0, milliseconds)
        let hours = clamped / 3_600_000
        let minutes = (clamped % 3_600_000) / 60_000
        let seconds = (clamped % 60_000) / 1_000
        let milliseconds = clamped % 1_000
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }

    public static func parse(_ value: String) -> Int? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = normalized.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 3,
              let hours = Int(components[0]),
              let minutes = Int(components[1]) else {
            return nil
        }

        let secondsComponents = components[2].split(
            omittingEmptySubsequences: false,
            whereSeparator: { $0 == "," || $0 == "." }
        )
        guard secondsComponents.count == 2,
              let seconds = Int(secondsComponents[0]),
              let milliseconds = Int(secondsComponents[1]),
              hours >= 0,
              (0..<60).contains(minutes),
              (0..<60).contains(seconds),
              (0..<1_000).contains(milliseconds) else {
            return nil
        }

        return hours * 3_600_000 + minutes * 60_000 + seconds * 1_000 + milliseconds
    }
}
