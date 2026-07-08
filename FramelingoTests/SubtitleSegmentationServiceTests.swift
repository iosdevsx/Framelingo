import Testing
import Foundation
@testable import Framelingo

struct SubtitleSegmentationServiceTests {
    @Test
    func testSplitsLongSegmentBySentencePunctuation() {
        let service = SubtitleSegmentationService()
        let result = service.segment([
            segment(
                start: 0,
                end: 12_000,
                text: "This is the first sentence. This is the second sentence! This is the third sentence?"
            )
        ])

        #expect(result.count == 3)
        #expect(result[0].originalText == "This is the first sentence.")
        #expect(result[1].originalText == "This is the second sentence!")
        #expect(result[2].originalText == "This is the third sentence?")
        #expect(result[0].startMs == 0)
        #expect(result[2].endMs == 12_000)
    }

    @Test
    func testSplitsVeryLongTextByWords() {
        var settings = SubtitleSegmentationSettings()
        settings.maxCharactersPerSegment = 42
        let service = SubtitleSegmentationService(settings: settings)
        let result = service.segment([
            segment(
                start: 0,
                end: 10_000,
                text: "This segment has no punctuation but it is still much too long to be comfortable in a subtitle editor"
            )
        ])

        #expect(result.count > 1)
        #expect(result.allSatisfy { $0.originalText.count <= 42 })
    }

    @Test
    func testDoesNotSplitByComma() {
        let service = SubtitleSegmentationService()
        let result = service.segment([
            segment(
                start: 0,
                end: 4_000,
                text: "This stays together, even with a comma."
            )
        ])

        #expect(result.count == 1)
        #expect(result[0].originalText == "This stays together, even with a comma.")
    }

    @Test
    func testKeepsShortSegmentUnchanged() {
        let service = SubtitleSegmentationService()
        let original = segment(start: 1_000, end: 2_500, text: "Short line.")
        let result = service.segment([original])

        #expect(result == [original])
    }

    @Test
    func testReindexesAfterSplit() {
        let service = SubtitleSegmentationService()
        let result = service.segment([
            segment(start: 0, end: 8_000, text: "One sentence. Two sentence."),
            segment(start: 9_000, end: 10_000, text: "Three.")
        ])

        #expect(result.map(\.index) == [1, 2, 3])
    }

    @Test
    func testAddsGapsBetweenSplitSegments() {
        var settings = SubtitleSegmentationSettings()
        settings.gapMs = 80
        let service = SubtitleSegmentationService(settings: settings)
        let result = service.segment([
            segment(start: 0, end: 8_000, text: "One sentence. Two sentence.")
        ])

        #expect(result.count == 2)
        #expect(result[1].startMs - result[0].endMs == 80)
    }

    @Test
    func testMergesVeryShortTrailingSentenceIntoPreviousSegment() {
        let service = SubtitleSegmentationService()
        let result = service.segment([
            segment(start: 0, end: 7_000, text: "This is a normal subtitle sentence. Yes.")
        ])

        #expect(result.count == 1)
        #expect(result[0].originalText == "This is a normal subtitle sentence. Yes.")
        #expect(result[0].startMs == 0)
        #expect(result[0].endMs == 7_000)
    }

    @Test
    func testDoesNotMergeVeryShortFirstSentenceForward() {
        let service = SubtitleSegmentationService()
        let result = service.segment([
            segment(start: 0, end: 7_000, text: "Yes. This is a normal subtitle sentence.")
        ])

        #expect(result.count == 2)
        #expect(result[0].originalText == "Yes.")
        #expect(result[1].originalText == "This is a normal subtitle sentence.")
    }

    private func segment(start: Int, end: Int, text: String) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: start,
            endMs: end,
            originalText: text,
            translatedText: "",
            speaker: nil,
            confidence: nil
        )
    }
}
