import Foundation
import Project
import Shorts
import SpeakerAnalysis
import Subtitles
import VideoRendering

public struct FullProjectVideoExportRequest {
    public let id: UUID
    public let project: Project
    public let settings: VideoExportSettings
    public let sourceInfo: VideoSourceInfo?
    public let outputURL: URL

    public init(
        id: UUID = UUID(),
        project: Project,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        outputURL: URL
    ) {
        self.id = id
        self.project = project
        self.settings = settings
        self.sourceInfo = sourceInfo
        self.outputURL = outputURL
    }
}

public struct ShortVideoExportRequest {
    public let id: UUID
    public let projectID: UUID
    public let projectName: String
    public let mediaURL: URL
    public let settings: VideoExportSettings
    public let sourceInfo: VideoSourceInfo?
    public let outputURL: URL
    public let plan: ShortExportPlan
    public let speakerLabels: [SpeakerLabel]
    public let speakerExportOptions: SubtitleExportOptions

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        projectName: String,
        mediaURL: URL,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        outputURL: URL,
        plan: ShortExportPlan,
        speakerLabels: [SpeakerLabel],
        speakerExportOptions: SubtitleExportOptions
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = projectName
        self.mediaURL = mediaURL
        self.settings = settings
        self.sourceInfo = sourceInfo
        self.outputURL = outputURL
        self.plan = plan
        self.speakerLabels = speakerLabels
        self.speakerExportOptions = speakerExportOptions
    }
}

public enum VideoExportRequest {
    case fullProject(FullProjectVideoExportRequest)
    case short(ShortVideoExportRequest)

    public var id: UUID {
        switch self {
        case .fullProject(let request): request.id
        case .short(let request): request.id
        }
    }

    public var projectName: String {
        switch self {
        case .fullProject(let request): request.project.displayName
        case .short(let request): request.projectName
        }
    }

    public var outputURL: URL {
        switch self {
        case .fullProject(let request): request.outputURL
        case .short(let request): request.outputURL
        }
    }

    public var durationMs: Int? {
        switch self {
        case .short(let request):
            return request.plan.durationMs
        case .fullProject(let request):
            if request.project.hasEditedTimeline,
               let durationMs = request.project.editTimeline?.totalDurationMs,
               durationMs > 0 {
                return durationMs
            }
            if let durationMs = request.project.mediaFile.durationMs, durationMs > 0 {
                return durationMs
            }
            let subtitleDurationMs = request.project.subtitles.map(\.endMs).max() ?? 0
            return subtitleDurationMs > 0 ? subtitleDurationMs : nil
        }
    }
}

public struct ShortsVideoExportBatchRequest {
    public let projectID: UUID
    public let mediaURL: URL
    public let speakerLabels: [SpeakerLabel]
    public let speakerExportOptions: SubtitleExportOptions
    public let items: [ShortExportBatchItem]

    public init(
        projectID: UUID,
        mediaURL: URL,
        speakerLabels: [SpeakerLabel],
        speakerExportOptions: SubtitleExportOptions,
        items: [ShortExportBatchItem]
    ) {
        self.projectID = projectID
        self.mediaURL = mediaURL
        self.speakerLabels = speakerLabels
        self.speakerExportOptions = speakerExportOptions
        self.items = items
    }
}
