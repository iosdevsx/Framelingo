import Foundation
import Shorts
import Subtitles
import Testing

struct ShortsSuggestionServiceTests {
    private let service = ShortsSuggestionService()

    @Test
    func suggestionsSplitAtSilenceGaps() {
        var cues: [SubtitleSegment] = []
        for block in 0..<3 {
            let blockStart = block * 62_000
            for cueIndex in 0..<6 {
                let start = blockStart + cueIndex * 10_000
                cues.append(makeCue(index: cues.count + 1, startMs: start, endMs: start + 9_900))
            }
        }

        let suggestions = service.suggestions(cues: cues, platform: .youtubeShorts)

        #expect(suggestions.count == 2)
        #expect(suggestions[0].reason == .pause)
        #expect(suggestions[0].startMs == 0)
        #expect(suggestions[0].endMs == 121_900)
        #expect(suggestions[1].reason == .endOfVideo)
        #expect(suggestions[1].startMs == 124_000)
    }

    @Test
    func suggestionsSplitAtSpeakerChanges() {
        let cues = [
            makeCue(index: 1, startMs: 0, endMs: 50_000, speakerId: 1),
            makeCue(index: 2, startMs: 50_100, endMs: 100_000, speakerId: 1),
            makeCue(index: 3, startMs: 100_200, endMs: 150_000, speakerId: 2)
        ]

        let suggestions = service.suggestions(cues: cues, platform: .youtubeShorts)

        #expect(suggestions.count == 2)
        #expect(suggestions[0].reason == .speakerChange)
        #expect(suggestions[0].endMs == 100_000)
        #expect(suggestions[1].startMs == 100_200)
    }

    @Test
    func noCuesYieldNoSuggestions() {
        #expect(service.suggestions(cues: [], platform: .tiktok).isEmpty)
    }

    @Test
    func candidateClosesBeforeExceedingPlatformLimit() {
        let suggestions = service.suggestions(
            cues: [
                makeCue(index: 1, startMs: 0, endMs: 100_000),
                makeCue(index: 2, startMs: 100_050, endMs: 200_000)
            ],
            platform: .youtubeShorts
        )

        #expect(suggestions.count == 2)
        #expect(suggestions[0].reason == .durationLimit)
        #expect(suggestions[0].endMs == 100_000)
        #expect(suggestions[0].durationMs <= ShortsPlatform.youtubeShorts.durationLimitMs)
    }

    @Test
    func suggestionsOverlappingExistingShortsAreFiltered() {
        let suggestions = service.suggestions(
            cues: [
                makeCue(index: 1, startMs: 0, endMs: 100_000),
                makeCue(index: 2, startMs: 105_000, endMs: 170_000)
            ],
            platform: .youtubeShorts,
            existingShorts: [ShortDefinition(title: "Done", startMs: 0, endMs: 60_000)]
        )

        #expect(suggestions.allSatisfy { $0.startMs >= 60_000 })
    }

    private func makeCue(
        index: Int,
        startMs: Int,
        endMs: Int,
        speakerId: Int? = nil
    ) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: index,
            startMs: startMs,
            endMs: endMs,
            originalText: "cue \(index)",
            translatedText: "",
            speakerId: speakerId
        )
    }
}
