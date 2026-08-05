import Foundation

enum FFmpegProgressParser {
    static func processedTimeValues(from data: Data, buffer: inout String) -> [Int] {
        guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
            return []
        }

        buffer.append(chunk)
        let lines = buffer.components(separatedBy: .newlines)
        buffer = lines.last ?? ""
        return lines.dropLast().compactMap(processedTimeMs(from:))
    }

    private static func processedTimeMs(from line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if let value = trimmed.value(after: "out_time_ms="),
           let microseconds = Int(value) {
            return max(0, microseconds / 1_000)
        }

        if let value = trimmed.value(after: "out_time=") {
            return parseTimestampMilliseconds(value)
        }

        return nil
    }

    private static func parseTimestampMilliseconds(_ value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard parts.count == 3,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return nil
        }

        let secondParts = parts[2].split(separator: ".", maxSplits: 1)
        guard let seconds = Int(secondParts[0]) else {
            return nil
        }

        let milliseconds: Int
        if secondParts.count == 2 {
            let fraction = String(secondParts[1].prefix(3))
            milliseconds = Int(fraction.padding(toLength: 3, withPad: "0", startingAt: 0)) ?? 0
        } else {
            milliseconds = 0
        }

        return ((hours * 60 + minutes) * 60 + seconds) * 1_000 + milliseconds
    }
}

private extension String {
    func value(after prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}
