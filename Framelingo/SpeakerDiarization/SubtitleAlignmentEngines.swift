import Foundation

struct CueLevelSubtitleAlignmentEngine: SubtitleAlignmentEngine {
    init() {
    }

    func align(
        words: [WordTiming],
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleSegment] {
        try await align(
            existingCues: existingCues,
            speakerSegments: speakerSegments,
            options: options
        )
    }

    func align(
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleSegment] {
        existingCues.enumerated().map { offset, cue in
            alignedCue(cue, index: offset + 1, speakerSegments: speakerSegments, options: options)
        }
    }

    private func alignedCue(
        _ cue: SubtitleSegment,
        index: Int,
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) -> SubtitleSegment {
        let cueStart = seconds(fromMilliseconds: cue.startMs)
        let cueEnd = seconds(fromMilliseconds: cue.endMs)
        let overlaps = speakerSegments.compactMap { segment -> (segment: SpeakerSegment, duration: TimeInterval)? in
            let duration = overlapDuration(startA: cueStart, endA: cueEnd, startB: segment.start, endB: segment.end)
            return duration > 0 ? (segment, duration) : nil
        }

        var alignedCue = cue
        alignedCue.index = index
        alignedCue.warnings = durationWarnings(for: cueStart, end: cueEnd, options: options)

        guard let best = overlaps.max(by: { $0.duration < $1.duration }) else {
            alignedCue.speakerId = nil
            alignedCue.warnings.appendUnique(.noSpeakerDetected)
            return alignedCue
        }

        alignedCue.speakerId = best.segment.speakerId
        if overlaps.count > 1 {
            alignedCue.warnings.appendUnique(.overlappingSpeakers)
        }
        if let confidence = best.segment.confidence, confidence < options.lowConfidenceThreshold {
            alignedCue.warnings.appendUnique(.lowConfidenceSpeaker)
        }

        return alignedCue
    }
}

struct WordLevelSubtitleAlignmentEngine: SubtitleAlignmentEngine {
    init() {
    }

    func align(
        words: [WordTiming],
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleSegment] {
        let sortedWords = words.sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
        }
        guard !sortedWords.isEmpty else {
            return []
        }

        var groups: [[WordTiming]] = []
        var currentGroup: [WordTiming] = []
        var currentSpeakerID: Int?

        for word in sortedWords {
            let wordSpeakerID = speakerSegment(for: word, in: speakerSegments)?.speakerId
            if shouldStartNewGroup(
                nextWord: word,
                nextSpeakerID: wordSpeakerID,
                currentGroup: currentGroup,
                currentSpeakerID: currentSpeakerID,
                options: options
            ) {
                groups.append(currentGroup)
                currentGroup = []
            }

            if currentGroup.isEmpty {
                currentSpeakerID = wordSpeakerID
            }
            currentGroup.append(word)

            if shouldEndGroupAfterWord(currentGroup, options: options) {
                groups.append(currentGroup)
                currentGroup = []
                currentSpeakerID = nil
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        var cues = groups.enumerated().map { offset, group in
            makeCue(
                from: group,
                index: offset + 1,
                existingCues: existingCues,
                speakerSegments: speakerSegments,
                options: options
            )
        }
        cues = Self.fixOverlaps(cues)
        return cues.enumerated().map { offset, cue in
            var indexedCue = cue
            indexedCue.index = offset + 1
            return indexedCue
        }
    }

    func align(
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleSegment] {
        try await CueLevelSubtitleAlignmentEngine().align(
            existingCues: existingCues,
            speakerSegments: speakerSegments,
            options: options
        )
    }

    static func fixOverlaps(_ cues: [SubtitleSegment]) -> [SubtitleSegment] {
        guard cues.count > 1 else {
            return cues
        }

        var fixed = cues.sorted { lhs, rhs in
            lhs.startMs == rhs.startMs ? lhs.endMs < rhs.endMs : lhs.startMs < rhs.startMs
        }

        for index in fixed.indices.dropLast() {
            let nextIndex = fixed.index(after: index)
            guard fixed[index].endMs > fixed[nextIndex].startMs else {
                continue
            }

            let midpoint = (fixed[index].endMs + fixed[nextIndex].startMs) / 2
            fixed[index].endMs = max(fixed[index].startMs, midpoint)
            fixed[nextIndex].startMs = min(fixed[nextIndex].endMs, midpoint + 20)
        }

        return fixed
    }

    private func shouldStartNewGroup(
        nextWord: WordTiming,
        nextSpeakerID: Int?,
        currentGroup: [WordTiming],
        currentSpeakerID: Int?,
        options: SubtitleAlignmentOptions
    ) -> Bool {
        guard let firstWord = currentGroup.first, let lastWord = currentGroup.last else {
            return false
        }

        if nextSpeakerID != currentSpeakerID {
            return true
        }

        if nextWord.start - lastWord.end > options.pauseSplitThreshold {
            return true
        }

        if nextWord.end - firstWord.start > options.maxCueDuration {
            return true
        }

        let currentText = normalizedText(for: currentGroup)
        let nextText = normalizedText(for: currentGroup + [nextWord])
        return currentText.count > 0 && nextText.count > options.maxCharsPerCue
    }

    private func shouldEndGroupAfterWord(
        _ group: [WordTiming],
        options: SubtitleAlignmentOptions
    ) -> Bool {
        guard let firstWord = group.first, let lastWord = group.last else {
            return false
        }

        guard lastWord.text.last.map({ ".?!".contains($0) }) == true else {
            return false
        }

        return lastWord.end - firstWord.start >= options.minCueDuration
    }

    private func makeCue(
        from words: [WordTiming],
        index: Int,
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) -> SubtitleSegment {
        let start = max(0, (words.first?.start ?? 0) - options.startPadding)
        let end = (words.last?.end ?? start) + options.endPadding
        let speakerSegment = speakerSegment(for: words, in: speakerSegments)
        var warnings = durationWarnings(for: start, end: end, options: options)

        if speakerSegment == nil {
            warnings.appendUnique(.noSpeakerDetected)
        } else if let confidence = speakerSegment?.confidence, confidence < options.lowConfidenceThreshold {
            warnings.appendUnique(.lowConfidenceSpeaker)
        }

        return SubtitleSegment(
            id: UUID(),
            index: index,
            startMs: milliseconds(fromSeconds: start),
            endMs: milliseconds(fromSeconds: end),
            originalText: normalizedText(for: words),
            translatedText: translatedText(for: start, end: end, existingCues: existingCues),
            speakerId: speakerSegment?.speakerId,
            confidence: words.compactMap(\.confidence).min(),
            warnings: warnings
        )
    }

    private func speakerSegment(for word: WordTiming, in speakerSegments: [SpeakerSegment]) -> SpeakerSegment? {
        speakerSegments
            .map { segment in
                (
                    segment: segment,
                    duration: overlapDuration(startA: word.start, endA: word.end, startB: segment.start, endB: segment.end)
                )
            }
            .filter { $0.duration > 0 }
            .max(by: { $0.duration < $1.duration })?
            .segment
    }

    private func speakerSegment(for words: [WordTiming], in speakerSegments: [SpeakerSegment]) -> SpeakerSegment? {
        guard let start = words.first?.start, let end = words.last?.end else {
            return nil
        }

        return speakerSegments
            .map { segment in
                (
                    segment: segment,
                    duration: overlapDuration(startA: start, endA: end, startB: segment.start, endB: segment.end)
                )
            }
            .filter { $0.duration > 0 }
            .max(by: { $0.duration < $1.duration })?
            .segment
    }

    private func translatedText(
        for start: TimeInterval,
        end: TimeInterval,
        existingCues: [SubtitleSegment]
    ) -> String {
        let candidates = existingCues.compactMap { cue -> (text: String, duration: TimeInterval)? in
            let text = cue.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return nil
            }

            let duration = overlapDuration(
                startA: start,
                endA: end,
                startB: seconds(fromMilliseconds: cue.startMs),
                endB: seconds(fromMilliseconds: cue.endMs)
            )
            return duration > 0 ? (cue.translatedText, duration) : nil
        }.sorted { $0.duration > $1.duration }

        guard let best = candidates.first else {
            return ""
        }

        if candidates.dropFirst().contains(where: { $0.duration >= best.duration * 0.5 }) {
            return ""
        }

        return best.text
    }

    private func normalizedText(for words: [WordTiming]) -> String {
        words.reduce("") { result, word in
            guard !result.isEmpty else {
                return word.text
            }

            if word.text.first.map({ ",.!?:;".contains($0) }) == true {
                return result + word.text
            }

            return result + " " + word.text
        }
    }
}

private func seconds(fromMilliseconds milliseconds: Int) -> TimeInterval {
    TimeInterval(milliseconds) / 1_000
}

private func milliseconds(fromSeconds seconds: TimeInterval) -> Int {
    Int((seconds * 1_000).rounded())
}

private func overlapDuration(
    startA: TimeInterval,
    endA: TimeInterval,
    startB: TimeInterval,
    endB: TimeInterval
) -> TimeInterval {
    max(0, min(endA, endB) - max(startA, startB))
}

private func durationWarnings(
    for start: TimeInterval,
    end: TimeInterval,
    options: SubtitleAlignmentOptions
) -> [SubtitleCueWarning] {
    let duration = max(0, end - start)
    var warnings: [SubtitleCueWarning] = []
    if duration > options.maxCueDuration {
        warnings.append(.tooLong)
    }
    if duration < options.minCueDuration {
        warnings.append(.tooShort)
    }
    return warnings
}

private extension Array where Element == SubtitleCueWarning {
    mutating func appendUnique(_ warning: SubtitleCueWarning) {
        guard !contains(warning) else {
            return
        }

        append(warning)
    }
}
