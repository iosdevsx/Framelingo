import Foundation
import Project
import ProjectImpl
import Testing

struct FileProjectRepositoryTests {
    @Test
    func createListSaveLoadAndDelete() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectRepositoryTests-\(UUID().uuidString)")
        let videoURL = rootURL.appendingPathComponent("Видео с пробелами.mov")
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        try Data().write(to: videoURL)

        let repository = ProjectAssembly.makeRepository(projectsDirectory: rootURL)
        let mediaFile = MediaFile(
            id: UUID(),
            originalURL: videoURL,
            fileName: videoURL.lastPathComponent,
            fileExtension: videoURL.pathExtension,
            sizeBytes: 0,
            durationMs: 1_000
        )
        var project = try await repository.createProject(for: mediaFile)
        #expect(try await repository.listProjects().map(\.id) == [project.id])

        project.name = "Updated"
        project.updatedAt = Date().addingTimeInterval(1)
        try await repository.saveProject(project)
        #expect(try await repository.loadProject(id: project.id).name == "Updated")

        try await repository.deleteProject(id: project.id)
        #expect(try await repository.listProjects().isEmpty)
        try FileManager.default.removeItem(at: rootURL)
    }
}
