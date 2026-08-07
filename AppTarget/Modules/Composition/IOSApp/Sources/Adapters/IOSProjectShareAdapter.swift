import Foundation
import Project

protocol IOSProjectSharePreparing: Actor {
    func prepare(_ project: Project) throws -> URL
}

actor IOSProjectShareAdapter: IOSProjectSharePreparing {
    private let fileManager: FileManager
    private let exportRootURL: URL
    private let projectFileService: any ProjectFileServicing

    init(
        fileManager: FileManager = .default,
        exportRootURL: URL,
        projectFileService: any ProjectFileServicing
    ) {
        self.fileManager = fileManager
        self.exportRootURL = exportRootURL
        self.projectFileService = projectFileService
    }

    func prepare(_ project: Project) throws -> URL {
        try fileManager.createDirectory(at: exportRootURL, withIntermediateDirectories: true)
        let fileName = sanitizedFileName(project.displayName) + ".framelingo.json"
        let url = exportRootURL.appendingPathComponent(fileName)
        try projectFileService.exportProject(project, to: url)
        return url
    }

    private func sanitizedFileName(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:")
        let components = value.components(separatedBy: forbidden)
        let result = components.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "Project" : result
    }
}
