import XCTest
@testable import Framelingo

final class SubtitleTimecodeUtilsTests: XCTestCase {
    func testFormatSRTTimestamp() {
        XCTAssertEqual(formatSRTTimestamp(83_456), "00:01:23,456")
        XCTAssertEqual(formatSRTTimestamp(0), "00:00:00,000")
        XCTAssertEqual(formatSRTTimestamp(3_661_005), "01:01:01,005")
    }

    func testParseSRTTimestamp() throws {
        XCTAssertEqual(try parseSRTTimestamp("00:01:23,456"), 83_456)
        XCTAssertEqual(try parseSRTTimestamp("01:01:01,005"), 3_661_005)
        XCTAssertThrowsError(try parseSRTTimestamp("00:61:00,000"))
    }

    func testExportSRT() {
        let srt = subtitlesToSRT(sampleSegments, mode: .translatedFallbackToOriginal)

        XCTAssertEqual(
            srt,
            """
            1
            00:00:01,000 --> 00:00:03,000
            Привет

            2
            00:00:04,000 --> 00:00:06,500
            Second line
            continues
            """
        )
    }

    func testParseSRT() throws {
        let input = """
        1
        00:00:01,000 --> 00:00:03,000
        Hello

        2
        00:00:04,000 --> 00:00:06,500
        Second line
        continues
        """

        let segments = try parseSRT(input)

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].index, 1)
        XCTAssertEqual(segments[0].startMs, 1_000)
        XCTAssertEqual(segments[0].endMs, 3_000)
        XCTAssertEqual(segments[0].originalText, "Hello")
        XCTAssertEqual(segments[1].originalText, "Second line\ncontinues")
    }

    func testRoundtripParseExport() throws {
        let input = """
        1
        00:00:01,000 --> 00:00:03,000
        Hello

        2
        00:00:04,000 --> 00:00:06,500
        Second line
        continues
        """

        let parsedSegments = try parseSRT(input)
        let exportedSRT = subtitlesToSRT(parsedSegments, mode: .original)

        XCTAssertEqual(exportedSRT, input)
    }

    private var sampleSegments: [SubtitleSegment] {
        [
            SubtitleSegment(
                id: UUID(),
                index: 10,
                startMs: 1_000,
                endMs: 3_000,
                originalText: "Hello",
                translatedText: "Привет",
                speaker: nil,
                confidence: nil
            ),
            SubtitleSegment(
                id: UUID(),
                index: 11,
                startMs: 4_000,
                endMs: 6_500,
                originalText: "Second line\ncontinues",
                translatedText: "",
                speaker: nil,
                confidence: nil
            )
        ]
    }
}
