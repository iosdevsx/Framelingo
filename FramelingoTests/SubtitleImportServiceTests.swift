import XCTest
@testable import Framelingo

final class SubtitleImportServiceTests: XCTestCase {
    func testSRTParseSimple() throws {
        let segments = try SRTSubtitleParser().parse("""
        1
        00:00:01,000 --> 00:00:03,500
        Hello
        """).segments

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].startMs, 1_000)
        XCTAssertEqual(segments[0].endMs, 3_500)
        XCTAssertEqual(segments[0].originalText, "Hello")
    }

    func testSRTParseMultiline() throws {
        let segments = try SRTSubtitleParser().parse("""
        10
        00:00:01,000 --> 00:00:03,500
        Hello
        world
        """).segments

        XCTAssertEqual(segments[0].originalText, "Hello\nworld")
    }

    func testVTTParseWithHeader() throws {
        let segments = try WebVTTSubtitleParser().parse("""
        WEBVTT

        00:00:01.000 --> 00:00:03.500
        <i>Hello</i>
        """).segments

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].startMs, 1_000)
        XCTAssertEqual(segments[0].endMs, 3_500)
        XCTAssertEqual(segments[0].originalText, "Hello")
    }

    func testVTTIgnoresNOTE() throws {
        let segments = try WebVTTSubtitleParser().parse("""
        WEBVTT

        NOTE this should be ignored
        with more note text

        00:01.000 --> 00:03.500
        Visible
        """).segments

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].originalText, "Visible")
    }

    func testASSParseDialogueWithCommaInText() throws {
        let segments = try ASSSubtitleParser().parse("""
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:03.50,Default,,0,0,0,,Hello, world
        """).segments

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].startMs, 1_000)
        XCTAssertEqual(segments[0].endMs, 3_500)
        XCTAssertEqual(segments[0].originalText, "Hello, world")
    }

    func testASSRemovesOverrideTags() throws {
        let segments = try ASSSubtitleParser().parse("""
        [Events]
        Dialogue: 0,0:00:01.00,0:00:03.50,Default,,0,0,0,,{\\an8}Hello\\N{\\i1}world
        """).segments

        XCTAssertEqual(segments[0].originalText, "Hello\nworld")
    }

    func testTXTGeneratesApproximateTimings() throws {
        let result = try PlainTextSubtitleParser().parse("""
        First

        Second block
        """)

        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.segments[0].startMs, 0)
        XCTAssertEqual(result.segments[0].endMs, 3_000)
        XCTAssertEqual(result.segments[1].startMs, 3_100)
        XCTAssertEqual(result.warnings, ["TXT file has no timings. Approximate timings were generated."])
    }

    func testNormalizationRecalculatesIndices() {
        let segments = [
            makeSegment(index: 20, startMs: 2_000, endMs: 3_000, text: "Second"),
            makeSegment(index: 10, startMs: 0, endMs: 1_000, text: "First")
        ]

        let result = SubtitleImportNormalizer.normalize(segments)

        XCTAssertEqual(result.segments.map(\.index), [1, 2])
        XCTAssertEqual(result.segments.map(\.originalText), ["First", "Second"])
    }

    func testUnsupportedExtensionReturnsError() {
        XCTAssertThrowsError(try SubtitleFileFormat.format(for: URL(fileURLWithPath: "/tmp/subtitles.xml"))) { error in
            XCTAssertEqual(error as? SubtitleImportError, .unsupportedFormat("xml"))
        }
    }
}
