import Foundation
import SpeakerAnalysis

struct MockSpeakerDiarizationEngine: SpeakerDiarizationEngine {
    init() {
    }

    func diarize(audioURL: URL) async throws -> [SpeakerSegment] {
        []
    }
}
