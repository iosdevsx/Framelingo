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
    func testUsesWordBoundariesWhenSplitTokensMatchWordTimings() {
        let service = SubtitleSegmentationService()
        let result = service.segment(
            [
                segment(
                    start: 0,
                    end: 4_000,
                    text: "Alpha bravo charlie delta. Echo foxtrot golf hotel."
                )
            ],
            words: [
                word("Alpha", startMs: 0, endMs: 300),
                word("bravo", startMs: 400, endMs: 700),
                word("charlie", startMs: 800, endMs: 1_100),
                word("delta", startMs: 1_200, endMs: 1_500),
                word("Echo", startMs: 1_700, endMs: 2_000),
                word("foxtrot", startMs: 2_100, endMs: 2_400),
                word("golf", startMs: 2_500, endMs: 2_800),
                word("hotel", startMs: 2_900, endMs: 3_200)
            ]
        )

        #expect(result.count == 2)
        guard result.count == 2 else { return }
        #expect(result[0].startMs == 0)
        #expect(result[0].endMs == 1_500)
        #expect(result[1].startMs == 1_700)
        #expect(result[1].endMs == 3_200)
    }

    @Test
    func testTokenCountMismatchFallsBackPerSegment() {
        var settings = SubtitleSegmentationSettings()
        settings.minCharactersPerSegment = 0
        let service = SubtitleSegmentationService(settings: settings)
        let result = service.segment(
            [
                segment(start: 0, end: 4_000, text: "One two. Three four."),
                segment(start: 5_000, end: 9_000, text: "Five six. Seven eight.")
            ],
            words: [
                word("One", startMs: 0, endMs: 300),
                word("two", startMs: 400, endMs: 700),
                word("Three", startMs: 800, endMs: 1_100),
                word("Five", startMs: 5_000, endMs: 5_300),
                word("six", startMs: 5_400, endMs: 5_700),
                word("Seven", startMs: 6_000, endMs: 6_300),
                word("eight", startMs: 6_400, endMs: 6_700)
            ]
        )

        #expect(result.count == 4)
        guard result.count == 4 else { return }
        #expect(result[0].originalText == "One two.")
        #expect(result[0].endMs != 700)
        #expect(result[1].endMs == 4_000)
        #expect(result[2].startMs == 5_000)
        #expect(result[2].endMs == 5_700)
        #expect(result[3].startMs == 6_000)
        #expect(result[3].endMs == 6_700)
    }

    @Test
    func testPunctuationAttachedChunkTokensValidateAgainstWords() {
        var settings = SubtitleSegmentationSettings()
        settings.minCharactersPerSegment = 0
        let service = SubtitleSegmentationService(settings: settings)
        let result = service.segment(
            [
                segment(start: 0, end: 3_000, text: "Hello, world. Again soon.")
            ],
            words: [
                word("Hello", startMs: 100, endMs: 300),
                word("world", startMs: 400, endMs: 800),
                word("Again", startMs: 1_000, endMs: 1_300),
                word("soon", startMs: 1_400, endMs: 1_700)
            ]
        )

        #expect(result.count == 2)
        guard result.count == 2 else { return }
        #expect(result[0].startMs == 100)
        #expect(result[0].endMs == 800)
        #expect(result[1].startMs == 1_000)
        #expect(result[1].endMs == 1_700)
    }

    @Test
    func testEmptyWordsPreservesCharProportionalFallback() {
        let service = SubtitleSegmentationService()
        let input = segment(start: 0, end: 8_000, text: "One sentence. Two sentence.")

        let defaultResult = service.segment([input])
        let emptyWordsResult = service.segment([input], words: [])

        #expect(emptyWordsResult.map(\.originalText) == defaultResult.map(\.originalText))
        #expect(emptyWordsResult.map(\.startMs) == defaultResult.map(\.startMs))
        #expect(emptyWordsResult.map(\.endMs) == defaultResult.map(\.endMs))
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

    private func word(_ text: String, startMs: Int, endMs: Int) -> WordTiming {
        WordTiming(
            text: text,
            start: Double(startMs) / 1_000,
            end: Double(endMs) / 1_000
        )
    }
}
