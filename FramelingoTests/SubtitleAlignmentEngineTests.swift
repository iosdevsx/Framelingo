import Foundation
import Testing
@testable import Framelingo

struct SubtitleAlignmentEngineTests {
    @Test
    func testCueLevelAssignsSingleSpeaker() async throws {
        let cues = [
            cue(index: 1, startMs: 1_000, endMs: 2_000, text: "Hello")
        ]
        let speakers = [
            SpeakerSegment(speakerId: 2, start: 0.5, end: 2.5, confidence: 0.9)
        ]

        let aligned = try await CueLevelSubtitleAlignmentEngine().align(
            existingCues: cues,
            speakerSegments: speakers,
            options: SubtitleAlignmentOptions()
        )

        #expect(aligned[0].speakerId == 2)
        #expect(aligned[0].warnings.isEmpty)
    }

    @Test
    func testCueLevelMarksSpeakerBoundaryOverlap() async throws {
        let cues = [
            cue(index: 1, startMs: 1_000, endMs: 3_000, text: "Hello")
        ]
        let speakers = [
            SpeakerSegment(speakerId: 0, start: 0.5, end: 1.7, confidence: 0.9),
            SpeakerSegment(speakerId: 1, start: 1.7, end: 3.5, confidence: 0.9)
        ]

        let aligned = try await CueLevelSubtitleAlignmentEngine().align(
            existingCues: cues,
            speakerSegments: speakers,
            options: SubtitleAlignmentOptions()
        )

        #expect(aligned[0].speakerId == 1)
        #expect(aligned[0].warnings.contains(.overlappingSpeakers))
    }

    @Test
    func testCueLevelMarksNoSpeakerOverlap() async throws {
        let cues = [
            cue(index: 1, startMs: 4_000, endMs: 5_000, text: "Hello")
        ]
        let speakers = [
            SpeakerSegment(speakerId: 0, start: 0.5, end: 1.5, confidence: 0.9)
        ]

        let aligned = try await CueLevelSubtitleAlignmentEngine().align(
            existingCues: cues,
            speakerSegments: speakers,
            options: SubtitleAlignmentOptions()
        )

        #expect(aligned[0].speakerId == nil)
        #expect(aligned[0].warnings.contains(.noSpeakerDetected))
    }

    @Test
    func testFixOverlapsSplitsAtMidpointWithOffset() {
        let fixed = WordLevelSubtitleAlignmentEngine.fixOverlaps([
            cue(index: 1, startMs: 0, endMs: 2_000, text: "First"),
            cue(index: 2, startMs: 1_000, endMs: 3_000, text: "Second")
        ])

        #expect(fixed[0].endMs == 1_500)
        #expect(fixed[1].startMs == 1_520)
    }

    @Test
    func testWordLevelSplitsAtSpeakerChange() async throws {
        let words = [
            WordTiming(text: "Hello", start: 0.0, end: 0.4),
            WordTiming(text: "there", start: 0.45, end: 0.8),
            WordTiming(text: "Hi", start: 0.9, end: 1.2)
        ]
        let speakers = [
            SpeakerSegment(speakerId: 0, start: 0.0, end: 0.85),
            SpeakerSegment(speakerId: 1, start: 0.85, end: 1.5)
        ]

        let aligned = try await WordLevelSubtitleAlignmentEngine().align(
            words: words,
            existingCues: [],
            speakerSegments: speakers,
            options: SubtitleAlignmentOptions(minCueDuration: 0.1, minWordsPerSpeakerRun: 1)
        )

        #expect(aligned.count == 2)
        #expect(aligned[0].speakerId == 0)
        #expect(aligned[0].originalText == "Hello there")
        #expect(aligned[1].speakerId == 1)
        #expect(aligned[1].originalText == "Hi")
    }

    @Test
    func testWordLevelIgnoresSingleUnassignedWordRun() async throws {
        let words = [
            word("one", start: 0.0, end: 0.3),
            word("two", start: 0.35, end: 0.65),
            word("three", start: 0.7, end: 1.0),
            word("four", start: 1.05, end: 1.35),
            word("five", start: 1.4, end: 1.7)
        ]
        let speakers = [
            SpeakerSegment(speakerId: 0, start: 0.0, end: 0.68),
            SpeakerSegment(speakerId: 0, start: 1.02, end: 1.8)
        ]

        let aligned = try await WordLevelSubtitleAlignmentEngine().align(
            words: words,
            existingCues: [],
            speakerSegments: speakers,
            options: SubtitleAlignmentOptions(minCueDuration: 0.1)
        )

        #expect(aligned.count == 1)
        guard aligned.count == 1 else { return }
        #expect(aligned[0].speakerId == 0)
        #expect(aligned[0].originalText == "one two three four five")
    }

    @Test
    func testWordLevelSplitsAtSpeakerRunMeetingMinimumLength() async throws {
        let words = [
            word("alpha", start: 0.0, end: 0.3),
            word("bravo", start: 0.35, end: 0.65),
            word("charlie", start: 0.7, end: 1.0),
            word("delta", start: 1.05, end: 1.35)
        ]
        let speakers = [
            SpeakerSegment(speakerId: 0, start: 0.0, end: 0.7),
            SpeakerSegment(speakerId: 1, start: 0.7, end: 1.5)
        ]

        let aligned = try await WordLevelSubtitleAlignmentEngine().align(
            words: words,
            existingCues: [],
            speakerSegments: speakers,
            options: SubtitleAlignmentOptions(minCueDuration: 0.1, minWordsPerSpeakerRun: 2)
        )

        #expect(aligned.count == 2)
        guard aligned.count == 2 else { return }
        #expect(aligned[0].speakerId == 0)
        #expect(aligned[0].originalText == "alpha bravo")
        #expect(aligned[1].speakerId == 1)
        #expect(aligned[1].originalText == "charlie delta")
    }

    @Test
    func testLeadingShortSpeakerRunAdoptsFollowingSpeaker() async throws {
        let words = [
            word("wait", start: 0.0, end: 0.3),
            word("start", start: 0.35, end: 0.65),
            word("again", start: 0.7, end: 1.0),
            word("now", start: 1.05, end: 1.35)
        ]
        let speakers = [
            SpeakerSegment(speakerId: 0, start: 0.0, end: 0.32),
            SpeakerSegment(speakerId: 1, start: 0.35, end: 1.5)
        ]

        let aligned = try await WordLevelSubtitleAlignmentEngine().align(
            words: words,
            existingCues: [],
            speakerSegments: speakers,
            options: SubtitleAlignmentOptions(minCueDuration: 0.1, minWordsPerSpeakerRun: 2)
        )

        #expect(aligned.count == 1)
        guard aligned.count == 1 else { return }
        #expect(aligned[0].speakerId == 1)
        #expect(aligned[0].originalText == "wait start again now")
    }

    @Test
    func testSubtitleAlignmentOptionsDecodeOlderJSONWithDefaultSpeakerRunLength() throws {
        let data = Data("""
        {
          "maxCueDuration": 6.0,
          "minCueDuration": 0.8,
          "maxCharsPerCue": 84,
          "maxCharsPerLine": 42,
          "pauseSplitThreshold": 0.7,
          "startPadding": 0.05,
          "endPadding": 0.10,
          "lowConfidenceThreshold": 0.55
        }
        """.utf8)

        let options = try JSONDecoder().decode(SubtitleAlignmentOptions.self, from: data)

        #expect(options.minWordsPerSpeakerRun == 2)
    }

    @Test
    func testWordLevelSplitsLongRunByDurationAndCharacters() async throws {
        let words = [
            WordTiming(text: "One", start: 0.0, end: 0.4),
            WordTiming(text: "two", start: 0.5, end: 0.9),
            WordTiming(text: "three", start: 1.0, end: 1.4),
            WordTiming(text: "four", start: 1.5, end: 1.9)
        ]
        let speakers = [
            SpeakerSegment(speakerId: 0, start: 0.0, end: 3.0)
        ]
        let options = SubtitleAlignmentOptions(
            maxCueDuration: 1.0,
            minCueDuration: 0.1,
            maxCharsPerCue: 9
        )

        let aligned = try await WordLevelSubtitleAlignmentEngine().align(
            words: words,
            existingCues: [],
            speakerSegments: speakers,
            options: options
        )

        #expect(aligned.count >= 2)
        #expect(aligned.allSatisfy { $0.originalText.count <= 14 })
    }

    @Test
    func testWordLevelSplitsAtPause() async throws {
        let words = [
            WordTiming(text: "Before", start: 0.0, end: 0.3),
            WordTiming(text: "after", start: 1.3, end: 1.6)
        ]
        let speakers = [
            SpeakerSegment(speakerId: 0, start: 0.0, end: 2.0)
        ]

        let aligned = try await WordLevelSubtitleAlignmentEngine().align(
            words: words,
            existingCues: [],
            speakerSegments: speakers,
            options: SubtitleAlignmentOptions(minCueDuration: 0.1, pauseSplitThreshold: 0.7)
        )

        #expect(aligned.count == 2)
        #expect(aligned.map(\.originalText) == ["Before", "after"])
    }

    @Test
    func testWordLevelSplitsAtSentencePunctuation() async throws {
        let words = [
            WordTiming(text: "Done.", start: 0.0, end: 0.9),
            WordTiming(text: "Next", start: 1.0, end: 1.4)
        ]
        let speakers = [
            SpeakerSegment(speakerId: 0, start: 0.0, end: 2.0)
        ]

        let aligned = try await WordLevelSubtitleAlignmentEngine().align(
            words: words,
            existingCues: [],
            speakerSegments: speakers,
            options: SubtitleAlignmentOptions(minCueDuration: 0.8)
        )

        #expect(aligned.count == 2)
        #expect(aligned[0].originalText == "Done.")
    }

    @Test
    func testWordLevelCarriesTranslationForClearOverlap() async throws {
        let words = [
            WordTiming(text: "Hello", start: 0.0, end: 0.4)
        ]
        let existing = [
            cue(index: 1, startMs: 0, endMs: 1_000, text: "Hello", translatedText: "Привет")
        ]

        let aligned = try await WordLevelSubtitleAlignmentEngine().align(
            words: words,
            existingCues: existing,
            speakerSegments: [SpeakerSegment(speakerId: 0, start: 0.0, end: 1.0)],
            options: SubtitleAlignmentOptions(minCueDuration: 0.1)
        )

        #expect(aligned[0].translatedText == "Привет")
    }

    @Test
    func testWordLevelClearsTranslationForAmbiguousOverlap() async throws {
        let words = [
            WordTiming(text: "Hello", start: 0.45, end: 0.55)
        ]
        let existing = [
            cue(index: 1, startMs: 0, endMs: 500, text: "A", translatedText: "А"),
            cue(index: 2, startMs: 500, endMs: 1_000, text: "B", translatedText: "Б")
        ]

        let aligned = try await WordLevelSubtitleAlignmentEngine().align(
            words: words,
            existingCues: existing,
            speakerSegments: [SpeakerSegment(speakerId: 0, start: 0.0, end: 1.0)],
            options: SubtitleAlignmentOptions(minCueDuration: 0.1)
        )

        #expect(aligned[0].translatedText.isEmpty)
    }

    private func cue(
        index: Int,
        startMs: Int,
        endMs: Int,
        text: String,
        translatedText: String = ""
    ) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: index,
            startMs: startMs,
            endMs: endMs,
            originalText: text,
            translatedText: translatedText
        )
    }

    private func word(_ text: String, start: TimeInterval, end: TimeInterval) -> WordTiming {
        WordTiming(text: text, start: start, end: end)
    }
}
