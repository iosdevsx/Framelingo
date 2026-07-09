import Foundation
import Testing
@testable import Framelingo

struct ParakeetSpeechToTextProviderTests {
    @Test
    func testUnsupportedLanguageDelegatesToFallback() async throws {
        let expectedResult = TranscriptionResult(
            segments: [
                SubtitleSegment(
                    id: UUID(),
                    index: 1,
                    startMs: 0,
                    endMs: 1_000,
                    originalText: "こんにちは",
                    translatedText: ""
                )
            ],
            words: [],
            detectedLanguage: "Japanese",
            durationMs: 1_000
        )
        let recorder = ProgressRecorder()
        let provider = ParakeetSpeechToTextProvider(
            fallback: StubSpeechToTextProvider(result: expectedResult)
        )

        let result = try await provider.transcribe(input(
            audioURL: URL(fileURLWithPath: "/tmp/audio.wav"),
            sourceLanguage: "Japanese",
            progressHandler: { _, status in
                await recorder.record(status)
            }
        ))

        #expect(result == expectedResult)
        let statuses = await recorder.statuses
        #expect(statuses.contains { $0.contains("using Whisper") })
    }

    @Test
    func testUnsupportedLanguageWithoutFallbackThrows() async throws {
        let provider = ParakeetSpeechToTextProvider(fallback: nil)

        do {
            _ = try await provider.transcribe(input(
                audioURL: URL(fileURLWithPath: "/tmp/audio.wav"),
                sourceLanguage: "ja"
            ))
            Issue.record("Expected unsupported language error.")
        } catch let error as ParakeetTranscriptionError {
            #expect(error == .unsupportedLanguage("ja"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func testNilAudioURLThrowsAudioMissing() async throws {
        let provider = ParakeetSpeechToTextProvider()

        do {
            _ = try await provider.transcribe(input(audioURL: nil, sourceLanguage: "ja"))
            Issue.record("Expected missing audio error.")
        } catch let error as ParakeetTranscriptionError {
            #expect(error == .audioMissing)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func testAudioWindowPlanKeepsShortAudioInSingleWindow() {
        let windows = ParakeetAudioWindow.plan(
            duration: 60,
            windowDuration: 90,
            overlap: 10
        )

        #expect(windows == [
            ParakeetAudioWindow(start: 0, end: 60, commitStart: 0, commitEnd: 60)
        ])
    }

    @Test
    func testAudioWindowPlanSplitsLongAudioWithMidpointCommits() {
        let windows = ParakeetAudioWindow.plan(
            duration: 200,
            windowDuration: 80,
            overlap: 50
        )

        #expect(windows == [
            ParakeetAudioWindow(start: 0, end: 80, commitStart: 0, commitEnd: 55),
            ParakeetAudioWindow(start: 30, end: 110, commitStart: 55, commitEnd: 85),
            ParakeetAudioWindow(start: 60, end: 140, commitStart: 85, commitEnd: 115),
            ParakeetAudioWindow(start: 90, end: 170, commitStart: 115, commitEnd: 145),
            ParakeetAudioWindow(start: 120, end: 200, commitStart: 145, commitEnd: 175),
            ParakeetAudioWindow(start: 150, end: 200, commitStart: 175, commitEnd: 190),
            ParakeetAudioWindow(start: 180, end: 200, commitStart: 190, commitEnd: 200)
        ])
    }

    @Test
    func testAudioWindowCommitRegionUsesWordMidpoint() {
        let window = ParakeetAudioWindow(start: 30, end: 110, commitStart: 55, commitEnd: 85)

        #expect(window.containsCommitted(WordTiming(text: "inside", start: 54.8, end: 55.4)))
        #expect(!window.containsCommitted(WordTiming(text: "before", start: 54.0, end: 54.8)))
        #expect(!window.containsCommitted(WordTiming(text: "after", start: 84.8, end: 85.2)))
    }

    @Test
    func testFactorySelectsKnownProvidersAndFallsBackForUnknownName() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("ParakeetProviderFactoryTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try fileManager.removeItem(at: directory)
            } catch {
            }
        }

        let executableURL = directory.appendingPathComponent("whisper-cli")
        let modelURL = directory.appendingPathComponent("ggml-small.bin")
        try Data("#!/bin/sh\n".utf8).write(to: executableURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
        try Data([0x01]).write(to: modelURL)

        var settings = AppSettings.default
        #expect(try SpeechToTextProviderFactory.makeProvider(settings: settings) is MockSpeechToTextProvider)

        settings.speechToTextProviderName = "Unknown Provider"
        #expect(try SpeechToTextProviderFactory.makeProvider(settings: settings) is MockSpeechToTextProvider)

        settings.speechToTextProviderName = SpeechToTextProviderName.localParakeet
        #expect(try SpeechToTextProviderFactory.makeProvider(settings: settings) is ParakeetSpeechToTextProvider)

        settings.speechToTextProviderName = SpeechToTextProviderName.localWhisper
        settings.whisperExecutablePath = executableURL.path
        settings.whisperModelPath = modelURL.path
        settings.whisperModelName = WhisperModel.small.rawValue
        #expect(try SpeechToTextProviderFactory.makeProvider(settings: settings) is LocalWhisperSpeechToTextProvider)
    }

    private func input(
        audioURL: URL?,
        sourceLanguage: String?,
        progressHandler: TranscriptionProgressHandler? = nil
    ) -> TranscriptionInput {
        TranscriptionInput(
            audioURL: audioURL,
            videoURL: URL(fileURLWithPath: "/tmp/video.mov"),
            sourceLanguage: sourceLanguage,
            progressHandler: progressHandler
        )
    }
}

private struct StubSpeechToTextProvider: SpeechToTextProvider {
    var result: TranscriptionResult

    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        result
    }
}

private actor ProgressRecorder {
    private(set) var statuses: [String] = []

    func record(_ status: String) {
        statuses.append(status)
    }
}
