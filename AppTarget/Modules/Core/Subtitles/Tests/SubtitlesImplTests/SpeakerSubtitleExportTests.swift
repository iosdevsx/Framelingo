import Foundation
import SpeakerAnalysis
import Subtitles
import SubtitlesImpl
import XCTest

final class SpeakerSubtitleExportTests: XCTestCase {
    func testSRTWithSpeakerLabels() async throws {
        let url = temporaryURL(extension: "srt")
        var request = baseRequest
        request.options = SubtitleExportOptions(
            includeSpeakerLabels: true,
            speakerFormat: .squareBrackets
        )
        try await exporter.export(
            request: request,
            kind: .translatedSRT,
            destinationURL: url
        )
        XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains("[Narrator] Привет"))
    }

    func testSRTWithoutSpeakerLabelsByDefault() async throws {
        let url = temporaryURL(extension: "srt")
        try await exporter.export(
            request: baseRequest,
            kind: .translatedSRT,
            destinationURL: url
        )
        let output = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(output.contains("Привет"))
        XCTAssertFalse(output.contains("[Narrator]"))
    }

    func testWebVTTWithVoiceTags() async throws {
        let url = temporaryURL(extension: "vtt")
        var request = baseRequest
        request.options = SubtitleExportOptions(
            includeSpeakerLabels: true,
            speakerFormat: .webVTTVoiceTags
        )
        try await exporter.export(
            request: request,
            kind: .translatedVTT,
            destinationURL: url
        )
        XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains("<v Narrator>Привет</v>"))
    }

    func testNilSpeakerIDSkipsLabel() async throws {
        let url = temporaryURL(extension: "srt")
        var request = baseRequest
        request.segments[0].speakerId = nil
        request.options = SubtitleExportOptions(
            includeSpeakerLabels: true,
            speakerFormat: .squareBrackets
        )
        try await exporter.export(
            request: request,
            kind: .translatedSRT,
            destinationURL: url
        )
        let output = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(output.contains("Привет"))
        XCTAssertFalse(output.contains("[Narrator]"))
    }

    func testUnrelatedVideoAppearanceCannotChangeTextExports() async throws {
        let firstURL = temporaryURL(extension: "srt")
        let secondURL = temporaryURL(extension: "srt")
        try await exporter.export(
            request: baseRequest,
            kind: .translatedSRT,
            destinationURL: firstURL
        )
        // Rendering appearance is intentionally absent from the Subtitles API.
        try await exporter.export(
            request: baseRequest,
            kind: .translatedSRT,
            destinationURL: secondURL
        )
        XCTAssertEqual(try Data(contentsOf: firstURL), try Data(contentsOf: secondURL))
    }

    private var exporter: any SubtitleExportService {
        SubtitlesAssembly.makeExporter()
    }

    private var baseRequest: SubtitleExportRequest {
        SubtitleExportRequest(
            segments: [
                SubtitleSegment(
                    id: UUID(),
                    index: 1,
                    startMs: 0,
                    endMs: 1_000,
                    originalText: "Hello",
                    translatedText: "Привет",
                    speakerId: 0
                ),
            ],
            speakerLabels: [
                SpeakerLabel(id: 0, displayName: "Narrator"),
            ]
        )
    }

    private func temporaryURL(extension fileExtension: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        addTeardownBlock {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
        return url
    }
}
