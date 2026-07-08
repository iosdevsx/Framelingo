import Foundation

protocol ProjectRepository {
    func createProject(for mediaFile: MediaFile) async throws -> Project
    func saveProject(_ project: Project) async throws
    func loadProject(id: UUID) async throws -> Project
    func listProjects() async throws -> [Project]
    func deleteProject(id: UUID) async throws
}
