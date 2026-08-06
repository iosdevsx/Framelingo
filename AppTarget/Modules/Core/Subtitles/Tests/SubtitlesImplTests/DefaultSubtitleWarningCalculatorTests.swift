import Foundation
import Subtitles
@testable import SubtitlesImpl
import XCTest

final class SubtitleWarningServiceTests: XCTestCase {
    func testFastCueProducesReadingSpeedWarning() {
        let cue = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 0,
            endMs: 500,
            originalText: String(repeating: "a", count: 20),
            translatedText: ""
        )
        XCTAssertTrue(SubtitleWarningService.warnings(for: cue).contains(where: {
            $0.kind == .bad && $0.message.contains("too fast")
        }))
    }
}
