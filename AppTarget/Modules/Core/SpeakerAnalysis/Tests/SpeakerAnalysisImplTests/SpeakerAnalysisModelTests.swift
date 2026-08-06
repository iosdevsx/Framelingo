import Foundation
import SpeakerAnalysis
import Testing

struct SpeakerAnalysisModelTests {
    @Test
    func diarizationContractsCodableRoundTrip() throws {
        let word = WordTiming(
            text: "Hello",
            start: 1.2,
            end: 1.8,
            confidence: 0.91
        )
        let segment = SpeakerSegment(
            speakerId: 1,
            start: 1.0,
            end: 2.0,
            confidence: 0.82
        )
        let label = SpeakerLabel(id: 1, displayName: "Driver")
        let options = SubtitleAlignmentOptions()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        #expect(try decoder.decode(WordTiming.self, from: encoder.encode(word)) == word)
        #expect(try decoder.decode(SpeakerSegment.self, from: encoder.encode(segment)) == segment)
        #expect(try decoder.decode(SpeakerLabel.self, from: encoder.encode(label)) == label)
        #expect(try decoder.decode(SubtitleAlignmentOptions.self, from: encoder.encode(options)) == options)
        #expect(
            try decoder.decode(
                SubtitleCueWarning.self,
                from: encoder.encode(SubtitleCueWarning.overlappingSpeakers)
            ) == .overlappingSpeakers
        )
    }

    @Test
    func speakerDefaultsRemainStable() {
        #expect(Speaker.defaults.map(\.id) == [
            "speaker_1",
            "speaker_2",
            "speaker_3",
            "speaker_4",
        ])
    }
}
