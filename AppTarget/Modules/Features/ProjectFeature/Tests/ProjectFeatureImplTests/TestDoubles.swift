import ExportFeature
import Foundation
import PlayerFeature
import Project
import ProjectFeature
import ProjectSession
import ProjectSessionImpl
import ShortsFeature
import Subtitles
import SubtitleEditorFeature
import SwiftUI
import TimelineFeature
import TimelineImpl

@testable import ProjectFeatureImpl

enum TestDoubles {
    @MainActor
    final class Context {
        let session: DefaultProjectSession

        init(project: Project) {
            session = DefaultProjectSession(dependencies: ProjectSessionDependencies(
                repository: Repository(),
                editTimelineService: TimelineAssembly.makeEditService()
            ))
            session.open(project)
        }
    }

    actor Repository: ProjectRepository {
        private var projects: [UUID: Project] = [:]

        func createProject(for mediaFile: MediaFile) async throws -> Project {
            throw RepositoryError.unavailable
        }
        func saveProject(_ project: Project) async throws { projects[project.id] = project }
        func loadProject(id: UUID) async throws -> Project {
            guard let project = projects[id] else { throw RepositoryError.unavailable }
            return project
        }
        func listProjects() async throws -> [Project] { Array(projects.values) }
        func deleteProject(id: UUID) async throws { projects[id] = nil }
    }

    enum RepositoryError: Error { case unavailable }

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

    @MainActor
    static func appState(project: Project) -> Context { Context(project: project) }

    @MainActor
    static func projectFeatureDependencies(appState: Context) -> ProjectFeatureDependencies {
        ProjectFeatureDependencies(
            session: appState.session,
            subtitleDocumentPicker: SubtitleDocumentPicker { _ in .cancelled }
        )
    }

    @MainActor
    static func projectFeatureComponents() -> ProjectFeatureComponents {
        ProjectFeatureComponents(
            player: PlayerFeatureFactory { _ in AnyView(EmptyView()) },
            timeline: TimelineFeatureFactory(
                makeSubtitleTimeline: { _ in AnyView(EmptyView()) },
                makeEditTimeline: { _ in AnyView(EmptyView()) }
            ),
            subtitleEditor: SubtitleEditorFeatureFactory(
                makeCueList: { _ in AnyView(EmptyView()) },
                makeEditorPane: { _ in AnyView(EmptyView()) },
                makeSubtitleEditor: { _ in AnyView(EmptyView()) },
                makeImportPreview: { _ in AnyView(EmptyView()) }
            ),
            shorts: ShortsFeatureFactory { _ in AnyView(EmptyView()) },
            export: ExportFeatureFactory(
                makeVideoSheet: { _ in AnyView(EmptyView()) },
                makeSubtitleOptionsSheet: { _ in AnyView(EmptyView()) }
            )
        )
    }
}
