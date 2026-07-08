import Foundation
import Testing
@testable import Framelingo

struct SpeakerSubtitleExportTests {
    @Test
    func testSRTWithSpeakerLabels() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speaker-labels-\(UUID().uuidString).srt")
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        var project = project
        project.speakerExportOptions = SubtitleExportOptions(includeSpeakerLabels: true, speakerFormat: .squareBrackets)

        try await FileSubtitleExportService().export(project: project, kind: .translatedSRT, destinationURL: url)
        let output = try String(contentsOf: url, encoding: .utf8)

        #expect(output.contains("[Narrator] Привет"))
    }

    @Test
    func testSRTWithoutSpeakerLabelsByDefault() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speaker-no-labels-\(UUID().uuidString).srt")
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        try await FileSubtitleExportService().export(project: project, kind: .translatedSRT, destinationURL: url)
        let output = try String(contentsOf: url, encoding: .utf8)

        #expect(output.contains("Привет"))
        #expect(!output.contains("[Narrator]"))
    }

    @Test
    func testWebVTTWithVoiceTags() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speaker-labels-\(UUID().uuidString).vtt")
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        var project = project
        project.speakerExportOptions = SubtitleExportOptions(includeSpeakerLabels: true, speakerFormat: .webVTTVoiceTags)

        try await FileSubtitleExportService().export(project: project, kind: .translatedVTT, destinationURL: url)
        let output = try String(contentsOf: url, encoding: .utf8)

        #expect(output.contains("<v Narrator>Привет</v>"))
    }

    @Test
    func testNilSpeakerIDSkipsLabel() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speaker-nil-\(UUID().uuidString).srt")
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        var project = project
        project.subtitles[0].speakerId = nil
        project.speakerExportOptions = SubtitleExportOptions(includeSpeakerLabels: true, speakerFormat: .squareBrackets)

        try await FileSubtitleExportService().export(project: project, kind: .translatedSRT, destinationURL: url)
        let output = try String(contentsOf: url, encoding: .utf8)

        #expect(output.contains("Привет"))
        #expect(!output.contains("[Narrator]"))
    }

    private var project: Project {
        Project(
            id: UUID(),
            name: "Interview",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000),
            mediaFile: MediaFile(
                id: UUID(),
                originalURL: URL(fileURLWithPath: "/tmp/interview.mov"),
                fileName: "interview.mov",
                fileExtension: "mov",
                sizeBytes: 42_000,
                durationMs: 10_000
            ),
            sourceLanguage: "English",
            targetLanguage: "Russian",
            subtitles: [
                SubtitleSegment(
                    id: UUID(),
                    index: 1,
                    startMs: 0,
                    endMs: 1_000,
                    originalText: "Hello",
                    translatedText: "Привет",
                    speakerId: 0
                )
            ],
            speakerLabels: [SpeakerLabel(id: 0, displayName: "Narrator")],
            status: .ready
        )
    }
}
