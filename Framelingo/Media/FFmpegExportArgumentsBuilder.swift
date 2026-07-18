import Foundation

/// A source-time range of the original video that survives edit-timeline cuts.
struct ExportClipRange: Equatable, Sendable {
    var sourceStartMs: Int
    var sourceEndMs: Int

    var durationMs: Int {
        max(0, sourceEndMs - sourceStartMs)
    }
}

enum ExportClipPlanError: LocalizedError, Equatable {
    case emptyPlan

    var errorDescription: String? {
        switch self {
        case .emptyPlan:
            return "The edit timeline has no clips to export. Review your cuts in Edit mode."
        }
    }
}

enum ExportClipPlanResolver {
    /// Returns `nil` when the project has no virtual cuts (export the full video),
    /// otherwise the kept source ranges in timeline order.
    static func clips(for project: Project) throws -> [ExportClipRange]? {
        guard let timeline = project.editTimeline, !timeline.clips.isEmpty else {
            return nil
        }

        // hasEditedTimeline covers tail trims (single clip from source 0 that is
        // shorter than the source); hasVirtualCuts covers degenerate timelines
        // that must fail visibly rather than silently export the full video.
        guard project.hasEditedTimeline || timeline.hasVirtualCuts else {
            return nil
        }

        let clips = timeline.clips
            .sorted { $0.timelineStartMs < $1.timelineStartMs }
            .map { ExportClipRange(sourceStartMs: $0.sourceStartMs, sourceEndMs: $0.sourceEndMs) }
            .filter { $0.durationMs > 0 }

        guard !clips.isEmpty else {
            throw ExportClipPlanError.emptyPlan
        }

        return clips
    }
}

/// Vertical (9:16) reframing parameters for shorts export. When source
/// dimensions are known and already match the output aspect, the graph
/// degenerates to a plain scale (no padding, no cropping).
struct VerticalReframePlan: Equatable, Sendable {
    var mode: ShortsReframing
    /// Horizontal position of the crop window, 0…1 (0.5 = centered). Ignored
    /// for blur-pad.
    var cropOffsetX: Double
    /// Discrete crop changes in short-local time. The last point at or before
    /// the current frame wins, producing hard cuts rather than animation.
    var cropKeyframes: [ShortCropKeyframe] = []
    var outputWidth: Int = ShortsExportSettings.verticalCanvasWidth
    var outputHeight: Int = ShortsExportSettings.verticalCanvasHeight
    var sourceWidth: Int?
    var sourceHeight: Int?

    var sourceMatchesOutputAspect: Bool {
        guard let sourceWidth, let sourceHeight, sourceWidth > 0, sourceHeight > 0 else {
            return false
        }

        let sourceAspect = Double(sourceWidth) / Double(sourceHeight)
        let outputAspect = Double(outputWidth) / Double(outputHeight)
        return abs(sourceAspect - outputAspect) < 0.01
    }
}

enum FFmpegExportArgumentsBuilder {
    /// Filter arguments for subtitle burn-in. Without clips this is the plain
    /// `-vf ass=…` pass; with clips it becomes a `-filter_complex` graph that
    /// trims each kept range, concatenates them, and burns subtitles on the
    /// concatenated video (which matches the timeline-time subtitle timings).
    /// A vertical reframe plan always uses `-filter_complex`, composing the
    /// reframing stages after concat (when cutting) and before the `ass` burn.
    static func filterArguments(
        clips: [ExportClipRange]?,
        subtitlesPath: String,
        includeAudio: Bool,
        targetSize: VideoOutputSize? = nil,
        targetFPS: Int? = nil,
        verticalReframe: VerticalReframePlan? = nil
    ) -> [String] {
        if let verticalReframe {
            return verticalFilterArguments(
                clips: clips,
                subtitlesPath: subtitlesPath,
                includeAudio: includeAudio,
                targetFPS: targetFPS,
                reframe: verticalReframe
            )
        }

        let videoFilters = outputVideoFilters(
            subtitlesPath: subtitlesPath,
            targetSize: targetSize,
            targetFPS: targetFPS
        )

        guard let clips, !clips.isEmpty else {
            return ["-vf", videoFilters.joined(separator: ",")]
        }

        var chains = clipChains(clips: clips, includeAudio: includeAudio)
        chains.append("[vcat]\(videoFilters.joined(separator: ","))[vout]")

        var arguments = ["-filter_complex", chains.joined(separator: ";"), "-map", "[vout]"]
        if includeAudio {
            arguments += ["-map", "[acat]"]
        }

        return arguments
    }

    private static func verticalFilterArguments(
        clips: [ExportClipRange]?,
        subtitlesPath: String,
        includeAudio: Bool,
        targetFPS: Int?,
        reframe: VerticalReframePlan
    ) -> [String] {
        let hasClips = clips?.isEmpty == false
        var chains: [String] = []
        var videoLabel = "[0:v]"
        if let clips, hasClips {
            chains = clipChains(clips: clips, includeAudio: includeAudio)
            videoLabel = "[vcat]"
        }

        var stages: [String] = []
        if let targetFPS, targetFPS > 0 {
            stages.append("fps=\(targetFPS)")
        }

        let width = reframe.outputWidth
        let height = reframe.outputHeight
        let assFilter = "ass=\(escapedSubtitleFilterPath(subtitlesPath))"

        if reframe.sourceMatchesOutputAspect {
            stages += ["scale=\(width):\(height)", assFilter]
            chains.append("\(videoLabel)\(stages.joined(separator: ","))[vout]")
        } else {
            switch reframe.mode {
            case .blurPad:
                let prefix = stages.isEmpty ? "" : stages.joined(separator: ",") + ","
                chains.append("\(videoLabel)\(prefix)split[shortmain][shortbgsrc]")
                chains.append("[shortbgsrc]scale=\(width):\(height):force_original_aspect_ratio=increase,crop=\(width):\(height),boxblur=luma_radius=32:luma_power=2[shortbg]")
                chains.append("[shortmain]scale=\(width):\(height):force_original_aspect_ratio=decrease:force_divisible_by=2[shortfg]")
                chains.append("[shortbg][shortfg]overlay=(W-w)/2:(H-h)/2,\(assFilter)[vout]")
            case .crop:
                let cropX: String
                if reframe.cropKeyframes.isEmpty {
                    cropX = "(iw-out_w)*\(clampedCropOffset(reframe.cropOffsetX))"
                } else {
                    cropX = "(iw-out_w)*(\(cropOffsetExpression(for: reframe)))"
                }
                stages.append("crop=w='min(iw,ih*\(width)/\(height))':h='min(ih,iw*\(height)/\(width))':x='\(cropX)':y='(ih-out_h)/2'")
                stages += ["scale=\(width):\(height)", assFilter]
                chains.append("\(videoLabel)\(stages.joined(separator: ","))[vout]")
            }
        }

        var arguments = ["-filter_complex", chains.joined(separator: ";"), "-map", "[vout]"]
        if hasClips {
            if includeAudio {
                arguments += ["-map", "[acat]"]
            }
        } else if includeAudio {
            // Optional mapping: sources without an audio stream export
            // video-only instead of failing the graph.
            arguments += ["-map", "0:a?"]
        }

        return arguments
    }

    private static func cropOffsetExpression(for reframe: VerticalReframePlan) -> String {
        var expression = clampedCropOffset(reframe.cropOffsetX)

        for keyframe in reframe.cropKeyframes.sorted(by: { $0.timeMs < $1.timeMs }) {
            let time = seconds(fromMs: keyframe.timeMs)
            let offset = String(format: "%.4f", min(max(keyframe.offsetX, 0), 1))
            expression = "if(gte(t,\(time)),\(offset),\(expression))"
        }

        return expression
    }

    private static func clampedCropOffset(_ value: Double) -> String {
        String(format: "%.4f", min(max(value, 0), 1))
    }

    private static func clipChains(clips: [ExportClipRange], includeAudio: Bool) -> [String] {
        var chains: [String] = []
        var concatInputs = ""

        for (index, clip) in clips.enumerated() {
            let start = seconds(fromMs: clip.sourceStartMs)
            let end = seconds(fromMs: clip.sourceEndMs)
            chains.append("[0:v]trim=start=\(start):end=\(end),setpts=PTS-STARTPTS[v\(index)]")
            concatInputs += "[v\(index)]"
            if includeAudio {
                chains.append("[0:a]atrim=start=\(start):end=\(end),asetpts=PTS-STARTPTS[a\(index)]")
                concatInputs += "[a\(index)]"
            }
        }

        let concatOutputs = includeAudio ? "[vcat][acat]" : "[vcat]"
        chains.append("\(concatInputs)concat=n=\(clips.count):v=1:a=\(includeAudio ? 1 : 0)\(concatOutputs)")
        return chains
    }

    private static func outputVideoFilters(
        subtitlesPath: String,
        targetSize: VideoOutputSize?,
        targetFPS: Int?
    ) -> [String] {
        var filters: [String] = []

        if let targetFPS, targetFPS > 0 {
            filters.append("fps=\(targetFPS)")
        }

        if let targetSize, targetSize.width > 0, targetSize.height > 0 {
            filters.append("scale=\(targetSize.width):\(targetSize.height)")
        }

        filters.append("ass=\(escapedSubtitleFilterPath(subtitlesPath))")
        return filters
    }

    /// Audio codec arguments: stream copy is only possible when the source is
    /// passed through untrimmed; concatenated segments must be re-encoded.
    static func audioCodecArguments(
        clips: [ExportClipRange]?,
        includeAudio: Bool
    ) -> [String] {
        guard let clips, !clips.isEmpty else {
            return ["-c:a", "copy"]
        }

        return includeAudio ? ["-c:a", "aac", "-b:a", "192k"] : []
    }

    static func seconds(fromMs milliseconds: Int) -> String {
        let clamped = max(0, milliseconds)
        return String(format: "%d.%03d", clamped / 1_000, clamped % 1_000)
    }

    static func escapedSubtitleFilterPath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: ":", with: "\\:")
    }

    /// Matches FFmpeg's complaint when `[0:a]` refers to a video without an
    /// audio stream, so callers can retry with a video-only graph.
    static func indicatesMissingAudioStream(_ output: String) -> Bool {
        output.contains("matches no streams")
    }
}
