import Foundation

struct LocalWhisperSpeechToTextProvider: SpeechToTextProvider {
    var executableURL: URL
    var modelURL: URL
    var whisperModelName: String?
    var vadEnabled: Bool = false
    var vadModelURL: URL?
    var segmentationService = SubtitleSegmentationService()

    /// Maps the app's language display names (`ProjectViewModel.availableLanguages`)
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
        let segments = try parseSRT(srt)

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

private actor WhisperProgressParser {
    private var bufferedOutput = ""
    private var lastProgress: Double = 0.15
    private let progressHandler: TranscriptionProgressHandler?

    init(progressHandler: TranscriptionProgressHandler?) {
        self.progressHandler = progressHandler
    }

    func append(_ data: Data) {
        guard !data.isEmpty,
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        bufferedOutput += text
        let progress = parseProgress(from: bufferedOutput)

        guard let progress,
              progress > lastProgress else {
            return
        }

        lastProgress = progress
        Task {
            await progressHandler?(progress, "Running Whisper... \(Int((progress * 100).rounded()))%")
        }
    }

    private func parseProgress(from text: String) -> Double? {
        let pattern = #"progress\s*=\s*([0-9]{1,3})%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).last,
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text),
              let percent = Double(text[range]) else {
            return nil
        }

        return min(max(0.15 + percent / 100 * 0.80, 0.15), 0.95)
    }
}

enum WhisperTranscriptionError: LocalizedError, Equatable {
    case audioMissing
    case outputMissing
    case executableMissing
    case modelMissing
    case launchFailed(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioMissing:
            return "Extracted audio file is missing."
        case .outputMissing:
            return "Whisper did not create a transcript file."
        case .executableMissing:
            return "Whisper is not installed. Open Settings and install Local Whisper."
        case .modelMissing:
            return "Whisper model is missing. Open Settings and install Local Whisper."
        case .launchFailed(let description):
            return "Could not launch Whisper: \(description)"
        case .processFailed(let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Whisper transcription failed." : "Whisper transcription failed: \(trimmed)"
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

private struct WhisperJSONOutput: Decodable {
    let transcription: [WhisperJSONSegment]
}

private struct WhisperJSONSegment: Decodable {
    let tokens: [WhisperJSONToken]?
}

private struct WhisperJSONToken: Decodable {
    let text: String
    let offsets: WhisperJSONOffsets
    let p: Double?

    enum CodingKeys: String, CodingKey {
        case text, offsets, p
    }
}

private struct WhisperJSONOffsets: Decodable {
    let from: Int
    let to: Int
}

enum SpeechToTextProviderFactory {
    static func makeProvider(settings: AppSettings) throws -> SpeechToTextProvider {
        switch settings.speechToTextProviderName {
        case SpeechToTextProviderName.localWhisper:
            return try makeLocalWhisperProvider(settings: settings)
        case SpeechToTextProviderName.localParakeet:
            return ParakeetSpeechToTextProvider(
                fallback: makeLocalWhisperFallback(settings: settings)
            )
        default:
            return MockSpeechToTextProvider()
        }
    }

    private static func makeLocalWhisperProvider(settings: AppSettings) throws -> LocalWhisperSpeechToTextProvider {
        let executablePath = settings.whisperExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelPath = settings.whisperModelPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !executablePath.isEmpty,
              FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw WhisperTranscriptionError.executableMissing
        }

        guard !modelPath.isEmpty,
              FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperTranscriptionError.modelMissing
        }

        let vadModelPath = settings.whisperVADModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let vadModelURL: URL? = !vadModelPath.isEmpty && FileManager.default.fileExists(atPath: vadModelPath)
            ? URL(fileURLWithPath: vadModelPath)
            : nil

        return LocalWhisperSpeechToTextProvider(
            executableURL: URL(fileURLWithPath: executablePath),
            modelURL: URL(fileURLWithPath: modelPath),
            whisperModelName: settings.whisperModelName,
            vadEnabled: settings.whisperVADEnabled,
            vadModelURL: vadModelURL
        )
    }

    private static func makeLocalWhisperFallback(settings: AppSettings) -> LocalWhisperSpeechToTextProvider? {
        do {
            return try makeLocalWhisperProvider(settings: settings)
        } catch {
            // Optional Parakeet fallback: selecting Parakeet should not fail just
            // because Local Whisper has not been installed yet.
            return nil
        }
    }
}
