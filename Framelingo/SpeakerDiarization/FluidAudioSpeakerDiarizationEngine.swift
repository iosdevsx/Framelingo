// FluidAudio is pinned to an exact version (see project.pbxproj package
// reference + Package.resolved) instead of a range. 0.14.2+ added TTS code
// (CosyVoice3Synthesizer.swift, StyleTTS2Synthesizer.swift) that uses
// `Float16` without `#if arch(arm64)` guards, which fails to compile for
// macOS x86_64 and breaks `xcodebuild archive` / Xcode's Product > Archive
// (it always attempts a universal build regardless of the host app's own
// ARCHS setting). Versions <= 0.14.1 guard every Float16 use per-arch and
// compile cleanly on both architectures. Only bump the pin after confirming
// `xcodebuild archive -destination generic/platform=macOS` still succeeds.
import FluidAudio
import Foundation

enum DiarizationError: LocalizedError, Equatable {
    case requiresMacOS14
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .requiresMacOS14:
            "Speaker analysis requires macOS 14 or later."
        case .modelLoadFailed(let message):
            "Speaker analysis failed to load models: \(message)"
        }
    }
}

final class FluidAudioSpeakerDiarizationEngine: SpeakerDiarizationEngine {
    private let modelStore: DiarizationModelStore
    private let progressHandler: DiarizationProgressHandler?
    private static let diarizerConfig = OfflineDiarizerConfig(
        // Baseline clustering distance. Lower values split speakers more aggressively; higher values merge similar speakers.
        clusteringThreshold: 0.6,
        // Baseline VBx warm-start precision. Deviations need measured rationale, not guesswork.
        Fa: 0.07,
        // Baseline VBx warm-start recall. Raising it can merge borderline speaker turns.
        Fb: 0.8,
        // Baseline segmentation window. Shorter windows cost more inference and can destabilize embeddings.
        windowDuration: 10.0,
        // Baseline sample rate expected by FluidAudio's offline diarization models.
        sampleRate: 16_000,
        // Baseline step ratio. Lower values increase overlap and cost; higher values reduce temporal resolution.
        segmentationStepRatio: 0.2,
        // Baseline embedding batch size, kept at the library's PLDA-safe maximum.
        embeddingBatchSize: 32,
        // Baseline overlap masking. Disabling it can contaminate embeddings during overlapping speech.
        embeddingExcludeOverlap: true,
        // Baseline extraction behavior. Skipping embeddings trades accuracy for speed and needs measured support.
        embeddingSkipStrategy: .none,
        // Baseline minimum segment duration. Lower values admit short fragments; higher values suppress short turns.
        minSegmentDuration: 1.0,
        // Baseline post-processing merge gap. Raising it merges nearby turns more aggressively.
        minGapDuration: 0.1,
        // Baseline exclusive output. Disabling it allows overlapping speaker segments in the app model.
        exclusiveSegments: true,
        // Baseline speech onset threshold. Lower values admit weaker speech; higher values can miss quiet starts.
        speechOnsetThreshold: 0.5,
        // Baseline speech offset threshold. Lower values extend speech; higher values can cut endings early.
        speechOffsetThreshold: 0.5,
        // Baseline segmentation onset duration. Raising it filters brief speech activations.
        segmentationMinDurationOn: 0.0,
        // Baseline segmentation offset duration. Raising it merges short pauses into speech.
        segmentationMinDurationOff: 0.0,
        // Baseline VBx iteration cap. Raising it costs more CPU with no current product evidence.
        maxVBxIterations: 20,
        // Baseline VBx convergence tolerance. Lower values may cost more CPU for marginal changes.
        convergenceTolerance: 1e-4,
        // Baseline export behavior. Embeddings are not persisted by the app.
        embeddingExportPath: nil
    )

    init(
        modelStore: DiarizationModelStore = DiarizationModelStore(),
        progressHandler: DiarizationProgressHandler? = nil
    ) {
        self.modelStore = modelStore
        self.progressHandler = progressHandler
    }

    func diarize(audioURL: URL) async throws -> [SpeakerSegment] {
        guard #available(macOS 14.0, *) else {
            throw DiarizationError.requiresMacOS14
        }

        try Task.checkCancellation()
        let modelDirectory = try modelStore.ensureModelDirectoryExists()
        await progressHandler?(nil, modelStore.modelsArePresent() ? "Loading speaker models..." : "Downloading speaker models...")

        // Keep this aligned with FluidAudio 0.14.1's documented baseline. Any
        // deviation requires an OpenSpec rationale, and future tuning should be
        // informed by `whisper-timestamp-accuracy` timing results.
        let manager = OfflineDiarizerManager(config: Self.diarizerConfig)
        do {
            let models = try await OfflineDiarizerModels.load(
                from: modelDirectory,
                progressHandler: { [progressHandler] progress in
                    guard let progressHandler else {
                        return
                    }

                    Task {
                        await progressHandler(
                            progress.fractionCompleted,
                            Self.statusText(for: progress)
                        )
                    }
                }
            )
            manager.initialize(models: models)
        } catch {
            throw DiarizationError.modelLoadFailed(error.localizedDescription)
        }

        try Task.checkCancellation()
        await progressHandler?(nil, "Recognizing speakers...")
        let result = try await manager.process(audioURL)

        return mapSegments(result.segments)
    }

    private static func statusText(for progress: DownloadUtils.DownloadProgress) -> String {
        switch progress.phase {
        case .listing:
            "Checking speaker models..."
        case .downloading:
            "Downloading speaker models..."
        case .compiling(let modelName):
            "Compiling \(modelName)..."
        }
    }

    private func mapSegments(_ segments: [TimedSpeakerSegment]) -> [SpeakerSegment] {
        var speakerIDsByFluidID: [String: Int] = [:]
        var nextSpeakerID = 0

        return segments.map { segment in
            let speakerID: Int
            if let existing = speakerIDsByFluidID[segment.speakerId] {
                speakerID = existing
            } else if let parsed = Self.trailingInteger(in: segment.speakerId) {
                speakerID = parsed
                speakerIDsByFluidID[segment.speakerId] = parsed
                nextSpeakerID = max(nextSpeakerID, parsed + 1)
            } else {
                speakerID = nextSpeakerID
                speakerIDsByFluidID[segment.speakerId] = speakerID
                nextSpeakerID += 1
            }

            return SpeakerSegment(
                speakerId: speakerID,
                start: TimeInterval(segment.startTimeSeconds),
                end: TimeInterval(segment.endTimeSeconds),
                confidence: Double(segment.qualityScore)
            )
        }
    }

    private static func trailingInteger(in value: String) -> Int? {
        let digits = value.reversed().prefix { $0.isNumber }.reversed()
        guard !digits.isEmpty else {
            return nil
        }

        return Int(String(digits))
    }
}
