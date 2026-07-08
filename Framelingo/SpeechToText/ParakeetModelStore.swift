// FluidAudio ASR calls intentionally target the pinned 0.14.1 API. See the
// archive-build note atop FluidAudioSpeakerDiarizationEngine.swift before
// changing the package pin or these call sites.
import FluidAudio
import Foundation

struct ParakeetModelStore {
    static let approximateDownloadSizeText = "~1 GB"

    let localModelDirectoryURL: URL

    init(localModelDirectoryURL: URL? = nil) {
        self.localModelDirectoryURL = localModelDirectoryURL
            ?? AsrModels.defaultCacheDirectory(for: .v3)
    }

    func modelsArePresent() -> Bool {
        AsrModels.modelsExist(at: localModelDirectoryURL, version: .v3)
    }

    func downloadAndLoadModels(
        progressHandler: DownloadUtils.ProgressHandler? = nil
    ) async throws -> AsrModels {
        try await AsrModels.downloadAndLoad(
            to: localModelDirectoryURL,
            version: .v3,
            progressHandler: progressHandler
        )
    }

    static func statusText(for progress: DownloadUtils.DownloadProgress) -> String {
        switch progress.phase {
        case .listing:
            return "Checking Parakeet models…"
        case .downloading:
            return "Downloading Parakeet models…"
        case .compiling(let modelName):
            let trimmedName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedName.isEmpty ? "Compiling Parakeet models…" : "Compiling \(trimmedName)…"
        }
    }
}
