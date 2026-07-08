import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recentProjects: [Project]
    @Published var selectedProject: Project?
    @Published var errorMessage: String?
    @Published var isSavingProject = false

    private let appState: AppState
    private let projectFileService = ProjectFileService()
    private let mediaMetadataService = MediaMetadataService()
    private let supportedExtensions = Set(["mp4", "mov", "m4v", "webm", "mkv"])

    init(appState: AppState) {
        self.appState = appState
        recentProjects = appState.recentProjects
        selectedProject = appState.selectedProject
    }

    func createMockProject() {
        let project = MockData.project
        appState.selectedProject = project
        appState.recentProjects.insert(project, at: 0)
        recentProjects = appState.recentProjects
        selectedProject = project
    }

    func selectProject(_ project: Project) async {
        do {
            let loadedProject = try await appState.projectRepository.loadProject(id: project.id)
            appState.selectedProject = loadedProject
            selectedProject = loadedProject
            errorMessage = nil
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? "Could not open project."
        } catch {
            errorMessage = "Could not open project."
        }
    }

    func loadRecentProjects() async {
        do {
            let projects = try await appState.projectRepository.listProjects()
            if !projects.isEmpty {
                appState.recentProjects = projects
                recentProjects = projects
            }
        } catch {
            errorMessage = "Could not load recent projects."
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
            var project = try await appState.projectRepository.createProject(for: mediaFile)
            project.subtitles = MockData.subtitles
            project.status = .ready
            project.updatedAt = Date()
            try await appState.projectRepository.saveProject(project)

            appState.selectedProject = project
            appState.recentProjects.removeAll { $0.id == project.id }
            appState.recentProjects.insert(project, at: 0)
            recentProjects = appState.recentProjects
            selectedProject = project
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

            try await appState.projectRepository.saveProject(project)
            appState.selectedProject = project
            appState.recentProjects.removeAll { $0.id == project.id }
            appState.recentProjects.insert(project, at: 0)
            recentProjects = appState.recentProjects
            selectedProject = project
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

        return FileManager.default.fileExists(atPath: url.path)
    }
}
