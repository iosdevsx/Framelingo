import Foundation
import SpeakerAnalysis
import SpeechToText
import Subtitles

#if os(macOS)
struct LocalWhisperSpeechToTextProvider: SpeechToTextProvider {
    var executableURL: URL
    var modelURL: URL
    var whisperModelName: String?
    var vadEnabled: Bool = false
    var vadModelURL: URL?
    var segmentationService = SubtitleSegmentationService()
    var subtitleParser: any SubtitleParsing

    /// Maps the project workspace's language display names
    /// to whisper.cpp language codes. Unmapped names fall back to auto-detection.
    static let languageCodes: [String: String] = [
        "english": "en",
        "russian": "ru",
        "spanish": "es",
        "french": "fr",
        "german": "de",
        "italian": "it",
        "portuguese": "pt",
        "chinese": "zh",
        "japanese": "ja",
        "korean": "ko"
    ]

    static func makeArguments(
        modelURL: URL,
        audioURL: URL,
        outputBaseURL: URL,
        sourceLanguage: String?,
        whisperModelName: String?,
        vadEnabled: Bool,
        vadModelURL: URL?,
        fileManager: FileManager = .default
    ) -> [String] {
        // whisper-cli defaults to `-l en` when the flag is omitted, so `-l` is always passed.
        let languageName = sourceLanguage?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let languageCode = languageCodes[languageName] ?? "auto"

        var arguments = [
            "-m", modelURL.path,
            "-f", audioURL.path,
            "-l", languageCode,
            "-osrt",
            "-ojf",
            "-of", outputBaseURL.path,
            "-pp",
            "-nt"
        ]

        // DTW needs a preset matching the loaded model's architecture; an unknown
        // model name (manually configured path) degrades to heuristic timestamps.
        if let whisperModelName,
           let model = WhisperModel(rawValue: whisperModelName) {
            arguments.append(contentsOf: ["--dtw", model.dtwPreset])
        }

        if vadEnabled,
           let vadModelURL,
           fileManager.fileExists(atPath: vadModelURL.path) {
            arguments.append(contentsOf: [
                "--vad",
                "--vad-model", vadModelURL.path,
                "--vad-speech-pad-ms", "100"
            ])
        }

        return arguments
    }

    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        guard let audioURL = input.audioURL else {
            throw WhisperTranscriptionError.audioMissing
        }

        let outputBaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent("Whisper", isDirectory: true)
            .appendingPathComponent("transcript-\(UUID().uuidString)")

        try FileManager.default.createDirectory(
            at: outputBaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let arguments = Self.makeArguments(
            modelURL: modelURL,
            audioURL: audioURL,
            outputBaseURL: outputBaseURL,
            sourceLanguage: input.sourceLanguage,
            whisperModelName: whisperModelName,
            vadEnabled: vadEnabled,
            vadModelURL: vadModelURL
        )

        await input.progressHandler?(0.15, "Running Whisper...")
        try await runWhisper(arguments: arguments, progressHandler: input.progressHandler)
        await input.progressHandler?(0.95, "Processing transcript...")

        let srtURL = outputBaseURL.appendingPathExtension("srt")
        guard FileManager.default.fileExists(atPath: srtURL.path) else {
            throw WhisperTranscriptionError.outputMissing
        }

        let srt = try String(contentsOf: srtURL, encoding: .utf8)
        let segments = try subtitleParser.parseSRT(srt)

        let jsonURL = outputBaseURL.appendingPathExtension("json")
        let words: [WordTiming]
        do {
            words = try parseWordTimings(from: jsonURL)
        } catch {
            // Word timings are optional; missing or malformed JSON keeps the SRT transcript usable.
            words = []
        }
        let segmentedSubtitles = segmentationService.segment(segments, words: words)

        return TranscriptionResult(
            segments: segmentedSubtitles,
            words: words,
            detectedLanguage: nil,
            durationMs: segmentedSubtitles.map(\.endMs).max()
        )
    }

    private func runWhisper(arguments: [String], progressHandler: TranscriptionProgressHandler?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stderrPipe = Pipe()
            let stdoutPipe = Pipe()
            let progressParser = WhisperProgressParser(progressHandler: progressHandler)
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardError = stderrPipe
            process.standardOutput = stdoutPipe

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                Task {
                    await progressParser.append(data)
                }
            }
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                Task {
                    await progressParser.append(data)
                }
            }

            process.terminationHandler = { process in
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                Task {
                    await progressParser.append(stderrData)
                    await progressParser.append(stdoutData)
                }
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: WhisperTranscriptionError.processFailed(stderr))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: WhisperTranscriptionError.launchFailed(error.localizedDescription))
            }
        }
    }
}

private extension LocalWhisperSpeechToTextProvider {
    func parseWordTimings(from jsonURL: URL) throws -> [WordTiming] {
        let data = try Data(contentsOf: jsonURL)
        let output = try JSONDecoder().decode(WhisperJSONOutput.self, from: data)
        let tokens = output.transcription.flatMap { $0.tokens ?? [] }.filter { token in
            !token.text.isEmpty && !token.text.hasPrefix("[")
        }
        return groupedIntoWords(tokens)
    }

    func groupedIntoWords(_ tokens: [WhisperJSONToken]) -> [WordTiming] {
        var result: [WordTiming] = []
        var wordTokens: [WhisperJSONToken] = []

        for token in tokens {
            if token.text.hasPrefix(" ") && !wordTokens.isEmpty {
                if let timing = makeWordTiming(from: wordTokens) {
                    result.append(timing)
                }
                wordTokens = []
            }
            wordTokens.append(token)
        }
        if let timing = makeWordTiming(from: wordTokens) {
            result.append(timing)
        }
        return result
    }

    func makeWordTiming(from tokens: [WhisperJSONToken]) -> WordTiming? {
        guard let first = tokens.first, let last = tokens.last else { return nil }
        let startMs = first.offsets.from
        let endMs = last.offsets.to > 0 ? last.offsets.to : first.offsets.to
        guard endMs > startMs else { return nil }
        let text = tokens.map { $0.text }.joined().trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return WordTiming(
            text: text,
            start: TimeInterval(startMs) / 1000.0,
            end: TimeInterval(endMs) / 1000.0,
            confidence: tokens.compactMap { $0.p }.min()
        )
    }
}
#endif
