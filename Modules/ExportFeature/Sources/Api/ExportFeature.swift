import Subtitles

/// Namespace marker for the export feature package.
public enum ExportFeature {}

public struct SubtitleExportOptionsState: Equatable {
    public let options: SubtitleExportOptions
    public let hasSpeakerLabels: Bool

    public init(options: SubtitleExportOptions, hasSpeakerLabels: Bool) {
        self.options = options
        self.hasSpeakerLabels = hasSpeakerLabels
    }
}

@MainActor
public struct SubtitleExportOptionsActions {
    private let updateAction: (SubtitleExportOptions) -> Void

    public init(update: @escaping (SubtitleExportOptions) -> Void) {
        self.updateAction = update
    }

    public func update(_ options: SubtitleExportOptions) {
        updateAction(options)
    }
}
