import SpeakerAnalysis

extension Array where Element == SubtitleCueWarning {
    mutating func appendUnique(_ warning: SubtitleCueWarning) {
        guard !contains(warning) else {
            return
        }
        append(warning)
    }
}
