import Combine
import Foundation
import Media
import Project
import Subtitles

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recentProjects: [ProjectSummary]
    @Published var errorMessage: String?
    @Published var isSavingProject = false

    private let projectCatalog: any ProjectCatalogManaging
    private let projectRepository: any ProjectRepository
    private let projectFileService: any ProjectFileServicing
    private let mediaMetadataService: any MediaMetadataProviding
    private let fileManager: FileManager
    private let mockProject: Project
    private let mockSubtitles: [SubtitleSegment]
    private let supportedExtensions = Set(["mp4", "mov", "m4v", "webm", "mkv"])
    private var catalogSubscription: AnyCancellable?

    init(
        projectCatalog: any ProjectCatalogManaging,
        projectRepository: any ProjectRepository,
        projectFileService: any ProjectFileServicing,
        mediaMetadataService: any MediaMetadataProviding,
        fileManager: FileManager = .default,
        mockProject: Project,
        mockSubtitles: [SubtitleSegment]
    ) {
        self.projectCatalog = projectCatalog
        self.projectRepository = projectRepository
        self.projectFileService = projectFileService
        self.mediaMetadataService = mediaMetadataService
        self.fileManager = fileManager
        self.mockProject = mockProject
        self.mockSubtitles = mockSubtitles
        recentProjects = projectCatalog.snapshot.summaries
        catalogSubscription = projectCatalog.snapshots.sink { [weak self] snapshot in
            self?.recentProjects = snapshot.summaries
            if let failure = snapshot.failure {
                self?.errorMessage = failure.message
            }
        }
    }

    func createMockProject() -> Project {
        let project = mockProject
        projectCatalog.register(project)
        return project
    }

    func selectProject(_ summary: ProjectSummary) async -> Project? {
        do {
            let loadedProject = try await projectCatalog.open(id: summary.id)
            errorMessage = nil
            return loadedProject
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? "Could not open project."
            return nil
        } catch {
            errorMessage = "Could not open project."
            return nil
        }
    }

    func loadRecentProjects() async {
        await projectCatalog.refresh()
        if let failure = projectCatalog.snapshot.failure {
            errorMessage = failure.message
        }
    }

    func createProject(from videoURL: URL) async -> Project? {
        guard isSupportedVideo(videoURL) else {
            errorMessage = "Unsupported file format. Choose MP4, MOV, M4V, WEBM, or MKV."
            return nil
        }

        isSavingProject = true
        defer { isSavingProject = false }

        let didAccessResource = videoURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessResource {
                videoURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let mediaFile = try await makeMediaFile(from: videoURL)
            var project = try await projectRepository.createProject(for: mediaFile)
            project.subtitles = mockSubtitles
            project.status = .ready
            project.updatedAt = Date()
            try await projectRepository.saveProject(project)

            projectCatalog.register(project)
            errorMessage = nil
            return project
        } catch {
            errorMessage = "Project save failed."
            return nil
        }
    }

    func openProjectFile(_ fileURL: URL) async -> Project? {
        isSavingProject = true
        defer { isSavingProject = false }

        let didAccessResource = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessResource {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let project = try projectFileService.importProject(from: fileURL)
            guard videoFileExists(at: project.mediaFile.originalURL) else {
                throw ProjectFileError.videoFileMissing(project.mediaFile.originalURL.path)
            }

            try await projectRepository.saveProject(project)
            projectCatalog.register(project)
            errorMessage = nil
            return project
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? "Could not open project file."
            return nil
        } catch {
            errorMessage = "Could not open project file."
            return nil
        }
    }

    private func isSupportedVideo(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private func makeMediaFile(from url: URL) async throws -> MediaFile {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        let fileName = url.lastPathComponent
        let durationMs: Int?

        do {
            durationMs = try await mediaMetadataService.durationMs(for: url)
        } catch {
            durationMs = nil
        }

        return MediaFile(
            id: UUID(),
            originalURL: url,
            fileName: fileName,
            fileExtension: url.pathExtension.lowercased(),
            sizeBytes: Int64(resourceValues.fileSize ?? 0),
            durationMs: durationMs
        )
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
