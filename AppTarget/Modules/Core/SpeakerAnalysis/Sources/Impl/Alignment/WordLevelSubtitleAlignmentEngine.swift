import Foundation
import SpeakerAnalysis

struct WordLevelSubtitleAlignmentEngine: SubtitleAlignmentEngine {
    init() {
    }

    func align(
        words: [WordTiming],
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue] {
        let sortedWords = words.sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
        }
        guard !sortedWords.isEmpty else {
            return []
        }

        var groups: [[WordTiming]] = []
        var currentGroup: [WordTiming] = []
        var currentSpeakerID: Int?
        let smoothedSpeakerIDs = smoothedSpeakerIDs(
            words: sortedWords,
            speakerSegments: speakerSegments,
            options: options
        )

        for (word, wordSpeakerID) in zip(sortedWords, smoothedSpeakerIDs) {
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

    func smoothedSpeakerIDs(
        words: [WordTiming],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) -> [Int?] {
        let rawSpeakerIDs = words.map { word in
            speakerSegment(for: word, in: speakerSegments)?.speakerId
        }
        let minimumRunLength = max(1, options.minWordsPerSpeakerRun)
        guard minimumRunLength > 1, rawSpeakerIDs.count > 1 else {
            return rawSpeakerIDs
        }

        let runs = speakerRuns(in: rawSpeakerIDs)
        var smoothedSpeakerIDs = rawSpeakerIDs
        for (runIndex, run) in runs.enumerated() where run.range.count < minimumRunLength {
            let replacementSpeakerID: Int?
            if runIndex > runs.startIndex {
                replacementSpeakerID = runs[runIndex - 1].speakerID
            } else if runIndex + 1 < runs.endIndex {
                replacementSpeakerID = runs[runIndex + 1].speakerID
            } else {
                replacementSpeakerID = run.speakerID
            }

            for index in run.range {
                smoothedSpeakerIDs[index] = replacementSpeakerID
            }
        }

        return smoothedSpeakerIDs
    }

    func align(
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue] {
        try await CueLevelSubtitleAlignmentEngine().align(
            existingCues: existingCues,
            speakerSegments: speakerSegments,
            options: options
        )
    }

    static func fixOverlaps(_ cues: [SubtitleAlignmentCue]) -> [SubtitleAlignmentCue] {
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
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) -> SubtitleAlignmentCue {
        let start = max(0, (words.first?.start ?? 0) - options.startPadding)
        let end = (words.last?.end ?? start) + options.endPadding
        let speakerSegment = speakerSegment(for: words, in: speakerSegments)
        var warnings = SubtitleAlignmentMath.durationWarnings(start: start, end: end, options: options)

        if speakerSegment == nil {
            warnings.appendUnique(.noSpeakerDetected)
        } else if let confidence = speakerSegment?.confidence, confidence < options.lowConfidenceThreshold {
            warnings.appendUnique(.lowConfidenceSpeaker)
        }

        return SubtitleAlignmentCue(
            id: UUID(),
            index: index,
            startMs: SubtitleAlignmentMath.milliseconds(fromSeconds: start),
            endMs: SubtitleAlignmentMath.milliseconds(fromSeconds: end),
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
                    duration: SubtitleAlignmentMath.overlapDuration(startA: word.start, endA: word.end, startB: segment.start, endB: segment.end)
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
                    duration: SubtitleAlignmentMath.overlapDuration(startA: start, endA: end, startB: segment.start, endB: segment.end)
                )
            }
            .filter { $0.duration > 0 }
            .max(by: { $0.duration < $1.duration })?
            .segment
    }

    private func speakerRuns(in speakerIDs: [Int?]) -> [(range: Range<Int>, speakerID: Int?)] {
        var runs: [(range: Range<Int>, speakerID: Int?)] = []
        var startIndex = speakerIDs.startIndex

        while startIndex < speakerIDs.endIndex {
            let speakerID = speakerIDs[startIndex]
            var endIndex = speakerIDs.index(after: startIndex)
            while endIndex < speakerIDs.endIndex, speakerIDs[endIndex] == speakerID {
                endIndex = speakerIDs.index(after: endIndex)
            }

            runs.append((startIndex..<endIndex, speakerID))
            startIndex = endIndex
        }

        return runs
    }

    private func translatedText(
        for start: TimeInterval,
        end: TimeInterval,
        existingCues: [SubtitleAlignmentCue]
    ) -> String {
        let candidates = existingCues.compactMap { cue -> (text: String, duration: TimeInterval)? in
            let text = cue.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return nil
            }

            let duration = SubtitleAlignmentMath.overlapDuration(
                startA: start,
                endA: end,
                startB: SubtitleAlignmentMath.seconds(fromMilliseconds: cue.startMs),
                endB: SubtitleAlignmentMath.seconds(fromMilliseconds: cue.endMs)
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
