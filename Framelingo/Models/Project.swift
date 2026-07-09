import Foundation

struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var mediaFile: MediaFile
    var sourceLanguage: String
    var targetLanguage: String
    var subtitles: [SubtitleSegment]
    var wordTimings: [WordTiming]
    var speakers: [Speaker]
    var speakerLabels: [SpeakerLabel]
    var speakerSegments: [SpeakerSegment]
    var status: ProcessingStatus
    var videoExportSettings: VideoExportSettings
    var speakerExportOptions: SubtitleExportOptions
    var editTimeline: EditTimeline?

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? mediaFile.fileName : trimmedName
    }

    var hasEditedTimeline: Bool {
        guard let editTimeline, !editTimeline.isEmpty else {
            return false
        }

        if editTimeline.hasVirtualCuts {
            return true
        }

        // A tail trim leaves a single clip starting at source 0, which
        // hasVirtualCuts cannot distinguish from an untouched timeline —
        // only a comparison against the source duration can.
        guard let sourceDurationMs, sourceDurationMs > 0 else {
            return false
        }

        return editTimeline.totalDurationMs < sourceDurationMs
    }

    private var sourceDurationMs: Int? {
        if let durationMs = mediaFile.durationMs, durationMs > 0 {
            return durationMs
        }

        let subtitleDurationMs = subtitles.map(\.endMs).max() ?? 0
        return subtitleDurationMs > 0 ? subtitleDurationMs : nil
    }

    func speaker(for segment: SubtitleSegment) -> Speaker? {
        guard let speakerID = segment.speaker else { return nil }
        return speakers.first(where: { $0.id == speakerID })
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case updatedAt
        case mediaFile
        case sourceLanguage
        case targetLanguage
        case subtitles
        case wordTimings
        case speakers
        case speakerLabels
        case speakerSegments
        case status
        case videoExportSettings
        case speakerExportOptions
        case editTimeline
    }

    init(
        id: UUID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        mediaFile: MediaFile,
        sourceLanguage: String,
        targetLanguage: String,
        subtitles: [SubtitleSegment],
        wordTimings: [WordTiming] = [],
        speakers: [Speaker] = Speaker.defaults,
        speakerLabels: [SpeakerLabel] = [],
        speakerSegments: [SpeakerSegment] = [],
        status: ProcessingStatus,
        videoExportSettings: VideoExportSettings = VideoExportSettings(),
        speakerExportOptions: SubtitleExportOptions = SubtitleExportOptions(),
        editTimeline: EditTimeline? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.mediaFile = mediaFile
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.subtitles = subtitles
        self.wordTimings = wordTimings
        self.speakers = speakers
        self.speakerLabels = speakerLabels
        self.speakerSegments = speakerSegments
        self.status = status
        self.videoExportSettings = videoExportSettings
        self.speakerExportOptions = speakerExportOptions
        self.editTimeline = editTimeline
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        mediaFile = try container.decode(MediaFile.self, forKey: .mediaFile)
        sourceLanguage = try container.decode(String.self, forKey: .sourceLanguage)
        targetLanguage = try container.decode(String.self, forKey: .targetLanguage)
        subtitles = try container.decode([SubtitleSegment].self, forKey: .subtitles)
        wordTimings = try container.decodeIfPresent([WordTiming].self, forKey: .wordTimings) ?? []
        speakers = try container.decodeIfPresent([Speaker].self, forKey: .speakers) ?? Speaker.defaults
        speakerLabels = try container.decodeIfPresent([SpeakerLabel].self, forKey: .speakerLabels) ?? []
        speakerSegments = try container.decodeIfPresent([SpeakerSegment].self, forKey: .speakerSegments) ?? []
        status = try container.decode(ProcessingStatus.self, forKey: .status)
        videoExportSettings = try container.decodeIfPresent(VideoExportSettings.self, forKey: .videoExportSettings) ?? VideoExportSettings()
        speakerExportOptions = try container.decodeIfPresent(SubtitleExportOptions.self, forKey: .speakerExportOptions) ?? SubtitleExportOptions()
        editTimeline = try container.decodeIfPresent(EditTimeline.self, forKey: .editTimeline)
    }
}
