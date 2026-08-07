import Foundation
import SpeakerAnalysis
import Subtitles
import Testing

struct SubtitleStructuralEditingPolicyTests {
    private let policy = SubtitleStructuralEditingPolicy()

    @Test
    func splitPreservesMetadataAndCurrentWhitespaceBehavior() throws {
        let originalID = UUID()
        let secondID = UUID()
        let segment = makeSegment(
            id: originalID,
            index: 9,
            startMs: 1_000,
            endMs: 5_000,
            originalText: "one  two three",
            translatedText: " один два ",
            speaker: "Host",
            speakerId: 7,
            confidence: 0.73,
            warnings: [.lowConfidenceSpeaker, .tooLong]
        )

        let result = try policy.split(segments: [segment], id: originalID, newSegmentID: secondID)

        #expect(result.selectedSegmentID == secondID)
        #expect(result.segments.map(\.index) == [1, 2])
        #expect(result.segments.map(\.originalText) == ["one ", "two three"])
        #expect(result.segments.map(\.translatedText) == [" один", "два "])
        #expect(result.segments.map(\.startMs) == [1_000, 3_000])
        #expect(result.segments.map(\.endMs) == [3_000, 5_000])
        #expect(result.segments[1].speaker == "Host")
        #expect(result.segments[1].speakerId == 7)
        #expect(result.segments[1].confidence == 0.73)
        #expect(result.segments[1].warnings == [.lowConfidenceSpeaker, .tooLong])
    }

    @Test
    func splitRejectsOneMillisecondSegmentWithTypedError() {
        let segment = makeSegment(startMs: 10, endMs: 11)

        #expect(throws: SubtitleStructuralEditError.segmentTooShort) {
            try policy.split(segments: [segment], id: segment.id)
        }
    }

    @Test
    func mergeTrimsBoundaryWhitespaceAndUsesLowerAvailableConfidence() throws {
        let first = makeSegment(
            startMs: 0,
            endMs: 1_000,
            originalText: " first \n",
            translatedText: "",
            speaker: "First",
            speakerId: 1,
            confidence: 0.9,
            warnings: [.tooShort]
        )
        let second = makeSegment(
            startMs: 1_050,
            endMs: 2_000,
            originalText: "  second  ",
            translatedText: " translated ",
            speaker: "Second",
            speakerId: 2,
            confidence: 0.4,
            warnings: [.tooLong]
        )

        let result = try policy.mergeWithNext(segments: [first, second], id: first.id)
        let merged = result.segments[0]

        #expect(merged.originalText == "first second")
        #expect(merged.translatedText == "translated")
        #expect(merged.speaker == "First")
        #expect(merged.speakerId == 1)
        #expect(merged.confidence == 0.4)
        #expect(merged.warnings == [.tooShort])
        #expect(merged.endMs == 2_000)
    }

    @Test
    func mergeRetainsTheOnlyAvailableConfidence() throws {
        let first = makeSegment(startMs: 0, endMs: 1_000, confidence: nil)
        let second = makeSegment(startMs: 1_050, endMs: 2_000, confidence: 0.6)

        let result = try policy.mergeWithNext(segments: [first, second], id: first.id)

        #expect(result.segments[0].confidence == 0.6)
    }

    @Test
    func addAndDeleteReindexAndChooseTheAdjacentSegment() throws {
        let first = makeSegment(index: 8, startMs: 0, endMs: 1_000)
        let second = makeSegment(index: 9, startMs: 4_000, endMs: 5_000)
        let insertedID = UUID()

        let added = try policy.addAfter(
            segments: [first, second],
            id: first.id,
            newSegmentID: insertedID
        )
        #expect(added.segments.map(\.index) == [1, 2, 3])
        #expect(added.segments[1].id == insertedID)
        #expect(added.segments[1].startMs == 1_000)
        #expect(added.segments[1].endMs == 3_000)

        let deleted = try policy.delete(segments: added.segments, id: insertedID)
        #expect(deleted.segments.map(\.id) == [first.id, second.id])
        #expect(deleted.selectedSegmentID == second.id)
        #expect(deleted.segments.map(\.index) == [1, 2])
    }

    @Test
    func missingSegmentsAndEmptyArraysReturnTypedErrors() {
        let missingID = UUID()

        #expect(throws: SubtitleStructuralEditError.segmentNotFound) {
            try policy.delete(segments: [], id: missingID)
        }
        #expect(throws: SubtitleStructuralEditError.segmentNotFound) {
            try policy.addAfter(segments: [], id: missingID)
        }
        #expect(throws: SubtitleStructuralEditError.segmentNotFound) {
            try policy.mergeWithNext(segments: [], id: missingID)
        }
    }

    @Test
    func mergeLastSegmentReturnsTypedNoNextError() {
        let only = makeSegment()

        #expect(throws: SubtitleStructuralEditError.noNextSegment) {
            try policy.mergeWithNext(segments: [only], id: only.id)
        }
    }

    private func makeSegment(
        id: UUID = UUID(),
        index: Int = 1,
        startMs: Int = 0,
        endMs: Int = 1_000,
        originalText: String = "text",
        translatedText: String = "",
        speaker: String? = nil,
        speakerId: Int? = nil,
        confidence: Double? = nil,
        warnings: [SubtitleCueWarning] = []
    ) -> SubtitleSegment {
        SubtitleSegment(
            id: id, index: index, startMs: startMs, endMs: endMs,
            originalText: originalText, translatedText: translatedText,
            speaker: speaker, speakerId: speakerId, confidence: confidence,
            warnings: warnings
        )
    }
}
