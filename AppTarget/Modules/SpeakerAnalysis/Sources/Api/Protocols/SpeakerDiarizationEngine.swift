import Foundation

public protocol SpeakerDiarizationEngine {
    func diarize(audioURL: URL) async throws -> [SpeakerSegment]
}
