struct SubtitleSegmentationSettings: Equatable {
    var maxCharactersPerSegment = 90
    var minCharactersPerSegment = 12
    var maxDurationMs = 6_000
    var minDurationMs = 700
    var gapMs = 60
}
