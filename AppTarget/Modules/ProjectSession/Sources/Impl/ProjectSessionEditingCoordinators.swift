import Foundation
import Project
import ProjectSession
import Shorts
import Subtitles
import Timeline

struct SubtitleEditingCoordinator {
    private let structural = SubtitleStructuralEditingPolicy()

    func update(_ segment: SubtitleSegment, in project: Project, durationMs: Int) -> (Project, String?)? {
        guard segment.startMs >= 0,
              segment.endMs > segment.startMs,
              let oldIndex = project.subtitles.firstIndex(where: { $0.id == segment.id }) else { return nil }
        var candidate = project
        let previous = candidate.subtitles[oldIndex]
        var message: String?
        if previous.startMs != segment.startMs || previous.endMs != segment.endMs {
            let result = SubtitleTimingValidator.updateSegmentTimingResult(
                segments: candidate.subtitles,
                id: segment.id,
                startMs: segment.startMs,
                endMs: segment.endMs,
                durationMs: durationMs
            )
            candidate.subtitles = result.segments
            if result.adjustment == .adjustedToConstraints {
                message = "Timing adjusted to keep a minimum \(SubtitleTimingValidator.minimumDurationMs)ms duration and \(SubtitleTimingValidator.minimumGapMs)ms gap between subtitles."
            }
        }
        guard let index = candidate.subtitles.firstIndex(where: { $0.id == segment.id }) else { return nil }
        candidate.subtitles[index].originalText = segment.originalText
        candidate.subtitles[index].translatedText = segment.translatedText
        candidate.subtitles[index].speaker = segment.speaker
        candidate.subtitles[index].speakerId = segment.speakerId
        candidate.subtitles[index].confidence = segment.confidence
        candidate.subtitles[index].warnings = segment.warnings
        candidate.subtitles = SubtitleTimingValidator.reindexed(candidate.subtitles)
        return (candidate, message)
    }

    func structural(
        _ operation: Operation,
        id: UUID,
        in project: Project
    ) throws -> (Project, UUID?) {
        let result: SubtitleStructuralEditResult
        switch operation {
        case .split: result = try structural.split(segments: project.subtitles, id: id)
        case .merge: result = try structural.mergeWithNext(segments: project.subtitles, id: id)
        case .delete: result = try structural.delete(segments: project.subtitles, id: id)
        case .add: result = try structural.addAfter(segments: project.subtitles, id: id)
        }
        var candidate = project
        candidate.subtitles = result.segments
        return (candidate, result.selectedSegmentID)
    }

    enum Operation { case split, merge, delete, add }
}

struct TimelineEditingCoordinator {
    let editor: any EditTimelineEditing
    private let mapping = SubtitleTimelineMappingService()

    func resolvedTimeline(for project: Project) -> EditTimeline? {
        if let timeline = project.editTimeline, !timeline.isEmpty { return timeline }
        guard let duration = sourceDurationMs(for: project), duration > 0 else { return nil }
        return editor.makeInitialTimeline(durationMs: duration)
    }

    func rippleDelete(project: Project, range: VideoCutRange) throws -> Project {
        guard let timeline = resolvedTimeline(for: project) else { throw EditTimelineError.invalidDuration }
        var candidate = project
        candidate.editTimeline = try editor.rippleDeleteRange(timeline: timeline, range: range)
        candidate.subtitles = mapping.rippleDeleteSubtitles(segments: project.subtitles, range: range)
        candidate.shorts = mapping.rippleDeleteShorts(shorts: project.shorts, range: range)
        candidate.wordTimings = project.wordTimings.compactMap { timing in
            guard let interval = mappedInterval(
                startMs: Int((timing.start * 1_000).rounded()),
                endMs: Int((timing.end * 1_000).rounded()),
                deleting: range
            ) else { return nil }
            var updated = timing
            updated.start = Double(interval.start) / 1_000
            updated.end = Double(interval.end) / 1_000
            return updated
        }
        candidate.speakerSegments = project.speakerSegments.compactMap { segment in
            guard let interval = mappedInterval(
                startMs: Int((segment.start * 1_000).rounded()),
                endMs: Int((segment.end * 1_000).rounded()),
                deleting: range
            ) else { return nil }
            var updated = segment
            updated.start = Double(interval.start) / 1_000
            updated.end = Double(interval.end) / 1_000
            return updated
        }
        return candidate
    }

    func sourceDurationMs(for project: Project) -> Int? {
        if let duration = project.mediaFile.durationMs, duration > 0 { return duration }
        let duration = project.subtitles.map(\.endMs).max() ?? 0
        return duration > 0 ? duration : nil
    }

    func durationMs(for project: Project) -> Int {
        if let duration = project.editTimeline?.totalDurationMs, duration > 0 { return duration }
        return sourceDurationMs(for: project) ?? 0
    }

    private func mappedInterval(
        startMs: Int,
        endMs: Int,
        deleting range: VideoCutRange
    ) -> (start: Int, end: Int)? {
        let cut = range.normalized
        let duration = cut.durationMs
        guard duration > 0 else { return (startMs, endMs) }
        if endMs <= cut.startMs { return (startMs, endMs) }
        if startMs >= cut.endMs { return (startMs - duration, endMs - duration) }
        let mappedStart = min(startMs, cut.startMs)
        let mappedEnd = endMs > cut.endMs ? endMs - duration : cut.startMs
        return mappedEnd > mappedStart ? (mappedStart, mappedEnd) : nil
    }
}

struct ShortsEditingCoordinator {
    private let policy = ShortsEditingPolicy()

    func add(project: Project, title: String, startMs: Int, endMs: Int) throws -> (Project, UUID) {
        let result = try policy.add(shorts: project.shorts, title: title, startMs: startMs, endMs: endMs)
        var candidate = project
        candidate.shorts = result.shorts
        return (candidate, result.editedShortID)
    }

    func replace(project: Project, short: ShortDefinition) throws -> Project? {
        let result = try policy.update(shorts: project.shorts, id: short.id) { $0 = short }
        guard result.didChange else { return nil }
        var candidate = project
        candidate.shorts = result.shorts
        return candidate
    }

    func range(project: Project, id: UUID, startMs: Int, endMs: Int) throws -> Project? {
        let result = try policy.updateRange(shorts: project.shorts, id: id, startMs: startMs, endMs: endMs)
        guard result.didChange else { return nil }
        var candidate = project
        candidate.shorts = result.shorts
        return candidate
    }

    func crop(project: Project, id: UUID, timelineTimeMs: Int, offsetX: Double) throws -> Project? {
        let result = try policy.upsertCropKeyframe(shorts: project.shorts, id: id, timelineTimeMs: timelineTimeMs, offsetX: offsetX)
        guard result.didChange else { return nil }
        var candidate = project
        candidate.shorts = result.shorts
        return candidate
    }

    func deleteCrop(project: Project, shortID: UUID, keyframeID: UUID) throws -> Project? {
        let result = try policy.deleteCropKeyframe(shorts: project.shorts, shortID: shortID, keyframeID: keyframeID)
        guard result.didChange else { return nil }
        var candidate = project
        candidate.shorts = result.shorts
        return candidate
    }

    func delete(project: Project, id: UUID) throws -> Project {
        let result = try policy.delete(shorts: project.shorts, id: id)
        var candidate = project
        candidate.shorts = result.shorts
        return candidate
    }
}
