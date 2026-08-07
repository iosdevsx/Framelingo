import AVFoundation
import Foundation
import Project

enum IOSDocumentImportFailure: Error, Equatable, LocalizedError {
    case accessDenied(String)
    case sourceMissing(String)
    case copyFailed(String)
    case invalidProject(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied(let path):
            "Access to the selected document expired or was denied: \(path)"
        case .sourceMissing(let path):
            "The selected file is missing: \(path)"
        case .copyFailed(let message):
            "The document could not be copied into Framelingo: \(message)"
        case .invalidProject(let message):
            "The selected project could not be opened: \(message)"
        }
    }
}

struct IOSSecurityScopedAccess: Sendable {
    let start: @Sendable (URL) -> Bool
    let stop: @Sendable (URL) -> Void

    static let live = IOSSecurityScopedAccess(
        start: { $0.startAccessingSecurityScopedResource() },
        stop: { $0.stopAccessingSecurityScopedResource() }
    )
}

struct IOSMediaDurationReader: Sendable {
    let durationMilliseconds: @Sendable (URL) async throws -> Int?

    static let live = IOSMediaDurationReader { url in
        let duration = try await AVURLAsset(url: url).load(.duration)
        guard duration.isNumeric else { return nil }
        let milliseconds = duration.seconds * 1_000
        guard milliseconds.isFinite, milliseconds >= 0 else { return nil }
        return Int(milliseconds.rounded())
    }
}

protocol IOSDocumentImporting: Actor {
    func importProject(from sourceURL: URL) async throws -> Project
    func importMedia(from sourceURL: URL) async throws -> MediaFile
    func releaseAllResources()
}

actor IOSDocumentImportAdapter: IOSDocumentImporting {
    private let fileManager: FileManager
    private let mediaRootURL: URL
    private let projectFileService: any ProjectFileServicing
    private let securityAccess: IOSSecurityScopedAccess
    private let durationReader: IOSMediaDurationReader
    private var activeResources: Set<URL> = []

    init(
        fileManager: FileManager = .default,
        mediaRootURL: URL,
        projectFileService: any ProjectFileServicing,
        securityAccess: IOSSecurityScopedAccess = .live,
        durationReader: IOSMediaDurationReader = .live
    ) {
        self.fileManager = fileManager
        self.mediaRootURL = mediaRootURL
        self.projectFileService = projectFileService
        self.securityAccess = securityAccess
        self.durationReader = durationReader
    }

    func importProject(from sourceURL: URL) async throws -> Project {
        try await withSecurityScopedAccess(to: sourceURL) {
            let imported: Project
            do {
                imported = try projectFileService.importProject(from: sourceURL)
            } catch {
                throw IOSDocumentImportFailure.invalidProject(error.localizedDescription)
            }

            var managedProject = imported
            managedProject.mediaFile = try await importExistingMedia(imported.mediaFile)
            return managedProject
        }
    }

    func importMedia(from sourceURL: URL) async throws -> MediaFile {
        try await withSecurityScopedAccess(to: sourceURL) {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw IOSDocumentImportFailure.sourceMissing(sourceURL.path)
            }

            let id = UUID()
            let managedURL = try copyToManagedStorage(sourceURL, mediaID: id)
            let values = try managedURL.resourceValues(forKeys: [.fileSizeKey])
            return MediaFile(
                id: id,
                originalURL: managedURL,
                fileName: sourceURL.lastPathComponent,
                fileExtension: sourceURL.pathExtension,
                sizeBytes: Int64(values.fileSize ?? 0),
                durationMs: try await durationReader.durationMilliseconds(managedURL)
            )
        }
    }

    func releaseAllResources() {
        let resources = activeResources
        activeResources.removeAll()
        for url in resources {
            securityAccess.stop(url)
        }
    }

    private func importExistingMedia(_ mediaFile: MediaFile) async throws -> MediaFile {
        let sourceURL = mediaFile.originalURL
        if sourceURL.standardizedFileURL.path.hasPrefix(
            mediaRootURL.standardizedFileURL.path + "/"
        ) {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw IOSDocumentImportFailure.sourceMissing(sourceURL.path)
            }
            return mediaFile
        }

        return try await withSecurityScopedAccess(to: sourceURL) {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw IOSDocumentImportFailure.sourceMissing(sourceURL.path)
            }
            var managed = mediaFile
            managed.originalURL = try copyToManagedStorage(sourceURL, mediaID: mediaFile.id)
            return managed
        }
    }

    private func copyToManagedStorage(_ sourceURL: URL, mediaID: UUID) throws -> URL {
        let directory = mediaRootURL.appendingPathComponent(
            mediaID.uuidString,
            isDirectory: true
        )
        let destination = directory.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            throw IOSDocumentImportFailure.copyFailed(error.localizedDescription)
        }
    }

    private func withSecurityScopedAccess<T>(
        to url: URL,
        operation: () async throws -> T
    ) async throws -> T {
        guard securityAccess.start(url) else {
            throw IOSDocumentImportFailure.accessDenied(url.path)
        }
        activeResources.insert(url)
        defer {
            if activeResources.remove(url) != nil {
                securityAccess.stop(url)
            }
        }
        return try await operation()
    }
}
