import Foundation
import Subtitles

struct DefaultSubtitleTimecodeService: SubtitleTimecodeService {
    func formatSRT(milliseconds: Int) -> String {
        formatSRTTimestamp(milliseconds)
    }

    func formatVTT(milliseconds: Int) -> String {
        formatSRTTimestamp(milliseconds).replacingOccurrences(of: ",", with: ".")
    }

    func parseSRT(_ value: String) throws -> Int {
        try parseSRTTimestamp(value)
    }
}
