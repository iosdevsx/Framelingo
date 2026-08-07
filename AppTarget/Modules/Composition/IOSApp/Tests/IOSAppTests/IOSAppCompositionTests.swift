import Foundation
@testable import IOSApp
import Project
import XCTest

@MainActor
final class IOSAppCompositionTests: XCTestCase {
    func testControlledCompositionUsesOneSessionAcrossProjectReplacement() {
        let repository = InMemoryProjectRepository()
        let model = IOSAppComposition.makeModel(repository: repository)
        let first = Project.fixture(name: "First")
        let second = Project.fixture(name: "Second")

        model.open(first)
        XCTAssertEqual(model.openedProject?.id, first.id)

        model.open(second)
        XCTAssertEqual(model.openedProject?.id, second.id)
        XCTAssertEqual(model.snapshot.history, .empty)
    }
}

private final class InMemoryProjectRepository: ProjectRepository {
    private var projects: [UUID: Project] = [:]

    func createProject(for mediaFile: MediaFile) async throws -> Project {
        let project = Project.fixture(name: mediaFile.fileName, mediaFile: mediaFile)
        projects[project.id] = project
        return project
    }

    func saveProject(_ project: Project) async throws { projects[project.id] = project }
    func loadProject(id: UUID) async throws -> Project { try XCTUnwrap(projects[id]) }
    func listProjects() async throws -> [Project] { Array(projects.values) }
    func deleteProject(id: UUID) async throws { projects[id] = nil }
}

private extension Project {
    static func fixture(name: String, mediaFile: MediaFile? = nil) -> Project {
        Project(
            id: UUID(),
            name: name,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            mediaFile: mediaFile ?? MediaFile(
                id: UUID(),
                originalURL: URL(fileURLWithPath: "/tmp/video.mov"),
                fileName: "video.mov",
                fileExtension: "mov",
                sizeBytes: 1,
                durationMs: 1_000
            ),
            sourceLanguage: "English",
            targetLanguage: "Russian",
            subtitles: [],
            status: .idle
        )
    }
}
