import FluidAudio
import Foundation
import Testing
@testable import Framelingo

struct WordTimingMergerTests {
    private let merger = WordTimingMerger()

    @Test
    func testMultiTokenWordUsesFirstStartLastEndAndMeanConfidence() {
        let words = merger.merge([
            token(" tran", start: 1.0, end: 1.1, confidence: 0.9),
            token("scri", start: 1.1, end: 1.2, confidence: 0.6),
            token("ption", start: 1.2, end: 1.4, confidence: 0.75)
        ])

        #expect(words.count == 1)
        #expect(words.first?.text == "transcription")
        #expect(words.first?.start == 1.0)
        #expect(words.first?.end == 1.4)
        #expect(words.first?.confidence == 0.75)
    }

    @Test
    func testPunctuationTokenAttachesToPreviousWord() {
        let words = merger.merge([
            token(" Hello", start: 0.0, end: 0.2),
            token(",", start: 0.2, end: 0.25),
            token(" world", start: 0.3, end: 0.6),
            token("!", start: 0.6, end: 0.65)
        ])

        #expect(words.map(\.text) == ["Hello,", "world!"])
    }

    @Test
    func testFirstTokenWithoutLeadingSpaceStartsWord() {
        let words = merger.merge([
            token("Hello", start: 0.0, end: 0.2),
            token(" world", start: 0.3, end: 0.6)
        ])

        #expect(words.map(\.text) == ["Hello", "world"])
    }

    @Test
    func testEmptyInputReturnsEmptyWords() {
        #expect(merger.merge([]).isEmpty)
    }

    @Test
    func testDegenerateTimingIsDropped() {
        let words = merger.merge([
            token(" bad", start: 1.0, end: 1.0),
            token(" good", start: 1.1, end: 1.5)
        ])

        #expect(words.map(\.text) == ["good"])
    }

    @Test
    func testEmptyTextCandidateIsDropped() {
        let words = merger.merge([
            token(" ", start: 0.0, end: 0.1),
            token(" next", start: 0.2, end: 0.4)
        ])

        #expect(words.map(\.text) == ["next"])
    }

    private func token(
        _ text: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Float = 0.8
    ) -> TokenTiming {
        TokenTiming(
            token: text,
            tokenId: 1,
            startTime: start,
            endTime: end,
            confidence: confidence
        )
    }
}
