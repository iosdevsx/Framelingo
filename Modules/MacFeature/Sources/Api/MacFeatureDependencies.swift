import Application
import Foundation
import Media
import Project
import ProjectFeature
import Settings
import SpeechToText
import Subtitles
import Timeline
import VideoRendering

public struct MacFeatureDependencies {
    public var appState: AppState
    public var settingsAccess: SettingsAccess
    public var projectCatalog: any ProjectCatalogManaging
    public var projectRepository: any ProjectRepository
    public var activeProjectExportSettings: any ActiveProjectExportSettingsManaging
    public var subtitleImporter: any SubtitleImporting
    public var editTimelineService: any EditTimelineEditing
    public var projectPreparationWorkflow: any ProjectPreparationWorkflow
    public var projectTranscriptionWorkflow: any ProjectTranscriptionWorkflow
    public var projectTranslationWorkflow: any ProjectTranslationWorkflow
    public var pickSubtitleFile: @MainActor () async -> URL?
    public var mediaMetadataProvider: any MediaMetadataProviding
    public var subtitleScriptGenerator: any SubtitleScriptGenerating
    public var makeFFmpegService: FFmpegServiceBuilder
    public var projectFileService: any ProjectFileServicing
    public var projectFeatureComponents: ProjectFeatureComponents
    public var whisperModelManager: any WhisperModelManaging
    public var parakeetModelManager: any ParakeetModelManaging
    public var usesEmbeddedVideoRenderingBackend: Bool
    public var fileManager: FileManager
    public var mockProject: Project
    public var mockSubtitles: [SubtitleSegment]

    public init(
        appState: AppState,
        settingsAccess: SettingsAccess,
        projectCatalog: any ProjectCatalogManaging,
        projectRepository: any ProjectRepository,
        activeProjectExportSettings: any ActiveProjectExportSettingsManaging,
        subtitleImporter: any SubtitleImporting,
        editTimelineService: any EditTimelineEditing,
        projectPreparationWorkflow: any ProjectPreparationWorkflow,
        projectTranscriptionWorkflow: any ProjectTranscriptionWorkflow,
        projectTranslationWorkflow: any ProjectTranslationWorkflow,
        pickSubtitleFile: @escaping @MainActor () async -> URL?,
        mediaMetadataProvider: any MediaMetadataProviding,
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        makeFFmpegService: @escaping FFmpegServiceBuilder,
        projectFileService: any ProjectFileServicing,
        projectFeatureComponents: ProjectFeatureComponents,
        whisperModelManager: any WhisperModelManaging,
        parakeetModelManager: any ParakeetModelManaging,
        usesEmbeddedVideoRenderingBackend: Bool,
        fileManager: FileManager = .default,
        mockProject: Project,
        mockSubtitles: [SubtitleSegment]
    ) {
        self.appState = appState
        self.settingsAccess = settingsAccess
        self.projectCatalog = projectCatalog
        self.projectRepository = projectRepository
        self.activeProjectExportSettings = activeProjectExportSettings
        self.subtitleImporter = subtitleImporter
        self.editTimelineService = editTimelineService
        self.projectPreparationWorkflow = projectPreparationWorkflow
        self.projectTranscriptionWorkflow = projectTranscriptionWorkflow
        self.projectTranslationWorkflow = projectTranslationWorkflow
        self.pickSubtitleFile = pickSubtitleFile
        self.mediaMetadataProvider = mediaMetadataProvider
        self.subtitleScriptGenerator = subtitleScriptGenerator
        self.makeFFmpegService = makeFFmpegService
        self.projectFileService = projectFileService
        self.projectFeatureComponents = projectFeatureComponents
        self.whisperModelManager = whisperModelManager
        self.parakeetModelManager = parakeetModelManager
        self.usesEmbeddedVideoRenderingBackend = usesEmbeddedVideoRenderingBackend
        self.fileManager = fileManager
        self.mockProject = mockProject
        self.mockSubtitles = mockSubtitles
    }
}
