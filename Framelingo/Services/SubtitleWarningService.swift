import Foundation

struct SubtitleWarning: Equatable {
    enum Kind: Equatable { case warn, bad }
    let kind: Kind
    let message: String
}

enum SubtitleWarningService {
    static let cpsWarn: Double = 17
    static let cpsBad: Double = 21
    static let lineWarnChars: Int = 42
    static let minDurationSec: Double = 1.0
    static let maxDurationSec: Double = 7.0

    static func cps(for segment: SubtitleSegment) -> Double {
        let durationSec = Double(segment.durationMs) / 1000
        guard durationSec > 0 else { return 0 }
        let chars = segment.originalText.replacingOccurrences(of: "\n", with: "").count
        return Double(chars) / durationSec
    }

    static func longestLine(in segment: SubtitleSegment) -> Int {
        segment.originalText.components(separatedBy: "\n").map(\.count).max() ?? 0
    }

    static func lineCount(in segment: SubtitleSegment) -> Int {
        segment.originalText.components(separatedBy: "\n").count
    }

    static func warnings(for segment: SubtitleSegment) -> [SubtitleWarning] {
        var result: [SubtitleWarning] = []
        let durationSec = Double(segment.durationMs) / 1000
        let cpsValue = cps(for: segment)

        if cpsValue > cpsBad {
            result.append(.init(kind: .bad, message: "Reading speed \(String(format: "%.1f", cpsValue)) cps — too fast"))
        } else if cpsValue > cpsWarn {
            result.append(.init(kind: .warn, message: "Reading speed \(String(format: "%.1f", cpsValue)) cps"))
        }

        let longest = longestLine(in: segment)
        if longest > lineWarnChars {
            result.append(.init(kind: .warn, message: "Line over \(lineWarnChars) chars"))
        }

        if segment.durationMs > 0 && durationSec < minDurationSec {
            result.append(.init(kind: .warn, message: "Duration under \(minDurationSec)s"))
        }
        if durationSec > maxDurationSec {
            result.append(.init(kind: .warn, message: "Duration over \(maxDurationSec)s"))
        }

        return result
    }
}
