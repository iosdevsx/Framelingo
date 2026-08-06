import Foundation
import Project
import ProjectSession
import Shorts
import Subtitles
import Timeline
import VideoRendering

@MainActor
extension DefaultProjectSession {
    public func updateSubtitle(_ segment: SubtitleSegment) -> ProjectSessionEditResult {
        guard let project else { return .unchanged }
        guard segment.startMs >= 0 else {
            return .init(didChange: false, message: "Start time must be zero or greater.")
        }
        guard segment.endMs > segment.startMs else {
            return .init(didChange: false, message: "End time must be greater than start time.")
        }
        guard let output = SubtitleEditingCoordinator().update(
            segment,
            in: project,
            durationMs: durationMs(for: project)
        ) else { return .unchanged }
        return .init(didChange: install(candidate: output.0), selectedID: segment.id, message: output.1)
    }

    public func updateSegmentTiming(id: UUID, startMs: Int, endMs: Int) -> ProjectSessionEditResult {
        guard var candidate = project else { return .unchanged }
        candidate.subtitles = SubtitleTimingValidator.updateSegmentTiming(
            segments: candidate.subtitles,
            id: id,
            startMs: startMs,
            endMs: endMs,
            durationMs: durationMs(for: candidate)
        )
        return .init(didChange: install(candidate: candidate), selectedID: id)
    }

    public func moveSegment(id: UUID, deltaMs: Int) -> ProjectSessionEditResult {
        guard var candidate = project else { return .unchanged }
        candidate.subtitles = SubtitleTimingValidator.moveSegment(
            segments: candidate.subtitles,
            id: id,
            deltaMs: deltaMs,
            durationMs: durationMs(for: candidate)
        )
        return .init(didChange: install(candidate: candidate), selectedID: id)
    }

    public func replaceSubtitlesFromTimeline(_ subtitles: [SubtitleSegment]) -> ProjectSessionEditResult {
        guard var candidate = project else { return .unchanged }
        candidate.subtitles = SubtitleTimingValidator.reindexed(subtitles)
        return .init(didChange: install(candidate: candidate))
    }

    public func updateTranslatedText(segmentID: UUID, text: String) -> ProjectSessionEditResult {
        guard var candidate = project,
              let index = candidate.subtitles.firstIndex(where: { $0.id == segmentID }) else { return .unchanged }
        candidate.subtitles[index].translatedText = text
        return .init(didChange: install(candidate: candidate), selectedID: segmentID)
    }

    public func splitSegment(id: UUID) -> ProjectSessionEditResult { structural(.split, id: id) }
    public func mergeWithNextSegment(id: UUID) -> ProjectSessionEditResult { structural(.merge, id: id) }
    public func deleteSegment(id: UUID) -> ProjectSessionEditResult { structural(.delete, id: id) }
    public func addSegmentAfter(id: UUID) -> ProjectSessionEditResult { structural(.add, id: id) }

    public func updateSpeakerLabel(id: Int, displayName: String) -> ProjectSessionEditResult {
        guard var candidate = project,
              let index = candidate.speakerLabels.firstIndex(where: { $0.id == id }) else { return .unchanged }
        candidate.speakerLabels[index].displayName = displayName
        return .init(didChange: install(candidate: candidate))
    }

    public func updateSourceLanguage(_ language: String) -> ProjectSessionEditResult {
        guard var candidate = project else { return .unchanged }
        candidate.sourceLanguage = language
        return .init(didChange: install(candidate: candidate))
    }

    public func updateTargetLanguage(_ language: String) -> ProjectSessionEditResult {
        guard var candidate = project else { return .unchanged }
        candidate.targetLanguage = language
        return .init(didChange: install(candidate: candidate))
    }

    public func updateSpeakerExportOptions(_ options: SubtitleExportOptions) -> ProjectSessionEditResult {
        guard var candidate = project else { return .unchanged }
        candidate.speakerExportOptions = options
        return .init(didChange: install(candidate: candidate))
    }

    public func updateVideoExportSettings(_ settings: VideoExportSettings, undoable: Bool) -> ProjectSessionEditResult {
        guard var candidate = project else { return .unchanged }
        candidate.videoExportSettings = settings
        return .init(didChange: install(candidate: candidate, metadata: metadata(undoable: undoable)))
    }

    public func selectCue(id: UUID?, extending: Bool, toggling: Bool) {
        guard let project else { return }
        var selection = interactionState.cueSelection
        guard let id else {
            selection = .empty
            _ = updateInteraction(interaction(cueSelection: selection))
            return
        }
        guard project.subtitles.contains(where: { $0.id == id }) else { return }
        if extending,
           let anchor = selection.anchorCueID ?? selection.primaryCueID,
           let anchorIndex = project.subtitles.firstIndex(where: { $0.id == anchor }),
           let targetIndex = project.subtitles.firstIndex(where: { $0.id == id }) {
            let bounds = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
            selection = .init(primaryCueID: id, selectedCueIDs: Set(project.subtitles[bounds].map(\.id)), anchorCueID: anchor)
        } else if toggling {
            var ids = selection.selectedCueIDs
            if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
            let primary = ids.contains(id) ? id : project.subtitles.first(where: { ids.contains($0.id) })?.id
            selection = .init(primaryCueID: primary, selectedCueIDs: ids, anchorCueID: primary)
        } else {
            selection = .init(primaryCueID: id, selectedCueIDs: [id], anchorCueID: id)
        }
        _ = updateInteraction(interaction(cueSelection: selection))
    }

    public func seek(to milliseconds: Int) {
        guard let project else { return }
        let time = max(milliseconds, 0)
        let active = TimelinePerformance.activeSegmentID(at: time, in: project.subtitles)
        let selection = active.map { ProjectSessionCueSelectionState(primaryCueID: $0, selectedCueIDs: [$0], anchorCueID: $0) }
            ?? interactionState.cueSelection
        _ = updateInteraction(interaction(
            cueSelection: selection,
            playback: .init(playheadMs: time, activeCueID: active)
        ))
    }

    public func ensureTimeline() -> ProjectSessionEditResult {
        guard var candidate = project, candidate.editTimeline?.isEmpty != false,
              let coordinator = timelineCoordinator,
              let timeline = coordinator.resolvedTimeline(for: candidate) else {
            return .unchanged
        }
        candidate.editTimeline = timeline
        return .init(didChange: install(candidate: candidate, metadata: metadata(undoable: false)))
    }

    public func setTimelineClipSelection(_ id: UUID?) {
        let timeline = ProjectSessionTimelineInteractionState(
            selectedClipID: id,
            rangeStartMs: interactionState.timeline.rangeStartMs,
            rangeEndMs: interactionState.timeline.rangeEndMs,
            isPlaybackEnabled: interactionState.timeline.isPlaybackEnabled
        )
        _ = updateInteraction(interaction(timeline: timeline))
    }

    public func setEditRangeStartFromPlayhead() { setRange(start: interactionState.playback.playheadMs, end: interactionState.timeline.rangeEndMs) }
    public func setEditRangeEndFromPlayhead() { setRange(start: interactionState.timeline.rangeStartMs, end: interactionState.playback.playheadMs) }
    public func setEditRange(startMs: Int?, endMs: Int?) { setRange(start: startMs, end: endMs) }
    public func clearEditRange() { setRange(start: nil, end: nil) }

    public func rippleDeleteSelectedRange() -> ProjectSessionEditResult {
        guard let project, let coordinator = timelineCoordinator,
              let start = interactionState.timeline.rangeStartMs,
              let end = interactionState.timeline.rangeEndMs else {
            return .init(didChange: false, message: "Set In and Out points first.")
        }
        let range = VideoCutRange(startMs: start, endMs: end).normalized
        do {
            let candidate = try coordinator.rippleDelete(project: project, range: range)
            let next = interaction(
                playback: .init(playheadMs: min(range.startMs, candidate.editTimeline?.totalDurationMs ?? 0)),
                timeline: .empty
            )
            return .init(didChange: install(candidate: candidate, interaction: next))
        } catch let error as LocalizedError {
            return .init(didChange: false, message: error.errorDescription ?? "Ripple delete failed.")
        } catch {
            return .init(didChange: false, message: "Ripple delete failed.")
        }
    }

    public func splitAtPlayhead() -> ProjectSessionEditResult {
        guard var candidate = project, let coordinator = timelineCoordinator,
              let timeline = coordinator.resolvedTimeline(for: candidate) else { return .unchanged }
        do {
            candidate.editTimeline = try coordinator.editor.splitAt(timeline: timeline, timelineMs: interactionState.playback.playheadMs)
            let selected = coordinator.editor.clip(atTimelineTime: interactionState.playback.playheadMs, in: candidate.editTimeline ?? timeline)?.id
            let timelineState = ProjectSessionTimelineInteractionState(selectedClipID: selected)
            return .init(didChange: install(candidate: candidate, interaction: interaction(timeline: timelineState)), selectedID: selected)
        } catch let error as LocalizedError {
            return .init(didChange: false, message: error.errorDescription)
        } catch { return .unchanged }
    }

    public func deleteSelectedClip() -> ProjectSessionEditResult {
        guard let project, let coordinator = timelineCoordinator,
              let selected = interactionState.timeline.selectedClipID,
              let timeline = coordinator.resolvedTimeline(for: project),
              let clip = timeline.clips.first(where: { $0.id == selected }) else {
            return .init(didChange: false, message: "Select a clip first.")
        }
        let range = VideoCutRange(startMs: clip.timelineStartMs, endMs: clip.timelineEndMs)
        do {
            var candidate = try coordinator.rippleDelete(project: project, range: range)
            candidate.editTimeline = try coordinator.editor.deleteClip(timeline: timeline, clipID: selected)
            let next = interaction(playback: .init(playheadMs: min(range.startMs, candidate.editTimeline?.totalDurationMs ?? 0)), timeline: .empty)
            return .init(didChange: install(candidate: candidate, interaction: next))
        } catch let error as LocalizedError {
            return .init(didChange: false, message: error.errorDescription)
        } catch { return .unchanged }
    }

    public func sourceTime(forTimelineTime milliseconds: Int) -> Int? {
        guard let project, let coordinator = timelineCoordinator,
              let timeline = coordinator.resolvedTimeline(for: project) else { return nil }
        return coordinator.editor.sourceTime(forTimelineTime: milliseconds, in: timeline)
    }

    public func clip(atTimelineTime milliseconds: Int) -> TimelineClip? {
        guard let project, let coordinator = timelineCoordinator,
              let timeline = coordinator.resolvedTimeline(for: project) else { return nil }
        return coordinator.editor.clip(atTimelineTime: milliseconds, in: timeline)
    }

    public func playbackAdvance(sourceTimeMs: Int, currentClipID: UUID?) -> EditTimelinePlaybackAdvance? {
        guard let project, let coordinator = timelineCoordinator,
              let timeline = coordinator.resolvedTimeline(for: project) else { return nil }
        return coordinator.editor.playbackAdvance(
            sourceTimeMs: sourceTimeMs,
            currentClipID: currentClipID,
            lastKnownTimelineMs: interactionState.playback.playheadMs,
            in: timeline
        )
    }

    public func seekTimeline(to milliseconds: Int) { seek(to: min(max(milliseconds, 0), timelineDurationMs())) }
    public func setTimelinePlaybackEnabled(_ enabled: Bool) {
        let old = interactionState.timeline
        _ = updateInteraction(interaction(timeline: .init(selectedClipID: old.selectedClipID, rangeStartMs: old.rangeStartMs, rangeEndMs: old.rangeEndMs, isPlaybackEnabled: enabled)))
    }
    public func timelineDurationMs() -> Int { project.map(durationMs(for:)) ?? 0 }
    public func resolvedTimeline() -> EditTimeline? {
        guard let project, let coordinator = timelineCoordinator else { return nil }
        return coordinator.resolvedTimeline(for: project)
    }

    public func selectShort(id: UUID?) {
        let old = interactionState.shorts
        _ = updateInteraction(interaction(shorts: .init(selectedShortID: id, pendingRangeStartMs: old.pendingRangeStartMs, suggestions: old.suggestions, suggestionStatus: old.suggestionStatus)))
    }

    public func addShort(startMs: Int, endMs: Int, title: String?) -> ProjectSessionEditResult {
        guard let project else { return .unchanged }
        do {
            let output = try ShortsEditingCoordinator().add(project: project, title: title ?? "Short \(project.shorts.count + 1)", startMs: startMs, endMs: endMs)
            let old = interactionState.shorts
            let next = ProjectSessionShortsInteractionState(selectedShortID: output.1, pendingRangeStartMs: nil, suggestions: old.suggestions, suggestionStatus: old.suggestionStatus)
            return .init(didChange: install(candidate: output.0, interaction: interaction(shorts: next)), selectedID: output.1)
        } catch { return .unchanged }
    }

    public func addShortAtPlayhead() -> ProjectSessionEditResult {
        guard let project else { return .unchanged }
        let duration = durationMs(for: project)
        let start = min(max(0, interactionState.playback.playheadMs), max(0, duration - 1_000))
        return addShort(startMs: start, endMs: min(start + 30_000, max(start + 1_000, duration)), title: nil)
    }

    public func createShortFromSelectedCues() -> ProjectSessionEditResult {
        guard let project else { return .unchanged }
        let ids = interactionState.cueSelection.selectedCueIDs
        let cues = project.subtitles.filter { ids.contains($0.id) }
        guard let start = cues.map(\.startMs).min(), let end = cues.map(\.endMs).max() else {
            return .init(didChange: false, message: "Select one or more subtitle cues first.")
        }
        return addShort(startMs: start, endMs: end, title: nil)
    }

    public func replaceShort(_ short: ShortDefinition) -> ProjectSessionEditResult {
        guard let project else { return .unchanged }
        do {
            guard let candidate = try ShortsEditingCoordinator().replace(project: project, short: short) else { return .unchanged }
            return .init(didChange: install(candidate: candidate), selectedID: short.id)
        } catch { return .unchanged }
    }

    public func updateShortRange(id: UUID, startMs: Int, endMs: Int) -> ProjectSessionEditResult {
        guard let project else { return .unchanged }
        do {
            guard let candidate = try ShortsEditingCoordinator().range(project: project, id: id, startMs: startMs, endMs: endMs) else { return .unchanged }
            return .init(didChange: install(candidate: candidate), selectedID: id)
        } catch { return .unchanged }
    }

    public func setSelectedShortStartToPlayhead() -> ProjectSessionEditResult {
        guard let short = selectedShort else { return .unchanged }
        let time = interactionState.playback.playheadMs
        guard time <= short.endMs - 1_000 else { return .init(didChange: false, message: "Move the playhead at least one second before the short end.") }
        return updateShortRange(id: short.id, startMs: time, endMs: short.endMs)
    }

    public func setSelectedShortEndToPlayhead() -> ProjectSessionEditResult {
        guard let short = selectedShort else { return .unchanged }
        let time = interactionState.playback.playheadMs
        guard time >= short.startMs + 1_000 else { return .init(didChange: false, message: "Move the playhead at least one second after the short start.") }
        return updateShortRange(id: short.id, startMs: short.startMs, endMs: time)
    }

    public func setShortStartFromPlayhead() -> ProjectSessionEditResult {
        let time = interactionState.playback.playheadMs
        if interactionState.shorts.pendingRangeStartMs != nil {
            setPendingRangeStart(time)
            return .unchanged
        }
        if let short = selectedShort, time >= short.startMs, time <= short.endMs - 1_000 {
            return updateShortRange(id: short.id, startMs: time, endMs: short.endMs)
        }
        setPendingRangeStart(time)
        return .unchanged
    }

    public func setShortEndFromPlayhead() -> ProjectSessionEditResult {
        guard let start = interactionState.shorts.pendingRangeStartMs else { return setSelectedShortEndToPlayhead() }
        let end = interactionState.playback.playheadMs
        guard end >= start + 1_000 else { return .init(didChange: false, message: "Move the playhead at least one second after the new short start.") }
        setPendingRangeStart(nil)
        return addShort(startMs: start, endMs: end, title: nil)
    }

    public func clearPendingShortRange() { setPendingRangeStart(nil) }

    public func deleteShort(id: UUID) -> ProjectSessionEditResult {
        guard let project else { return .unchanged }
        do { return .init(didChange: install(candidate: try ShortsEditingCoordinator().delete(project: project, id: id))) }
        catch { return .unchanged }
    }

    public func addCropPointAtPlayhead(shortID: UUID) -> ProjectSessionEditResult {
        guard let short = project?.shorts.first(where: { $0.id == shortID }) else { return .unchanged }
        let time = interactionState.playback.playheadMs
        guard time >= short.startMs, time <= short.endMs else { return .init(didChange: false, message: "Move the playhead inside the selected short first.") }
        return updateShortCropOffset(id: shortID, timelineTimeMs: time, offsetX: short.cropOffset(atTimelineTimeMs: time))
    }

    public func updateShortCropOffset(id: UUID, timelineTimeMs: Int, offsetX: Double) -> ProjectSessionEditResult {
        guard let project else { return .unchanged }
        do {
            guard let candidate = try ShortsEditingCoordinator().crop(project: project, id: id, timelineTimeMs: timelineTimeMs, offsetX: offsetX) else { return .unchanged }
            return .init(didChange: install(candidate: candidate), selectedID: id)
        } catch { return .unchanged }
    }

    public func deleteShortCropKeyframe(shortID: UUID, keyframeID: UUID) -> ProjectSessionEditResult {
        guard let project else { return .unchanged }
        do {
            guard let candidate = try ShortsEditingCoordinator().deleteCrop(project: project, shortID: shortID, keyframeID: keyframeID) else { return .unchanged }
            return .init(didChange: install(candidate: candidate), selectedID: shortID)
        } catch { return .unchanged }
    }

    public func updateShortsExportSettings(_ settings: ShortsExportSettings) -> ProjectSessionEditResult {
        guard var candidate = project else { return .unchanged }
        candidate.shortsExportSettings = settings
        return .init(didChange: install(candidate: candidate, metadata: metadata(undoable: false)))
    }

    public func updateShortsSubtitleStyle(_ style: VideoExportSettings, undoable: Bool) -> ProjectSessionEditResult {
        guard var candidate = project else { return .unchanged }
        candidate.shortsExportSettings.subtitleStyle = style
        return .init(didChange: install(candidate: candidate, metadata: metadata(undoable: undoable)))
    }

    public func generateShortsSuggestions() {
        guard let project else { return }
        let suggestions = ShortsSuggestionService().suggestions(cues: project.subtitles, platform: project.shortsExportSettings.platform, existingShorts: project.shorts)
        let status: ProjectSessionSuggestionStatus = suggestions.isEmpty ? .empty : .available
        let old = interactionState.shorts
        _ = updateInteraction(interaction(shorts: .init(selectedShortID: old.selectedShortID, pendingRangeStartMs: old.pendingRangeStartMs, suggestions: suggestions, suggestionStatus: status)))
    }

    public func acceptShortSuggestion(id: UUID) -> ProjectSessionEditResult {
        guard let suggestion = interactionState.shorts.suggestions.first(where: { $0.id == id }) else { return .unchanged }
        let result = addShort(startMs: suggestion.startMs, endMs: suggestion.endMs, title: nil)
        dismissShortSuggestion(id: id)
        return result
    }

    public func dismissShortSuggestion(id: UUID) {
        let old = interactionState.shorts
        let suggestions = old.suggestions.filter { $0.id != id }
        let status: ProjectSessionSuggestionStatus = suggestions.isEmpty ? .exhausted : .available
        _ = updateInteraction(interaction(shorts: .init(selectedShortID: old.selectedShortID, pendingRangeStartMs: old.pendingRangeStartMs, suggestions: suggestions, suggestionStatus: status)))
    }

    private func structural(_ operation: SubtitleEditingCoordinator.Operation, id: UUID) -> ProjectSessionEditResult {
        guard let project else { return .unchanged }
        do {
            let output = try SubtitleEditingCoordinator().structural(operation, id: id, in: project)
            let selection = output.1.map { ProjectSessionCueSelectionState(primaryCueID: $0, selectedCueIDs: [$0], anchorCueID: $0) } ?? .empty
            return .init(didChange: install(candidate: output.0, interaction: interaction(cueSelection: selection)), selectedID: output.1)
        } catch SubtitleStructuralEditError.segmentTooShort {
            return .init(didChange: false, message: "Segment is too short to split.")
        } catch { return .unchanged }
    }

    private var timelineCoordinator: TimelineEditingCoordinator? {
        editTimelineService.map(TimelineEditingCoordinator.init(editor:))
    }

    private var selectedShort: ShortDefinition? {
        guard let id = interactionState.shorts.selectedShortID else { return nil }
        return project?.shorts.first(where: { $0.id == id })
    }

    private func durationMs(for project: Project) -> Int {
        if let timeline = project.editTimeline?.totalDurationMs, timeline > 0 { return timeline }
        if let source = project.mediaFile.durationMs, source > 0 { return source }
        return project.subtitles.map(\.endMs).max() ?? 0
    }

    private func metadata(undoable: Bool) -> ProjectSessionTransactionMetadata {
        ProjectSessionTransactionMetadata(
            history: undoable ? .undoable : .none,
            persistence: .autosave,
            eventKind: .changed
        )
    }

    private func setRange(start: Int?, end: Int?) {
        let old = interactionState.timeline
        _ = updateInteraction(interaction(timeline: .init(selectedClipID: old.selectedClipID, rangeStartMs: start, rangeEndMs: end, isPlaybackEnabled: old.isPlaybackEnabled)))
    }

    private func setPendingRangeStart(_ milliseconds: Int?) {
        let old = interactionState.shorts
        _ = updateInteraction(interaction(shorts: .init(selectedShortID: old.selectedShortID, pendingRangeStartMs: milliseconds, suggestions: old.suggestions, suggestionStatus: old.suggestionStatus)))
    }

    private func interaction(
        cueSelection: ProjectSessionCueSelectionState? = nil,
        playback: ProjectSessionPlaybackState? = nil,
        timeline: ProjectSessionTimelineInteractionState? = nil,
        shorts: ProjectSessionShortsInteractionState? = nil
    ) -> ProjectSessionInteractionState {
        ProjectSessionInteractionState(
            cueSelection: cueSelection ?? interactionState.cueSelection,
            playback: playback ?? interactionState.playback,
            timeline: timeline ?? interactionState.timeline,
            shorts: shorts ?? interactionState.shorts
        )
    }
}
