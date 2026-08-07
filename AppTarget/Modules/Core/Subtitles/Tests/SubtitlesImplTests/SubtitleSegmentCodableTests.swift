import Foundation
import SpeakerAnalysis
import Subtitles
import XCTest

final class SubtitleSegmentCodableTests: XCTestCase {
    func testSpeakerFieldsCodableRoundtrip() throws {
        let segment = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 1_000,
            endMs: 2_000,
            originalText: "Original",
            translatedText: "Translated",
            speaker: "Legacy Speaker",
            speakerId: 0,
            confidence: 0.95,
            warnings: [.overlappingSpeakers, .lowConfidenceSpeaker]
        )
        let encoded = try JSONEncoder().encode(segment)
        XCTAssertEqual(try JSONDecoder().decode(SubtitleSegment.self, from: encoded), segment)
    }

    func testLegacyJSONDefaultsNewFields() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "index": 1,
          "startMs": 1000,
          "endMs": 2000,
          "originalText": "Original",
          "translatedText": "Translated",
          "speaker": "Speaker 1",
          "confidence": 0.9
        }
        """
        let decoded = try JSONDecoder().decode(
            SubtitleSegment.self,
            from: Data(json.utf8)
        )
        XCTAssertNil(decoded.speakerId)
        XCTAssertTrue(decoded.warnings.isEmpty)
    }
}
