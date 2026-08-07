import Foundation

public enum SubtitleStructuralEditError: Error, Equatable {
    case segmentNotFound
    case segmentTooShort
    case noNextSegment
}

public struct SubtitleStructuralEditResult: Equatable {
    public let segments: [SubtitleSegment]
    public let selectedSegmentID: UUID?

    public init(segments: [SubtitleSegment], selectedSegmentID: UUID?) {
        self.segments = segments
        self.selectedSegmentID = selectedSegmentID
    }
}

public struct SubtitleStructuralEditingPolicy {
    public init() {}

    public func split(
        segments: [SubtitleSegment],
        id: UUID,
        newSegmentID: UUID = UUID()
    ) throws -> SubtitleStructuralEditResult {
        guard let index = segments.firstIndex(where: { $0.id == id }) else {
            throw SubtitleStructuralEditError.segmentNotFound
        }

        let segment = segments[index]
        let midpointMs = segment.startMs + max(1, segment.durationMs / 2)
        guard midpointMs > segment.startMs, midpointMs < segment.endMs else {
            throw SubtitleStructuralEditError.segmentTooShort
        }

        let originalParts = splitText(segment.originalText)
        let translatedParts = splitText(segment.translatedText)
        var firstSegment = segment
        firstSegment.endMs = midpointMs
        firstSegment.originalText = originalParts.first
        firstSegment.translatedText = translatedParts.first

        let secondSegment = SubtitleSegment(
            id: newSegmentID,
            index: segment.index + 1,
            startMs: midpointMs,
            endMs: segment.endMs,
            originalText: originalParts.second,
            translatedText: translatedParts.second,
            speaker: segment.speaker,
            speakerId: segment.speakerId,
            confidence: segment.confidence,
            warnings: segment.warnings
        )

        var updated = segments
        updated[index] = firstSegment
        updated.insert(secondSegment, at: index + 1)
        return SubtitleStructuralEditResult(
            segments: SubtitleTimingValidator.reindexed(updated),
            selectedSegmentID: secondSegment.id
        )
    }

    public func mergeWithNext(
        segments: [SubtitleSegment],
        id: UUID
    ) throws -> SubtitleStructuralEditResult {
        guard let index = segments.firstIndex(where: { $0.id == id }) else {
            throw SubtitleStructuralEditError.segmentNotFound
        }
        guard index + 1 < segments.count else {
            throw SubtitleStructuralEditError.noNextSegment
        }

        let segment = segments[index]
        let nextSegment = segments[index + 1]
        var mergedSegment = segment
        mergedSegment.endMs = nextSegment.endMs
        mergedSegment.originalText = joinedText(segment.originalText, nextSegment.originalText)
        mergedSegment.translatedText = joinedText(segment.translatedText, nextSegment.translatedText)
        mergedSegment.confidence = minimumConfidence(segment.confidence, nextSegment.confidence)

        var updated = segments
        updated[index] = mergedSegment
        updated.remove(at: index + 1)
        return SubtitleStructuralEditResult(
            segments: SubtitleTimingValidator.reindexed(updated),
            selectedSegmentID: mergedSegment.id
        )
    }

    public func addAfter(
        segments: [SubtitleSegment],
        id: UUID,
        newSegmentID: UUID = UUID()
    ) throws -> SubtitleStructuralEditResult {
        guard let index = segments.firstIndex(where: { $0.id == id }) else {
            throw SubtitleStructuralEditError.segmentNotFound
        }

        let segment = segments[index]
        let newSegment = SubtitleSegment(
            id: newSegmentID,
            index: segment.index + 1,
            startMs: segment.endMs,
            endMs: segment.endMs + 2_000,
            originalText: "",
            translatedText: ""
        )
        var updated = segments
        updated.insert(newSegment, at: index + 1)
        return SubtitleStructuralEditResult(
            segments: SubtitleTimingValidator.reindexed(updated),
            selectedSegmentID: newSegment.id
        )
    }

    public func delete(
        segments: [SubtitleSegment],
        id: UUID
    ) throws -> SubtitleStructuralEditResult {
        guard let index = segments.firstIndex(where: { $0.id == id }) else {
            throw SubtitleStructuralEditError.segmentNotFound
        }

        var updated = segments
        updated.remove(at: index)
        updated = SubtitleTimingValidator.reindexed(updated)
        let selectedSegmentID = updated.isEmpty ? nil : updated[min(index, updated.count - 1)].id
        return SubtitleStructuralEditResult(
            segments: updated,
            selectedSegmentID: selectedSegmentID
        )
    }

    private func splitText(_ text: String) -> (first: String, second: String) {
        let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard words.count > 1 else {
            return (text, "")
        }
        let midpoint = max(1, words.count / 2)
        return (
            words.prefix(midpoint).joined(separator: " "),
            words.dropFirst(midpoint).joined(separator: " ")
        )
    }

    private func joinedText(_ first: String, _ second: String) -> String {
        [first, second]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func minimumConfidence(_ first: Double?, _ second: Double?) -> Double? {
        switch (first, second) {
        case let (.some(first), .some(second)): min(first, second)
        case let (.some(first), .none): first
        case let (.none, .some(second)): second
        case (.none, .none): nil
        }
    }
}
