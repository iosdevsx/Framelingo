import Foundation
import Testing
@testable import Framelingo

struct SpeakerDiarizationModelTests {
    @Test
    func testNewDiarizationTypesCodableRoundTrip() throws {
        let word = WordTiming(text: "Hello", start: 1.2, end: 1.8, confidence: 0.91)
        let speakerSegment = SpeakerSegment(speakerId: 1, start: 1.0, end: 2.0, confidence: 0.82)
        let speakerLabel = SpeakerLabel(id: 1, displayName: "Driver")
        let options = SubtitleAlignmentOptions()

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        #expect(try decoder.decode(WordTiming.self, from: encoder.encode(word)) == word)
        #expect(try decoder.decode(SpeakerSegment.self, from: encoder.encode(speakerSegment)) == speakerSegment)
        #expect(try decoder.decode(SpeakerLabel.self, from: encoder.encode(speakerLabel)) == speakerLabel)
        #expect(try decoder.decode(SubtitleAlignmentOptions.self, from: encoder.encode(options)) == options)
        #expect(try decoder.decode(SubtitleCueWarning.self, from: encoder.encode(SubtitleCueWarning.overlappingSpeakers)) == .overlappingSpeakers)
    }

    @Test
    func testSubtitleSegmentSpeakerFieldsCodableRoundTrip() throws {
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
        let decoded = try JSONDecoder().decode(SubtitleSegment.self, from: encoded)

        #expect(decoded == segment)
    }

    @Test
    func testOldSubtitleSegmentJSONDefaultsNewFields() throws {
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

        let decoded = try JSONDecoder().decode(SubtitleSegment.self, from: Data(json.utf8))

        #expect(decoded.speakerId == nil)
        #expect(decoded.warnings.isEmpty)
    }

    @Test
    func testProjectSpeakerFieldsCodableRoundTrip() throws {
        let project = Project(
            id: UUID(),
            name: "Interview",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000),
            mediaFile: mediaFile,
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
            speakerLabels: [SpeakerLabel(id: 0, displayName: "Interviewer")],
            speakerSegments: [SpeakerSegment(speakerId: 0, start: 0, end: 1.0)],
            status: .ready
        )

        let encoded = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: encoded)

        #expect(decoded == project)
    }

    @Test
    func testOldProjectJSONDefaultsSpeakerFields() throws {
        let project = Project(
            id: UUID(),
            name: "Legacy Project",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000),
            mediaFile: mediaFile,
            sourceLanguage: "English",
            targetLanguage: "Russian",
            subtitles: [
                SubtitleSegment(
                    id: UUID(),
                    index: 1,
                    startMs: 0,
                    endMs: 1_000,
                    originalText: "Hello",
                    translatedText: ""
                )
            ],
            status: .ready
        )
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any]
        object?["speakerLabels"] = nil
        object?["speakerSegments"] = nil
        object?["wordTimings"] = nil
        object?["videoExportSettings"] = nil
        object?["speakerExportOptions"] = nil
        let legacyData = try JSONSerialization.data(withJSONObject: object as Any)

        let decoded = try JSONDecoder().decode(Project.self, from: legacyData)

        #expect(decoded.speakerLabels.isEmpty)
        #expect(decoded.speakerSegments.isEmpty)
        #expect(decoded.wordTimings.isEmpty)
        #expect(decoded.videoExportSettings == VideoExportSettings())
        #expect(decoded.speakerExportOptions == SubtitleExportOptions())
    }

    private var mediaFile: MediaFile {
        MediaFile(
            id: UUID(),
            originalURL: URL(fileURLWithPath: "/tmp/interview.mov"),
            fileName: "interview.mov",
            fileExtension: "mov",
            sizeBytes: 42_000,
            durationMs: 60_000
        )
    }
}
