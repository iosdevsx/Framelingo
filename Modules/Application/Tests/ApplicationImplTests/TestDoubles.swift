import Foundation
import Project
import Subtitles

enum TestDoubles {
    enum TestError: Error {
        case expected
    }

    final class Repository: ProjectRepository {
        var projects: [UUID: Project] = [:]
        var savedProjects: [Project] = []

        func createProject(for mediaFile: MediaFile) async throws -> Project {
            throw TestError.expected
        }

        func saveProject(_ project: Project) async throws {
            projects[project.id] = project
            savedProjects.append(project)
        }

        func loadProject(id: UUID) async throws -> Project {
            guard let project = projects[id] else { throw TestError.expected }
            return project
        }

        func listProjects() async throws -> [Project] {
            Array(projects.values)
        }

        func deleteProject(id: UUID) async throws {
            projects[id] = nil
        }
    }

    static func project(subtitles: [SubtitleSegment]? = nil) -> Project {
        let segment = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 0,
            endMs: 2_000,
            originalText: "Hello",
            translatedText: ""
        )
        return Project(
            id: UUID(),
            name: "Test",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            mediaFile: MediaFile(
                id: UUID(),
                originalURL: URL(fileURLWithPath: "/tmp/test.mp4"),
                fileName: "test.mp4",
                fileExtension: "mp4",
                sizeBytes: 1,
                durationMs: 10_000
            ),
            sourceLanguage: "English",
            targetLanguage: "Russian",
            subtitles: subtitles ?? [segment],
            status: .ready
        )
    }
}
