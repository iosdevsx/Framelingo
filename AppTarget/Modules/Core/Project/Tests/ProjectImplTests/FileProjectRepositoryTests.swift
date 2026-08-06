import Foundation
import Project
import ProjectImpl
import Testing
import Timeline
import VideoRendering

struct FileProjectRepositoryTests {
    @Test
    func savedEditTimelineSurvivesReloadForRetranscription() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectTimelineReloadTests-\(UUID().uuidString)")
        let videoURL = rootURL.appendingPathComponent("source.mov")
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
            durationMs: 10_000
        )
        var project = try await repository.createProject(for: mediaFile)
        project.editTimeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 1_000,
                    sourceEndMs: 3_000,
                    timelineStartMs: 0,
                    timelineEndMs: 2_000
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 7_000,
                    sourceEndMs: 9_000,
                    timelineStartMs: 2_000,
                    timelineEndMs: 4_000
                ),
            ],
            totalDurationMs: 4_000
        )
        try await repository.saveProject(project)

        let reopenedProject = try await repository.loadProject(id: project.id)

        #expect(reopenedProject.editTimeline == project.editTimeline)
        #expect(
            try ExportClipPlanResolver.clips(for: reopenedProject) == [
                ExportClipRange(sourceStartMs: 1_000, sourceEndMs: 3_000),
                ExportClipRange(sourceStartMs: 7_000, sourceEndMs: 9_000),
            ]
        )

        try FileManager.default.removeItem(at: rootURL)
    }

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
