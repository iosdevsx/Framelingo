import SpeakerAnalysis

public struct SubtitleExportRequest: Equatable {
    public var segments: [SubtitleSegment]
    public var speakerLabels: [SpeakerLabel]
    public var options: SubtitleExportOptions

    public init(
        segments: [SubtitleSegment],
        speakerLabels: [SpeakerLabel] = [],
        options: SubtitleExportOptions = SubtitleExportOptions()
    ) {
        self.segments = segments
        self.speakerLabels = speakerLabels
        self.options = options
    }
}
