import Foundation

struct ShortSuggestion: Identifiable, Equatable {
    let id: UUID
    var startMs: Int
    var endMs: Int
    var reason: ShortSuggestionReason

    var durationMs: Int {
        max(0, endMs - startMs)
    }

    init(id: UUID = UUID(), startMs: Int, endMs: Int, reason: ShortSuggestionReason) {
        self.id = id
        self.startMs = startMs
        self.endMs = endMs
        self.reason = reason
    }
}

enum ShortSuggestionReason: Equatable {
    case pause
    case speakerChange
    case durationLimit
    case endOfVideo

    var displayName: String {
        switch self {
        case .pause:
            return "Pause"
        case .speakerChange:
            return "Speaker change"
        case .durationLimit:
            return "Duration limit"
        case .endOfVideo:
            return "End of video"
        }
    }
}

/// Proposes candidate shorts from data already on the project: silence gaps
/// between consecutive cues and speaker changes form candidate boundaries;
/// blocks between boundaries are grown greedily toward the platform's target
/// duration. Cues are never split — every suggestion spans whole cues.
struct ShortsSuggestionService {
    var silenceGapThresholdMs = 1_500
    /// Close a candidate once it reaches this fraction of the platform limit.
    var targetFractionOfLimit = 0.5
    /// Ignore trailing candidates shorter than this.
    var minimumSuggestionDurationMs = 5_000

    func suggestions(
        cues: [SubtitleSegment],
        platform: ShortsPlatform,
        existingShorts: [ShortDefinition] = []
    ) -> [ShortSuggestion] {
        let sortedCues = cues
            .filter { $0.endMs > $0.startMs }
            .sorted { $0.startMs < $1.startMs }
        guard !sortedCues.isEmpty else {
            return []
        }

        let limitMs = platform.durationLimitMs
        let targetMs = Int(Double(limitMs) * targetFractionOfLimit)

        var suggestions: [ShortSuggestion] = []
        var candidateStartMs = sortedCues[0].startMs
        var candidateEndMs = sortedCues[0].endMs

        func closeCandidate(reason: ShortSuggestionReason) {
            let candidate = ShortSuggestion(
                startMs: candidateStartMs,
                endMs: candidateEndMs,
                reason: reason
            )
            if candidate.durationMs >= minimumSuggestionDurationMs {
                suggestions.append(candidate)
            }
        }

        for (previous, cue) in zip(sortedCues, sortedCues.dropFirst()) {
            let boundaryReason = boundary(between: previous, and: cue)
            let candidateDurationMs = candidateEndMs - candidateStartMs

            if let boundaryReason, candidateDurationMs >= targetMs {
                closeCandidate(reason: boundaryReason)
                candidateStartMs = cue.startMs
            } else if candidateEndMs - candidateStartMs + cue.durationMs > limitMs {
                // Adding the next cue would exceed the platform limit: close at
                // the last whole cue even without a natural boundary.
                closeCandidate(reason: .durationLimit)
                candidateStartMs = cue.startMs
            }

            candidateEndMs = cue.endMs
        }

        closeCandidate(reason: .endOfVideo)

        guard !existingShorts.isEmpty else {
            return suggestions
        }

        return suggestions.filter { suggestion in
            !existingShorts.contains { short in
                suggestion.startMs < short.endMs && suggestion.endMs > short.startMs
            }
        }
    }

    private func boundary(
        between previous: SubtitleSegment,
        and next: SubtitleSegment
    ) -> ShortSuggestionReason? {
        if next.startMs - previous.endMs >= silenceGapThresholdMs {
            return .pause
        }

        if let previousSpeaker = previous.speakerId,
           let nextSpeaker = next.speakerId,
           previousSpeaker != nextSpeaker {
            return .speakerChange
        }

        return nil
    }
}
