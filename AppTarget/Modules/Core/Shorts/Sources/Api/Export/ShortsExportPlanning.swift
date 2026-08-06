import Foundation
import Subtitles
import Timeline
import VideoRendering

public struct ShortsExportPlanningInput {
    public var projectName: String
    public var shorts: [ShortDefinition]
    public var settings: ShortsExportSettings
    public var encodingSettings: VideoExportSettings
    public var editTimeline: EditTimeline?
    public var subtitles: [SubtitleSegment]
    public var sourceInfo: VideoSourceInfo?
    public var destinationDirectory: URL

    public init(
        projectName: String,
        shorts: [ShortDefinition],
        settings: ShortsExportSettings,
        encodingSettings: VideoExportSettings,
        editTimeline: EditTimeline?,
        subtitles: [SubtitleSegment],
        sourceInfo: VideoSourceInfo?,
        destinationDirectory: URL
    ) {
        self.projectName = projectName
        self.shorts = shorts
        self.settings = settings
        self.encodingSettings = encodingSettings
        self.editTimeline = editTimeline
        self.subtitles = subtitles
        self.sourceInfo = sourceInfo
        self.destinationDirectory = destinationDirectory
    }
}

public enum ShortsExportPlanningFailure: Error, Equatable, LocalizedError, Sendable {
    case emptyClipPlan

    public var errorDescription: String? {
        switch self {
        case .emptyClipPlan:
            return "The edit timeline has no clips to export. Review your cuts in Edit mode."
        }
    }
}

public enum ShortExportPlanningOutcome: Equatable, Sendable {
    case valid(ShortExportPlan)
    case invalid(ShortsExportPlanningFailure)
}

public struct ShortExportBatchItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var shortID: UUID
    public var displayName: String
    public var outputURL: URL
    public var encodingSettings: VideoExportSettings
    public var sourceInfo: VideoSourceInfo?
    public var outcome: ShortExportPlanningOutcome

    public init(
        id: UUID = UUID(),
        shortID: UUID,
        displayName: String,
        outputURL: URL,
        encodingSettings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        outcome: ShortExportPlanningOutcome
    ) {
        self.id = id
        self.shortID = shortID
        self.displayName = displayName
        self.outputURL = outputURL
        self.encodingSettings = encodingSettings
        self.sourceInfo = sourceInfo
        self.outcome = outcome
    }
}

public enum ShortsReframeMapper {
    public static func plan(
        for short: ShortDefinition,
        defaults: ShortsExportSettings,
        sourceInfo: VideoSourceInfo?
    ) -> VerticalReframePlan {
        VerticalReframePlan(
            mode: short.effectiveReframing(default: defaults.reframing) == .crop ? .crop : .blurPad,
            cropOffsetX: short.cropOffsetX,
            cropKeyframes: short.cropKeyframes.map {
                VideoCropKeyframe(id: $0.id, timeMs: $0.timeMs, offsetX: $0.offsetX)
            },
            sourceWidth: sourceInfo?.width,
            sourceHeight: sourceInfo?.height
        )
    }
}

public struct ShortsExportPlanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func plan(_ input: ShortsExportPlanningInput) -> [ShortExportBatchItem] {
        let orderedShorts = input.shorts.sorted { lhs, rhs in
            if lhs.startMs == rhs.startMs {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.startMs < rhs.startMs
        }
        guard !orderedShorts.isEmpty else {
            return []
        }

        var encodingSettings = input.encodingSettings
        encodingSettings.resolution = .original
        encodingSettings.frameRate = .original
        var reservedPaths: Set<String> = []

        return orderedShorts.enumerated().map { position, short in
            let baseName = ShortsFilenameTemplate.baseName(
                template: input.settings.filenameTemplate,
                projectName: input.projectName,
                index: position + 1,
                totalCount: orderedShorts.count,
                shortTitle: short.title
            )
            let outputURL = availableURL(
                in: input.destinationDirectory,
                baseName: baseName,
                reservedPaths: reservedPaths
            )
            reservedPaths.insert(outputURL.path)

            let outcome: ShortExportPlanningOutcome
            do {
                outcome = .valid(ShortExportPlan(
                    clips: try ShortsClipPlanner.clips(for: short, editTimeline: input.editTimeline),
                    subtitles: ShortsClipPlanner.localizedSubtitles(input.subtitles, for: short),
                    subtitleStyle: input.settings.subtitleStyle,
                    platform: short.effectivePlatform(default: input.settings.platform),
                    reframe: ShortsReframeMapper.plan(
                        for: short,
                        defaults: input.settings,
                        sourceInfo: input.sourceInfo
                    ),
                    hookText: short.trimmedHookText,
                    hookFontSize: input.settings.hookFontSize,
                    durationMs: short.durationMs,
                    burnSubtitlesIntoVideo: input.settings.burnSubtitlesIntoVideo,
                    writeSRTSidecar: input.settings.exportSRTSidecar
                ))
            } catch {
                outcome = .invalid(.emptyClipPlan)
            }

            return ShortExportBatchItem(
                shortID: short.id,
                displayName: "\(input.projectName) — \(short.title)",
                outputURL: outputURL,
                encodingSettings: encodingSettings,
                sourceInfo: input.sourceInfo,
                outcome: outcome
            )
        }
    }

    private func availableURL(
        in directory: URL,
        baseName: String,
        reservedPaths: Set<String>
    ) -> URL {
        var suffix = 1
        while true {
            let name = suffix == 1 ? baseName : "\(baseName) \(suffix)"
            let candidate = directory.appendingPathComponent(name).appendingPathExtension("mp4")
            if !fileManager.fileExists(atPath: candidate.path), !reservedPaths.contains(candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }
}
