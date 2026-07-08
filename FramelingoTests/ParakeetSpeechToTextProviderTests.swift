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
