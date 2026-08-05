import VideoRendering

public enum ExportClipPlanResolver {
    /// Returns `nil` when the project has no virtual cuts (export the full video),
    /// otherwise the kept source ranges in timeline order.
    public static func clips(for project: Project) throws -> [ExportClipRange]? {
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
