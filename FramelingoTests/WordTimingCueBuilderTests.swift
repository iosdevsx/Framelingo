import Foundation
import Testing
@testable import Framelingo

struct WordTimingCueBuilderTests {
    @Test
    func testPauseSplitsCue() {
        let cues = WordTimingCueBuilder(options: SubtitleAlignmentOptions(minCueDuration: 0.1))
            .build(from: [
                word("Before", start: 0.0, end: 0.3),
                word("after", start: 1.2, end: 1.5)
            ])

        #expect(cues.count == 2)
        #expect(cues[0].originalText == "Before")
        #expect(cues[0].endMs == 300)
        #expect(cues[1].originalText == "after")
        #expect(cues[1].startMs == 1_200)
    }

    @Test
    func testLengthSplitHappensAtWordBoundary() {
        let cues = WordTimingCueBuilder(options: SubtitleAlignmentOptions(maxCharsPerCue: 10))
            .build(from: [
                word("One", start: 0.0, end: 0.2),
                word("two", start: 0.3, end: 0.5),
                word("three", start: 0.6, end: 0.9),
                word("four", start: 1.0, end: 1.3)
            ])

        #expect(cues.count == 2)
        #expect(cues.map(\.originalText) == ["One two", "three four"])
        #expect(cues.allSatisfy { $0.originalText.count <= 10 })
    }

    @Test
    func testPunctuationPreferredBoundary() {
        let cues = WordTimingCueBuilder(options: SubtitleAlignmentOptions(minCueDuration: 0.8))
            .build(from: [
                word("Done.", start: 0.0, end: 0.9),
                word("Next", start: 1.0, end: 1.4),
                word("starts", start: 1.5, end: 1.8)
            ])

        #expect(cues.count == 2)
        #expect(cues[0].originalText == "Done.")
        #expect(cues[1].originalText == "Next starts")
    }

    @Test
    func testShortTrailingFragmentMergesIntoPreviousCue() {
        let cues = WordTimingCueBuilder(options: SubtitleAlignmentOptions(minCueDuration: 0.8))
            .build(from: [
                word("This", start: 0.0, end: 0.2),
                word("is", start: 0.3, end: 0.4),
                word("a", start: 0.5, end: 0.6),
                word("normal", start: 0.7, end: 1.0),
                word("sentence.", start: 1.1, end: 1.6),
                word("Yes.", start: 1.7, end: 2.0)
            ])

        #expect(cues.count == 1)
        #expect(cues[0].originalText == "This is a normal sentence. Yes.")
        #expect(cues[0].startMs == 0)
        #expect(cues[0].endMs == 2_000)
    }

    @Test
    func testSingleWordInputProducesSingleCue() {
        let cues = WordTimingCueBuilder()
            .build(from: [
                word("Hello", start: 1.0, end: 1.4, confidence: 0.91)
            ])

        #expect(cues.count == 1)
        #expect(cues[0].index == 1)
        #expect(cues[0].originalText == "Hello")
        #expect(cues[0].confidence == 0.91)
    }

    @Test
    func testCueTimesEqualFirstAndLastWordTimes() {
        let cues = WordTimingCueBuilder()
            .build(from: [
                word("First", start: 1.23, end: 1.5),
                word("last", start: 2.0, end: 2.34)
            ])

        #expect(cues.count == 1)
        #expect(cues[0].startMs == 1_230)
        #expect(cues[0].endMs == 2_340)
    }

    @Test
    func testCueConfidenceUsesMeanWordConfidence() {
        let cues = WordTimingCueBuilder()
            .build(from: [
                word("One", start: 0.0, end: 0.2, confidence: 0.9),
                word("two", start: 0.3, end: 0.5, confidence: 0.7)
            ])

        #expect(cues[0].confidence == 0.8)
    }

    private func word(
        _ text: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Double? = nil
    ) -> WordTiming {
        WordTiming(text: text, start: start, end: end, confidence: confidence)
    }
}
