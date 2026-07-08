import Foundation

final class FileProjectRepository: ProjectRepository {
    private let fileManager: FileManager
    private let projectsDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, appName: String = "Framelingo") {
        self.fileManager = fileManager

        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        projectsDirectory = applicationSupportURL
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func createProject(for mediaFile: MediaFile) async throws -> Project {
        let project = Project(
            id: UUID(),
            name: mediaFile.fileName,
            createdAt: Date(),
            updatedAt: Date(),
            mediaFile: mediaFile,
            sourceLanguage: "English",
            targetLanguage: "Russian",
            subtitles: [],
            status: .idle
        )

        try await saveProject(project)
        return project
    }

    func saveProject(_ project: Project) async throws {
        let projectDirectory = projectDirectory(for: project.id)
        try fileManager.createDirectory(
            at: projectDirectory,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(project)
        try data.write(to: projectURL(for: project.id), options: .atomic)
    }

    func loadProject(id: UUID) async throws -> Project {
        let data = try Data(contentsOf: projectURL(for: id))
        let project = try decoder.decode(Project.self, from: data)

        guard videoFileExists(at: project.mediaFile.originalURL) else {
            throw AppError.videoFileMissing(project.mediaFile.originalURL.path)
        }

        return project
    }

    func listProjects() async throws -> [Project] {
        guard fileManager.fileExists(atPath: projectsDirectory.path) else {
            return []
        }

        let projectDirectories = try fileManager.contentsOfDirectory(
            at: projectsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        let projects = try projectDirectories.compactMap { directory -> Project? in
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                return nil
            }

            let projectURL = directory.appendingPathComponent("project.json")
            guard fileManager.fileExists(atPath: projectURL.path) else {
                return nil
            }

            let data = try Data(contentsOf: projectURL)
            return try decoder.decode(Project.self, from: data)
        }

        return projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    func deleteProject(id: UUID) async throws {
        let directory = projectDirectory(for: id)
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }

        try fileManager.removeItem(at: directory)
    }

    private func projectDirectory(for id: UUID) -> URL {
        projectsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func projectURL(for id: UUID) -> URL {
        projectDirectory(for: id).appendingPathComponent("project.json")
    }

    private func videoFileExists(at url: URL) -> Bool {
        guard url.isFileURL else {
            return false
        }

        let didAccessResource = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessResource {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return fileManager.fileExists(atPath: url.path)
    }
}
