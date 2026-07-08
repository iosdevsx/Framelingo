import Foundation

typealias DiarizationProgressHandler = @Sendable (_ progress: Double?, _ status: String) async -> Void

protocol SpeakerDiarizationEngine {
    func diarize(audioURL: URL) async throws -> [SpeakerSegment]
}

struct MockSpeakerDiarizationEngine: SpeakerDiarizationEngine {
    init() {
    }

    func diarize(audioURL: URL) async throws -> [SpeakerSegment] {
        []
    }
}
