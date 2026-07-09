// FluidAudio ASR calls intentionally target the pinned 0.14.1 API. See the
// archive-build note atop FluidAudioSpeakerDiarizationEngine.swift before
// changing the package pin or these call sites.
import AVFoundation
import FluidAudio
import Foundation

struct ParakeetSpeechToTextProvider: SpeechToTextProvider {
    private static let windowedTranscriptionThreshold: TimeInterval = 80
    private static let windowDuration: TimeInterval = 80
    private static let windowOverlap: TimeInterval = 50
    private static let gapFillThreshold: TimeInterval = 2
    private static let gapFillBoundaryTolerance: TimeInterval = 0.05
    private static let expectedSampleRate: Double = 16_000

    var modelStore: ParakeetModelStore
    var fallback: SpeechToTextProvider?
    var wordTimingMerger: WordTimingMerger
    var cueBuilder: WordTimingCueBuilder

    init(
        modelStore: ParakeetModelStore = ParakeetModelStore(),
        fallback: SpeechToTextProvider? = nil,
        wordTimingMerger: WordTimingMerger = WordTimingMerger(),
        cueBuilder: WordTimingCueBuilder = WordTimingCueBuilder()
    ) {
        self.modelStore = modelStore
        self.fallback = fallback
        self.wordTimingMerger = wordTimingMerger
        self.cueBuilder = cueBuilder
    }

    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        guard let audioURL = input.audioURL else {
            throw ParakeetTranscriptionError.audioMissing
        }

        guard #available(macOS 14.0, *) else {
            throw ParakeetTranscriptionError.requiresMacOS14
        }

        if let fallbackResult = try await fallbackResultIfNeeded(for: input) {
            return fallbackResult
        }

        try Task.checkCancellation()
        let audioInfo = try audioInfo(for: audioURL)

        try Task.checkCancellation()
        let models = try await loadModels(progressHandler: input.progressHandler)

        try Task.checkCancellation()
        let manager = AsrManager(config: .default, models: models)

        let languageHint = ParakeetLanguageSupport.fluidAudioLanguageHint(for: input.sourceLanguage)
        let words = try await transcribeWords(
            audioURL: audioURL,
            audioInfo: audioInfo,
            manager: manager,
            languageHint: languageHint,
            progressHandler: input.progressHandler
        )

        try Task.checkCancellation()
        await input.progressHandler?(0.95, "Processing Parakeet transcript…")
        let segments = cueBuilder.build(from: words)

        return TranscriptionResult(
            segments: segments,
            words: words,
            detectedLanguage: nil,
            durationMs: milliseconds(fromSeconds: audioInfo.duration)
        )
    }

    private func fallbackResultIfNeeded(for input: TranscriptionInput) async throws -> TranscriptionResult? {
        guard let sourceLanguage = input.sourceLanguage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sourceLanguage.isEmpty,
              !ParakeetLanguageSupport.isSupported(sourceLanguage) else {
            return nil
        }

        guard let fallback else {
            throw ParakeetTranscriptionError.unsupportedLanguage(sourceLanguage)
        }

        await input.progressHandler?(0.15, "Language not supported by Parakeet — using Whisper…")
        return try await fallback.transcribe(input)
    }

    private func loadModels(progressHandler: TranscriptionProgressHandler?) async throws -> AsrModels {
        await progressHandler?(
            0.15,
            modelStore.modelsArePresent() ? "Loading Parakeet models…" : "Downloading Parakeet models…"
        )

        do {
            return try await modelStore.downloadAndLoadModels { progress in
                guard let progressHandler else {
                    return
                }

                let mappedProgress = 0.15 + clamped(progress.fractionCompleted) * 0.10
                Task {
                    await progressHandler(
                        mappedProgress,
                        ParakeetModelStore.statusText(for: progress)
                    )
                }
            }
        } catch let error as CancellationError {
            throw error
        } catch {
            throw ParakeetTranscriptionError.modelLoadFailed(error.localizedDescription)
        }
    }

    private func transcribeWords(
        audioURL: URL,
        audioInfo: ParakeetAudioInfo,
        manager: AsrManager,
        languageHint: Language?,
        progressHandler: TranscriptionProgressHandler?
    ) async throws -> [WordTiming] {
        if audioInfo.duration > Self.windowedTranscriptionThreshold {
            return try await transcribeWindowedWords(
                audioURL: audioURL,
                audioInfo: audioInfo,
                manager: manager,
                languageHint: languageHint,
                progressHandler: progressHandler
            )
        }

        let progressTask = transcriptionProgressTask(
            manager: manager,
            progressHandler: progressHandler
        )
        defer {
            progressTask?.cancel()
        }

        do {
            await progressHandler?(0.25, "Running Parakeet…")
            var decoderState = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
            let result = try await manager.transcribe(
                audioURL,
                decoderState: &decoderState,
                language: languageHint
            )
            return wordTimingMerger.merge(result.tokenTimings ?? [])
        } catch let error as CancellationError {
            throw error
        } catch {
            throw ParakeetTranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    private func transcribeWindowedWords(
        audioURL: URL,
        audioInfo: ParakeetAudioInfo,
        manager: AsrManager,
        languageHint: Language?,
        progressHandler: TranscriptionProgressHandler?
    ) async throws -> [WordTiming] {
        let windows = ParakeetAudioWindow.plan(
            duration: audioInfo.duration,
            windowDuration: Self.windowDuration,
            overlap: Self.windowOverlap
        )
        guard !windows.isEmpty else {
            return []
        }

        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            try validatePreparedAudio(audioFile)

            var committedWords: [WordTiming] = []
            var candidateWordGroups: [[WordTiming]] = []
            for (offset, window) in windows.enumerated() {
                try Task.checkCancellation()
                await reportWindowProgress(
                    offset: offset,
                    total: windows.count,
                    progressHandler: progressHandler
                )

                let samples = try readSamples(for: window, from: audioFile)
                guard !samples.isEmpty else {
                    continue
                }

                var decoderState = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
                let result = try await manager.transcribe(
                    samples,
                    decoderState: &decoderState,
                    language: languageHint
                )
                let windowWords = wordTimingMerger
                    .merge(result.tokenTimings ?? [])
                    .compactMap { offsetWord($0, by: window.start, clampedTo: window) }

                candidateWordGroups.append(windowWords)
                committedWords.append(contentsOf: windowWords.filter { window.containsCommitted($0) })
                await reportWindowProgress(
                    offset: offset + 1,
                    total: windows.count,
                    progressHandler: progressHandler
                )
            }

            return Self.fillLargeGaps(
                in: Self.sortedWords(committedWords),
                using: candidateWordGroups
            )
        } catch let error as CancellationError {
            throw error
        } catch let error as ParakeetTranscriptionError {
            throw error
        } catch {
            throw ParakeetTranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    private func transcriptionProgressTask(
        manager: AsrManager,
        progressHandler: TranscriptionProgressHandler?
    ) -> Task<Void, Never>? {
        guard let progressHandler else {
            return nil
        }

        return Task {
            do {
                let stream = await manager.transcriptionProgressStream
                for try await progress in stream {
                    let clampedProgress = clamped(progress)
                    await progressHandler(
                        0.25 + clampedProgress * 0.70,
                        "Transcribing with Parakeet… \(Int((clampedProgress * 100).rounded()))%"
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func audioInfo(for url: URL) throws -> ParakeetAudioInfo {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let sampleRate = audioFile.processingFormat.sampleRate
            guard sampleRate > 0 else {
                throw ParakeetTranscriptionError.transcriptionFailed("Prepared audio has an invalid sample rate.")
            }

            return ParakeetAudioInfo(duration: Double(audioFile.length) / sampleRate)
        } catch let error as ParakeetTranscriptionError {
            throw error
        } catch {
            throw ParakeetTranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    private func validatePreparedAudio(_ audioFile: AVAudioFile) throws {
        let format = audioFile.processingFormat
        guard Int(format.sampleRate.rounded()) == Int(Self.expectedSampleRate),
              format.channelCount == 1 else {
            throw ParakeetTranscriptionError.transcriptionFailed(
                "Prepared audio must be 16 kHz mono WAV for Parakeet windowed transcription."
            )
        }
    }

    private func readSamples(for window: ParakeetAudioWindow, from audioFile: AVAudioFile) throws -> [Float] {
        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = max(
            AVAudioFramePosition(0),
            min(audioFile.length, AVAudioFramePosition((window.start * sampleRate).rounded(.down)))
        )
        let endFrame = max(
            startFrame,
            min(audioFile.length, AVAudioFramePosition((window.end * sampleRate).rounded(.up)))
        )
        let frameCount = endFrame - startFrame
        guard frameCount > 0, frameCount <= AVAudioFramePosition(UInt32.max) else {
            return []
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            throw ParakeetTranscriptionError.transcriptionFailed("Could not allocate an audio buffer.")
        }

        audioFile.framePosition = startFrame
        try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(frameCount))

        guard let channel = buffer.floatChannelData?.pointee else {
            throw ParakeetTranscriptionError.transcriptionFailed("Could not read prepared audio samples.")
        }

        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }

    private func offsetWord(
        _ word: WordTiming,
        by offset: TimeInterval,
        clampedTo window: ParakeetAudioWindow
    ) -> WordTiming? {
        let start = max(window.start, word.start + offset)
        let end = min(window.end, word.end + offset)
        guard end > start else {
            return nil
        }

        return WordTiming(
            id: word.id,
            text: word.text,
            start: start,
            end: end,
            confidence: word.confidence
        )
    }

    private func reportWindowProgress(
        offset: Int,
        total: Int,
        progressHandler: TranscriptionProgressHandler?
    ) async {
        guard let progressHandler, total > 0 else {
            return
        }

        let fraction = clamped(Double(offset) / Double(total))
        await progressHandler(
            0.25 + fraction * 0.70,
            "Transcribing with Parakeet… \(Int((fraction * 100).rounded()))%"
        )
    }

    private func milliseconds(fromSeconds seconds: TimeInterval) -> Int {
        Int((seconds * 1_000).rounded())
    }

    static func fillLargeGaps(
        in primaryWords: [WordTiming],
        using candidateWordGroups: [[WordTiming]]
    ) -> [WordTiming] {
        let primaryWords = sortedWords(primaryWords)
        guard primaryWords.count > 1 else {
            return primaryWords
        }

        var result: [WordTiming] = []

        for index in primaryWords.indices {
            let word = primaryWords[index]
            result.append(word)

            guard index < primaryWords.index(before: primaryWords.endIndex) else {
                continue
            }

            let nextWord = primaryWords[primaryWords.index(after: index)]
            let gapStart = word.end
            let gapEnd = nextWord.start
            guard gapEnd - gapStart >= Self.gapFillThreshold else {
                continue
            }

            result.append(contentsOf: bestGapFill(
                from: candidateWordGroups,
                gapStart: gapStart,
                gapEnd: gapEnd
            ))
        }

        return result
    }

    private static func sortedWords(_ words: [WordTiming]) -> [WordTiming] {
        words.sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
        }
    }

    private static func bestGapFill(
        from candidateWordGroups: [[WordTiming]],
        gapStart: TimeInterval,
        gapEnd: TimeInterval
    ) -> [WordTiming] {
        candidateWordGroups
            .map { group in
                sortedWords(group).filter { candidate in
                    let midpoint = (candidate.start + candidate.end) / 2
                    return midpoint > gapStart + Self.gapFillBoundaryTolerance
                        && midpoint < gapEnd - Self.gapFillBoundaryTolerance
                }
            }
            .max { lhs, rhs in
                gapFillScore(lhs) < gapFillScore(rhs)
            } ?? []
    }

    private static func gapFillScore(_ words: [WordTiming]) -> Double {
        guard let firstWord = words.first,
              let lastWord = words.last else {
            return 0
        }

        return Double(words.count) + max(0, lastWord.end - firstWord.start)
    }
}

private struct ParakeetAudioInfo {
    var duration: TimeInterval
}

struct ParakeetAudioWindow: Equatable {
    var start: TimeInterval
    var end: TimeInterval
    var commitStart: TimeInterval
    var commitEnd: TimeInterval

    static func plan(
        duration: TimeInterval,
        windowDuration: TimeInterval,
        overlap: TimeInterval
    ) -> [ParakeetAudioWindow] {
        guard duration > 0, windowDuration > 0 else {
            return []
        }

        let minimumStride = min(1, windowDuration)
        let boundedOverlap = min(max(overlap, 0), max(0, windowDuration - minimumStride))
        guard duration > windowDuration else {
            return [
                ParakeetAudioWindow(
                    start: 0,
                    end: duration,
                    commitStart: 0,
                    commitEnd: duration
                )
            ]
        }

        let stride = windowDuration - boundedOverlap
        let minimumWindowDuration = min(1, windowDuration)
        var rawWindows: [(start: TimeInterval, end: TimeInterval)] = []
        var start: TimeInterval = 0

        while start < duration {
            let end = min(duration, start + windowDuration)
            if end - start >= minimumWindowDuration {
                rawWindows.append((start: start, end: end))
            }

            start += stride
        }

        guard !rawWindows.isEmpty else {
            return [
                ParakeetAudioWindow(
                    start: 0,
                    end: duration,
                    commitStart: 0,
                    commitEnd: duration
                )
            ]
        }

        return rawWindows.enumerated().map { offset, rawWindow in
            let commitStart: TimeInterval
            if offset == 0 {
                commitStart = 0
            } else {
                let previous = rawWindows[offset - 1]
                commitStart = (previous.end + rawWindow.start) / 2
            }

            let commitEnd: TimeInterval
            if offset == rawWindows.count - 1 {
                commitEnd = duration
            } else {
                let next = rawWindows[offset + 1]
                commitEnd = (rawWindow.end + next.start) / 2
            }

            return ParakeetAudioWindow(
                start: rawWindow.start,
                end: rawWindow.end,
                commitStart: commitStart,
                commitEnd: commitEnd
            )
        }
    }

    func containsCommitted(_ word: WordTiming) -> Bool {
        let midpoint = (word.start + word.end) / 2
        return midpoint >= commitStart && midpoint < commitEnd
    }
}
