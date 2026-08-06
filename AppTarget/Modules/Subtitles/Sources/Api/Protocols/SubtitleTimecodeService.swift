public protocol SubtitleTimecodeService {
    func formatSRT(milliseconds: Int) -> String
    func formatVTT(milliseconds: Int) -> String
    func parseSRT(_ value: String) throws -> Int
}
