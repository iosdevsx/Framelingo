import Foundation

struct WhisperInstallation: Equatable {
    var executableURL: URL
    var modelURL: URL
    var model: WhisperModel
}

enum WhisperInstallerError: LocalizedError {
    case executableNotFound
    case modelDownloadFailed
    case invalidModel

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Whisper executable was not found. Add whisper.cpp to the project or bundle whisper-cli with the app."
        case .modelDownloadFailed:
            return "Could not download the Whisper model."
        case .invalidModel:
            return "Selected Whisper model is invalid."
        }
    }
}

struct WhisperInstaller {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func install(
        model: WhisperModel,
        progressHandler: @escaping @Sendable (Double?) async -> Void
    ) async throws -> WhisperInstallation {
        guard let executableURL = findWhisperExecutable() else {
            throw WhisperInstallerError.executableNotFound
        }

        let modelURL = try await ensureModelInstalled(model, progressHandler: progressHandler)
        return WhisperInstallation(
            executableURL: executableURL,
            modelURL: modelURL,
            model: model
        )
    }

    func findWhisperExecutable() -> URL? {
        let bundleCandidates = [
            Bundle.main.url(forResource: "whisper-cli", withExtension: nil),
            Bundle.main.url(forResource: "main", withExtension: nil),
            Bundle.main.resourceURL?
                .appendingPathComponent("Whisper", isDirectory: true)
                .appendingPathComponent("whisper-cli")
        ].compactMap { $0 }

        let relativeCandidates = [
            "whisper.cpp/build/bin/whisper-cli",
            "whisper.cpp/build/bin/main",
            "whisper.cpp/main",
            "whisper/build/bin/whisper-cli",
            "whisper-cli"
        ]

        let searchRoots = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath),
            sourceRootURL()
        ]

        let projectCandidates = searchRoots.flatMap { rootURL in
            relativeCandidates.map { relativePath in
                URL(fileURLWithPath: relativePath, relativeTo: rootURL).standardizedFileURL
            }
        }

        return (bundleCandidates + projectCandidates).first { url in
            fileManager.isExecutableFile(atPath: url.path)
        }
    }

    func installedModelURL(for model: WhisperModel) throws -> URL {
        try modelsDirectoryURL().appendingPathComponent(model.fileName)
    }

    func isModelInstalled(_ model: WhisperModel) -> Bool {
        guard let url = try? installedModelURL(for: model) else {
            return false
        }

        return fileManager.fileExists(atPath: url.path)
    }

    private func ensureModelInstalled(
        _ model: WhisperModel,
        progressHandler: @escaping @Sendable (Double?) async -> Void
    ) async throws -> URL {
        let destinationURL = try installedModelURL(for: model)
        if fileManager.fileExists(atPath: destinationURL.path) {
            await progressHandler(1)
            return destinationURL
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let temporaryURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(model.fileName).download")

        if fileManager.fileExists(atPath: temporaryURL.path) {
            try fileManager.removeItem(at: temporaryURL)
        }

        do {
            let (bytes, response) = try await URLSession.shared.bytes(from: model.downloadURL)
            let expectedLength = response.expectedContentLength
            fileManager.createFile(atPath: temporaryURL.path, contents: nil)

            let fileHandle = try FileHandle(forWritingTo: temporaryURL)
            defer {
                try? fileHandle.close()
            }

            var downloadedBytes: Int64 = 0
            var buffer = Data()
            buffer.reserveCapacity(262_144)
            for try await byte in bytes {
                buffer.append(byte)
                downloadedBytes += 1

                if buffer.count >= 262_144 {
                    try fileHandle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                }

                if expectedLength > 0, downloadedBytes % 524_288 == 0 {
                    await progressHandler(Double(downloadedBytes) / Double(expectedLength))
                }
            }

            if !buffer.isEmpty {
                try fileHandle.write(contentsOf: buffer)
            }

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            await progressHandler(1)
            return destinationURL
        } catch {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.removeItem(at: temporaryURL)
            }
            throw WhisperInstallerError.modelDownloadFailed
        }
    }

    private func modelsDirectoryURL() throws -> URL {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        return applicationSupportURL
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("Whisper", isDirectory: true)
    }

    private func sourceRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
