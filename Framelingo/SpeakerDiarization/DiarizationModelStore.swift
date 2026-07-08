import FluidAudio
import Foundation

enum DiarizationModelError: LocalizedError, Equatable {
    case modelsNotFound
    case modelDirectoryUnavailable
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelsNotFound:
            "Speaker analysis models are not installed yet."
        case .modelDirectoryUnavailable:
            "Speaker analysis model directory is unavailable."
        case .modelLoadFailed(let message):
            "Speaker analysis models could not be loaded: \(message)"
        }
    }
}

struct DiarizationModelStore {
    let localModelDirectoryURL: URL

    init(localModelDirectoryURL: URL? = nil) {
        self.localModelDirectoryURL = localModelDirectoryURL
            ?? OfflineDiarizerModels.defaultModelsDirectory()
    }

    func modelsArePresent() -> Bool {
        let repoDirectory = localModelDirectoryURL.appendingPathComponent(Repo.diarizer.folderName)
        return ModelNames.OfflineDiarizer.requiredModels.allSatisfy { modelName in
            FileManager.default.fileExists(
                atPath: repoDirectory.appendingPathComponent(modelName).path
            )
        }
    }

    func ensureModelDirectoryExists() throws -> URL {
        do {
            try FileManager.default.createDirectory(
                at: localModelDirectoryURL,
                withIntermediateDirectories: true
            )
            return localModelDirectoryURL
        } catch {
            throw DiarizationModelError.modelDirectoryUnavailable
        }
    }
}
