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

        let manager = OfflineDiarizerManager(config: .default)
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
