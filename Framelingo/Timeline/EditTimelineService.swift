import Foundation

enum EditTimelineError: LocalizedError, Equatable {
    case invalidDuration
    case invalidRange
    case cannotDeleteEntireTimeline
    case clipNotFound
    case splitOutsideTimeline

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Video duration is unknown. Open the video first."
        case .invalidRange:
            return "Select a range of at least 500 ms."
        case .cannotDeleteEntireTimeline:
            return "Cannot delete the entire timeline."
        case .clipNotFound:
            return "Selected clip was not found."
        case .splitOutsideTimeline:
            return "Playhead is outside the editable timeline."
        }
    }
}

enum EditTimelinePlaybackAdvance: Equatable {
    case paused
    case finished(totalDurationMs: Int)
    case seekWithinClip(timelineMs: Int)
    case advanceToNextClip(TimelineClip)
}

struct EditTimelineService {
    private let minimumClipDurationMs = 100

    func makeInitialTimeline(durationMs: Int) -> EditTimeline {
        let duration = max(0, durationMs)
        guard duration > 0 else {
            return EditTimeline(clips: [], totalDurationMs: 0)
        }

        return EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: duration,
                    timelineStartMs: 0,
                    timelineEndMs: duration
                )
            ],
            totalDurationMs: duration
        )
    }

    func rippleDeleteRange(
        timeline: EditTimeline,
        range: VideoCutRange
    ) throws -> EditTimeline {
        let normalizedRange = range.normalized
        guard normalizedRange.durationMs >= 500 else {
            throw EditTimelineError.invalidRange
        }

        let timelineDuration = timeline.totalDurationMs
        let deleteStart = max(0, min(normalizedRange.startMs, timelineDuration))
        let deleteEnd = max(0, min(normalizedRange.endMs, timelineDuration))
        guard deleteEnd - deleteStart >= 500 else {
            throw EditTimelineError.invalidRange
        }

        var keptClips: [TimelineClip] = []

        for clip in timeline.clips {
            if clip.timelineEndMs <= deleteStart || clip.timelineStartMs >= deleteEnd {
                keptClips.append(clip)
                continue
            }

            if deleteStart > clip.timelineStartMs {
                let leftDuration = deleteStart - clip.timelineStartMs
                if leftDuration >= minimumClipDurationMs {
                    var leftClip = clip
                    leftClip.sourceEndMs = clip.sourceStartMs + leftDuration
                    leftClip.timelineEndMs = deleteStart
                    keptClips.append(leftClip)
                }
            }

            if deleteEnd < clip.timelineEndMs {
                let rightDuration = clip.timelineEndMs - deleteEnd
                if rightDuration >= minimumClipDurationMs {
                    let sourceOffset = deleteEnd - clip.timelineStartMs
                    var rightClip = clip
                    rightClip.id = UUID()
                    rightClip.sourceStartMs = clip.sourceStartMs + sourceOffset
                    rightClip.timelineStartMs = deleteEnd
                    keptClips.append(rightClip)
                }
            }
        }

        guard !keptClips.isEmpty else {
            throw EditTimelineError.cannotDeleteEntireTimeline
        }

        return recalculateTimelinePositions(clips: keptClips)
    }

    func splitAt(
        timeline: EditTimeline,
        timelineMs: Int
    ) throws -> EditTimeline {
        guard let clip = clip(atTimelineTime: timelineMs, in: timeline) else {
            throw EditTimelineError.splitOutsideTimeline
        }

        let leftDuration = timelineMs - clip.timelineStartMs
        let rightDuration = clip.timelineEndMs - timelineMs
        guard leftDuration >= minimumClipDurationMs, rightDuration >= minimumClipDurationMs else {
            throw EditTimelineError.invalidRange
        }

        var clips: [TimelineClip] = []
        for currentClip in timeline.clips {
            guard currentClip.id == clip.id else {
                clips.append(currentClip)
                continue
            }

            var leftClip = currentClip
            leftClip.sourceEndMs = currentClip.sourceStartMs + leftDuration
            leftClip.timelineEndMs = timelineMs

            var rightClip = currentClip
            rightClip.id = UUID()
            rightClip.sourceStartMs = leftClip.sourceEndMs
            rightClip.timelineStartMs = timelineMs

            clips.append(leftClip)
            clips.append(rightClip)
        }

        return recalculateTimelinePositions(clips: clips)
    }

    func deleteClip(
        timeline: EditTimeline,
        clipID: UUID
    ) throws -> EditTimeline {
        guard timeline.clips.contains(where: { $0.id == clipID }) else {
            throw EditTimelineError.clipNotFound
        }

        let clips = timeline.clips.filter { $0.id != clipID }
        guard !clips.isEmpty else {
            throw EditTimelineError.cannotDeleteEntireTimeline
        }

        return recalculateTimelinePositions(clips: clips)
    }

    func sourceTime(
        forTimelineTime timelineMs: Int,
        in timeline: EditTimeline
    ) -> Int? {
        guard let clip = clip(atTimelineTime: timelineMs, in: timeline) else {
            return nil
        }

        return clip.sourceStartMs + max(0, timelineMs - clip.timelineStartMs)
    }

    func clip(atTimelineTime timelineMs: Int, in timeline: EditTimeline) -> TimelineClip? {
        if let exactClip = timeline.clips.first(where: { timelineMs >= $0.timelineStartMs && timelineMs < $0.timelineEndMs }) {
            return exactClip
        }

        if timelineMs == timeline.totalDurationMs {
            return timeline.clips.last
        }

        return nil
    }

    func playbackAdvance(
        sourceTimeMs: Int,
        currentClipID: UUID?,
        lastKnownTimelineMs: Int,
        in timeline: EditTimeline,
        lookaheadMs: Int = 30
    ) -> EditTimelinePlaybackAdvance {
        guard !timeline.clips.isEmpty else {
            return .paused
        }

        let currentClip = currentClipID
            .flatMap { id in timeline.clips.first(where: { $0.id == id }) }
            ?? clip(atTimelineTime: lastKnownTimelineMs, in: timeline)

        guard let currentClip else {
            return .paused
        }

        guard sourceTimeMs >= currentClip.sourceEndMs - lookaheadMs else {
            let timelineMs = currentClip.timelineStartMs + max(0, sourceTimeMs - currentClip.sourceStartMs)
            return .seekWithinClip(timelineMs: min(timelineMs, timeline.totalDurationMs))
        }

        guard let currentIndex = timeline.clips.firstIndex(where: { $0.id == currentClip.id }),
              currentIndex + 1 < timeline.clips.count else {
            return .finished(totalDurationMs: timeline.totalDurationMs)
        }

        return .advanceToNextClip(timeline.clips[currentIndex + 1])
    }

    func recalculateTimelinePositions(
        clips: [TimelineClip]
    ) -> EditTimeline {
        var cursor = 0
        let normalizedClips = clips
            .filter { $0.sourceDurationMs >= minimumClipDurationMs }
            .map { clip -> TimelineClip in
                var updatedClip = clip
                let duration = updatedClip.sourceDurationMs
                updatedClip.timelineStartMs = cursor
                updatedClip.timelineEndMs = cursor + duration
                cursor += duration
                return updatedClip
            }

        return EditTimeline(clips: normalizedClips, totalDurationMs: cursor)
    }
}
