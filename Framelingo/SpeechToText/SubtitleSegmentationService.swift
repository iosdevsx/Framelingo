import Foundation

struct SubtitleSegmentationSettings: Equatable {
    var maxCharactersPerSegment = 90
    var minCharactersPerSegment = 12
    var maxDurationMs = 6_000
    var minDurationMs = 700
    var gapMs = 60
}

struct SubtitleSegmentationService {
    var settings = SubtitleSegmentationSettings()

    func segment(_ segments: [SubtitleSegment]) -> [SubtitleSegment] {
        let splitSegments = segments
            .sorted { $0.startMs == $1.startMs ? $0.index < $1.index : $0.startMs < $1.startMs }
            .flatMap(splitIfNeeded)

        return splitSegments.enumerated().map { offset, segment in
            var updatedSegment = segment
            updatedSegment.index = offset + 1
            return updatedSegment
        }
    }

    private func splitIfNeeded(_ segment: SubtitleSegment) -> [SubtitleSegment] {
        let text = segment.originalText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            return [segment]
        }

        let chunks = textChunks(for: text)
        guard chunks.count > 1 else {
            var updatedSegment = segment
            updatedSegment.originalText = text
            return [updatedSegment]
        }

        return mergeShortTrailingSegments(distributeTiming(segment: segment, chunks: chunks))
    }

    private func textChunks(for text: String) -> [String] {
        let sentenceChunks = splitBySentencePunctuation(text)
        return sentenceChunks
            .flatMap { splitLongChunk($0, preferredSeparators: [" "]) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func splitBySentencePunctuation(_ text: String) -> [String] {
        var chunks: [String] = []
        var current = ""

        for character in text {
            current.append(character)

            if ".!?;:".contains(character) {
                appendChunk(&chunks, &current)
            }
        }

        appendChunk(&chunks, &current)
        return chunks
    }

    private func splitLongChunk(_ chunk: String, preferredSeparators: [String]) -> [String] {
        let trimmedChunk = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedChunk.count > settings.maxCharactersPerSegment else {
            return [trimmedChunk]
        }

        var result: [String] = []
        var remaining = trimmedChunk

        while remaining.count > settings.maxCharactersPerSegment {
            let splitIndex = bestSplitIndex(in: remaining, preferredSeparators: preferredSeparators)
            guard splitIndex > remaining.startIndex else {
                break
            }

            let left = String(remaining[..<splitIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !left.isEmpty {
                result.append(left)
            }

            remaining = String(remaining[splitIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !remaining.isEmpty {
            result.append(remaining)
        }

        return result
    }

    private func bestSplitIndex(in text: String, preferredSeparators: [String]) -> String.Index {
        let targetOffset = min(settings.maxCharactersPerSegment, text.count)
        let targetIndex = text.index(text.startIndex, offsetBy: targetOffset)
        let prefix = String(text[..<targetIndex])

        for separator in preferredSeparators {
            if let range = prefix.range(of: separator, options: .backwards),
               prefix.distance(from: prefix.startIndex, to: range.lowerBound) >= 24 {
                return text.index(text.startIndex, offsetBy: prefix.distance(from: prefix.startIndex, to: range.upperBound))
            }
        }

        return targetIndex
    }

    private func appendChunk(_ chunks: inout [String], _ current: inout String) {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            chunks.append(trimmed)
        }
        current = ""
    }

    private func distributeTiming(segment: SubtitleSegment, chunks: [String]) -> [SubtitleSegment] {
        let duration = max(segment.endMs - segment.startMs, settings.minDurationMs * chunks.count)
        let totalTextWeight = max(chunks.reduce(0) { $0 + max($1.count, 1) }, 1)
        let totalGap = settings.gapMs * max(chunks.count - 1, 0)
        let availableDuration = max(duration - totalGap, settings.minDurationMs * chunks.count)

        var cursor = segment.startMs
        var result: [SubtitleSegment] = []

        for (offset, chunk) in chunks.enumerated() {
            let isLast = offset == chunks.count - 1
            let weightedDuration = Int((Double(max(chunk.count, 1)) / Double(totalTextWeight) * Double(availableDuration)).rounded())
            let chunkDuration = max(settings.minDurationMs, min(settings.maxDurationMs, weightedDuration))
            let end = isLast ? segment.endMs : min(cursor + chunkDuration, segment.endMs - settings.gapMs)

            guard end > cursor else {
                continue
            }

            result.append(SubtitleSegment(
                id: UUID(),
                index: segment.index + offset,
                startMs: cursor,
                endMs: end,
                originalText: chunk,
                translatedText: "",
                speaker: segment.speaker,
                confidence: segment.confidence
            ))

            cursor = min(end + settings.gapMs, segment.endMs)
        }

        return result.isEmpty ? [segment] : result
    }

    private func mergeShortTrailingSegments(_ segments: [SubtitleSegment]) -> [SubtitleSegment] {
        var result: [SubtitleSegment] = []

        for segment in segments {
            let text = segment.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.isEmpty, shouldMergeIntoPrevious(text) else {
                result.append(segment)
                continue
            }

            guard let previous = result.last else {
                result.append(segment)
                continue
            }

            let mergedText = joinedSubtitleText(previous.originalText, text)
            let maxReadableLength = settings.maxCharactersPerSegment + settings.minCharactersPerSegment

            guard mergedText.count <= maxReadableLength else {
                result.append(segment)
                continue
            }

            var merged = previous
            merged.endMs = max(previous.endMs, segment.endMs)
            merged.originalText = mergedText
            merged.translatedText = joinedSubtitleText(previous.translatedText, segment.translatedText)
            result[result.count - 1] = merged
        }

        return result
    }

    private func shouldMergeIntoPrevious(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        return trimmed.count <= settings.minCharactersPerSegment
    }

    private func joinedSubtitleText(_ left: String, _ right: String) -> String {
        let left = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = right.trimmingCharacters(in: .whitespacesAndNewlines)

        if left.isEmpty { return right }
        if right.isEmpty { return left }

        return "\(left) \(right)"
    }
}
