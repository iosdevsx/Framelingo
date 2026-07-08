import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var ffmpegVersion: String?
    @Published var ffmpegCheckMessage: String?
    @Published var isCheckingFFmpeg = false
    @Published var whisperInstallMessage: String?
    @Published var whisperInstallProgress: Double?
    @Published var isInstallingWhisper = false
    @Published var selectedProject: Project?

    private let appState: AppState
    private let whisperInstaller = WhisperInstaller()
    private var projectSaveTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
        settings = appState.settings
        selectedProject = appState.selectedProject
    }

    deinit {
        projectSaveTask?.cancel()
    }

    func save() {
        appState.settings = settings
    }

    var currentVideoExportSettings: VideoExportSettings {
        selectedProject?.videoExportSettings ?? VideoExportSettings()
    }

    var hasSelectedProject: Bool {
        selectedProject != nil
    }

    func updateVideoExportSettings(_ settings: VideoExportSettings) {
        guard var project = selectedProject else {
            return
        }

        project.videoExportSettings = settings
        project.updatedAt = Date()
        selectedProject = project
        appState.selectedProject = project
        if let index = appState.recentProjects.firstIndex(where: { $0.id == project.id }) {
            appState.recentProjects[index] = project
        }

        projectSaveTask?.cancel()
        let repository = appState.projectRepository
        projectSaveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
                try Task.checkCancellation()
                try await repository.saveProject(project)
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    var selectedWhisperModel: WhisperModel {
        get {
            WhisperModel(rawValue: settings.whisperModelName) ?? .base
        }
        set {
            settings.whisperModelName = newValue.rawValue
            save()
        }
    }

    var isVADModelInstalled: Bool {
        !settings.whisperVADModelPath.isEmpty
            && FileManager.default.fileExists(atPath: settings.whisperVADModelPath)
    }

    var isVADEnabled: Bool {
        get {
            settings.whisperVADEnabled
        }
        set {
            settings.whisperVADEnabled = newValue
            save()
        }
    }

    var whisperStatusText: String {
        if settings.speechToTextProviderName == SpeechToTextProviderName.localWhisper,
           !settings.whisperExecutablePath.isEmpty,
           !settings.whisperModelPath.isEmpty {
            return isVADModelInstalled
                ? "Local Whisper is configured. VAD model installed."
                : "Local Whisper is configured. VAD model not installed — reinstall to enable voice activity detection."
        }

        return "Local Whisper is not installed."
    }

    func installWhisper() async {
        guard !isInstallingWhisper else {
            return
        }

        isInstallingWhisper = true
        whisperInstallProgress = nil
        whisperInstallMessage = "Preparing Whisper..."
        defer {
            isInstallingWhisper = false
        }

        do {
            let model = selectedWhisperModel
            let installation = try await whisperInstaller.install(model: model) { stage, progress in
                await MainActor.run {
                    self.whisperInstallProgress = progress
                    let downloadName: String
                    switch stage {
                    case .transcriptionModel:
                        downloadName = "\(model.displayName) model"
                    case .vadModel:
                        downloadName = "voice detection (VAD) model"
                    }
                    if let progress {
                        self.whisperInstallMessage = "Downloading \(downloadName)... \(Int((progress * 100).rounded()))%"
                    } else {
                        self.whisperInstallMessage = "Downloading \(downloadName)..."
                    }
                }
            }

            settings.speechToTextProviderName = SpeechToTextProviderName.localWhisper
            settings.whisperExecutablePath = installation.executableURL.path
            settings.whisperModelName = installation.model.rawValue
            settings.whisperModelPath = installation.modelURL.path
            settings.whisperVADModelPath = installation.vadModelURL?.path ?? ""
            save()
            whisperInstallProgress = 1
            if let vadError = installation.vadModelErrorMessage {
                whisperInstallMessage = "Local Whisper installed and selected for speech-to-text. \(vadError)"
            } else {
                whisperInstallMessage = "Local Whisper installed and selected for speech-to-text."
            }
        } catch let error as LocalizedError {
            whisperInstallProgress = nil
            whisperInstallMessage = error.errorDescription ?? "Could not install Whisper."
        } catch {
            whisperInstallProgress = nil
            whisperInstallMessage = "Could not install Whisper."
        }
    }

    func checkFFmpeg() async {
        isCheckingFFmpeg = true
        defer {
            isCheckingFFmpeg = false
        }

        do {
            let service = FFmpegServiceFactory.makeDefaultService(settings: settings)
            let info = try await service.checkAvailability()
            if !FFmpegServiceFactory.usesEmbeddedFFmpegKit {
                settings.ffmpegPath = info.executableURL.path
            }
            appState.settings = settings
            ffmpegVersion = FFmpegServiceFactory.usesEmbeddedFFmpegKit
                ? info.version
                : "\(info.version) (\(info.executableURL.path))"
            ffmpegCheckMessage = nil
        } catch FFmpegServiceError.notFound {
            ffmpegVersion = nil
            ffmpegCheckMessage = "FFmpeg is not installed or path is incorrect."
        } catch FFmpegServiceError.launchFailed(_, let underlyingDescription) {
            ffmpegVersion = nil
            ffmpegCheckMessage = "FFmpeg could not be launched: \(underlyingDescription)"
        } catch let error as LocalizedError {
            ffmpegVersion = nil
            ffmpegCheckMessage = error.errorDescription ?? "Could not check FFmpeg."
        } catch {
            ffmpegVersion = nil
            ffmpegCheckMessage = "Could not check FFmpeg."
        }
    }

}
