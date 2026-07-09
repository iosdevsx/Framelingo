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

enum FFmpegExportArgumentsBuilder {
    /// Filter arguments for subtitle burn-in. Without clips this is the plain
    /// `-vf ass=…` pass; with clips it becomes a `-filter_complex` graph that
    /// trims each kept range, concatenates them, and burns subtitles on the
    /// concatenated video (which matches the timeline-time subtitle timings).
    static func filterArguments(
        clips: [ExportClipRange]?,
        subtitlesPath: String,
        includeAudio: Bool
    ) -> [String] {
        guard let clips, !clips.isEmpty else {
            return ["-vf", "ass=\(escapedSubtitleFilterPath(subtitlesPath))"]
        }

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
        chains.append("[vcat]ass=\(escapedSubtitleFilterPath(subtitlesPath))[vout]")

        var arguments = ["-filter_complex", chains.joined(separator: ";"), "-map", "[vout]"]
        if includeAudio {
            arguments += ["-map", "[acat]"]
        }

        return arguments
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
