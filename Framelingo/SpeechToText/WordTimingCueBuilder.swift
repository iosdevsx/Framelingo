import Foundation

struct WordTimingCueBuilder {
    var options = SubtitleAlignmentOptions()
    var shortTrailingFragmentMaxCharacters = 12

    func build(from words: [WordTiming]) -> [SubtitleSegment] {
        let sortedWords = words
            .filter { word in
                !word.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && word.end > word.start
            }
            .sorted { lhs, rhs in
                lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
            }

        guard !sortedWords.isEmpty else {
            return []
        }

        var groups: [[WordTiming]] = []
        var currentGroup: [WordTiming] = []

        for word in sortedWords {
            if shouldStartNewCue(with: word, currentGroup: currentGroup) {
                groups.append(currentGroup)
                currentGroup = []
            }

            currentGroup.append(word)
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return mergeShortTrailingFragments(groups)
            .enumerated()
            .map { offset, group in
                makeCue(from: group, index: offset + 1)
            }
    }

    private func shouldStartNewCue(with nextWord: WordTiming, currentGroup: [WordTiming]) -> Bool {
        guard let firstWord = currentGroup.first,
              let lastWord = currentGroup.last else {
            return false
        }

        if nextWord.start - lastWord.end > options.pauseSplitThreshold {
            return true
        }

        if isSentenceEnding(lastWord.text),
           lastWord.end - firstWord.start >= options.minCueDuration {
            return true
        }

        if nextWord.end - firstWord.start > options.maxCueDuration {
            return true
        }

        return cueText(for: currentGroup + [nextWord]).count > options.maxCharsPerCue
    }

    private func mergeShortTrailingFragments(_ groups: [[WordTiming]]) -> [[WordTiming]] {
        var result: [[WordTiming]] = []

        for group in groups {
            guard let previous = result.last,
                  shouldMergeIntoPrevious(group),
                  cueText(for: previous + group).count <= options.maxCharsPerCue + shortTrailingFragmentMaxCharacters else {
                result.append(group)
                continue
            }

            result[result.count - 1] = previous + group
        }

        return result
    }

    private func shouldMergeIntoPrevious(_ group: [WordTiming]) -> Bool {
        let text = cueText(for: group).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count <= shortTrailingFragmentMaxCharacters && isSentenceEnding(text)
    }

    private func makeCue(from words: [WordTiming], index: Int) -> SubtitleSegment {
        guard let firstWord = words.first, let lastWord = words.last else {
            return SubtitleSegment(
                id: UUID(),
                index: index,
                startMs: 0,
                endMs: 0,
                originalText: "",
                translatedText: ""
            )
        }

        return SubtitleSegment(
            id: UUID(),
            index: index,
            startMs: max(0, milliseconds(fromSeconds: firstWord.start)),
            endMs: max(0, milliseconds(fromSeconds: lastWord.end)),
            originalText: cueText(for: words),
            translatedText: "",
            speaker: nil,
            confidence: meanConfidence(for: words)
        )
    }

    private func cueText(for words: [WordTiming]) -> String {
        words.reduce("") { result, word in
            let text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.isEmpty else {
                return text
            }

            if text.first.map({ ",.!?:;".contains($0) }) == true {
                return result + text
            }

            return result + " " + text
        }
    }

    private func meanConfidence(for words: [WordTiming]) -> Double? {
        let confidences = words.compactMap(\.confidence)
        guard !confidences.isEmpty else {
            return nil
        }

        return confidences.reduce(0, +) / Double(confidences.count)
    }

    private func isSentenceEnding(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).last.map { ".!?".contains($0) } == true
    }

    private func milliseconds(fromSeconds seconds: TimeInterval) -> Int {
        Int((seconds * 1_000).rounded())
    }
}
