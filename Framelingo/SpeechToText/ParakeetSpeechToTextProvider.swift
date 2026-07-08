// FluidAudio ASR calls intentionally target the pinned 0.14.1 API. See the
// archive-build note atop FluidAudioSpeakerDiarizationEngine.swift before
// changing the package pin or these call sites.
import FluidAudio
import Foundation

struct ParakeetSpeechToTextProvider: SpeechToTextProvider {
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
        let models = try await loadModels(progressHandler: input.progressHandler)

        try Task.checkCancellation()
        let manager = AsrManager(config: .default, models: models)
        let progressTask = transcriptionProgressTask(
            manager: manager,
            progressHandler: input.progressHandler
        )
        defer {
            progressTask?.cancel()
        }

        let result: ASRResult
        do {
            await input.progressHandler?(0.25, "Running Parakeet…")
            var decoderState = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
            result = try await manager.transcribe(
                audioURL,
                decoderState: &decoderState,
                language: ParakeetLanguageSupport.fluidAudioLanguageHint(for: input.sourceLanguage)
            )
        } catch let error as CancellationError {
            throw error
        } catch {
            throw ParakeetTranscriptionError.transcriptionFailed(error.localizedDescription)
        }

        try Task.checkCancellation()
        await input.progressHandler?(0.95, "Processing Parakeet transcript…")
        let words = wordTimingMerger.merge(result.tokenTimings ?? [])
        let segments = cueBuilder.build(from: words)

        return TranscriptionResult(
            segments: segments,
            words: words,
            detectedLanguage: nil,
            durationMs: Int((result.duration * 1_000).rounded())
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
}
