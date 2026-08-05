import Application
import Foundation
import Project
import SpeechToText
import Subtitles

public struct MacFeatureDependencies {
    public var appState: AppState
    public var projectViewModelDependencies: ProjectViewModelDependencies
    public var projectFileService: any ProjectFileServicing
    public var whisperModelManager: any WhisperModelManaging
    public var parakeetModelManager: any ParakeetModelManaging
    public var usesEmbeddedVideoRenderingBackend: Bool
    public var fileManager: FileManager
    public var mockProject: Project
    public var mockSubtitles: [SubtitleSegment]

    public init(
        appState: AppState,
        projectViewModelDependencies: ProjectViewModelDependencies,
        projectFileService: any ProjectFileServicing,
        whisperModelManager: any WhisperModelManaging,
        parakeetModelManager: any ParakeetModelManaging,
        usesEmbeddedVideoRenderingBackend: Bool,
        fileManager: FileManager = .default,
        mockProject: Project,
        mockSubtitles: [SubtitleSegment]
    ) {
        self.appState = appState
        self.projectViewModelDependencies = projectViewModelDependencies
        self.projectFileService = projectFileService
        self.whisperModelManager = whisperModelManager
        self.parakeetModelManager = parakeetModelManager
        self.usesEmbeddedVideoRenderingBackend = usesEmbeddedVideoRenderingBackend
        self.fileManager = fileManager
        self.mockProject = mockProject
        self.mockSubtitles = mockSubtitles
    }
}
