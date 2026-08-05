import Foundation

public struct SubtitleExportOptions: Codable, Equatable {
    public var includeSpeakerLabels: Bool
    public var speakerFormat: SpeakerExportFormat

    public init(
        includeSpeakerLabels: Bool = false,
        speakerFormat: SpeakerExportFormat = .squareBrackets
    ) {
        self.includeSpeakerLabels = includeSpeakerLabels
        self.speakerFormat = speakerFormat
    }
}
