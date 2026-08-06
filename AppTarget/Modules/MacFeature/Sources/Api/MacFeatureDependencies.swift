import Application
import Foundation
import Media
import Project
import ProjectFeature
import ProjectPreparation
import TranscriptionPipeline
import TranslationPipeline
import Settings
import SpeechToText
import Subtitles
import Timeline
import VideoRendering
import VideoExport

public typealias FFmpegServiceBuilder = (AppSettings) -> any FFmpegService

public struct MacFeatureDependencies {
    public var appState: AppState
    public var videoExportQueue: any VideoExportQueue
    public var settingsAccess: SettingsAccess
    public var projectCatalog: any ProjectCatalogManaging
    public var projectRepository: any ProjectRepository
    public var preparedMediaCleanup: PreparedMediaCleanup
    public var subtitleImporter: any SubtitleImporting
    public var editTimelineService: any EditTimelineEditing
    public var projectPreparer: any ProjectPreparing
    public var projectPreparationConfiguration: ProjectPreparationConfigurationProvider
    public var projectTranscriber: any TranscribingProject
    public var projectTranslator: any TranslatingProject
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
        videoExportQueue: any VideoExportQueue,
        settingsAccess: SettingsAccess,
        projectCatalog: any ProjectCatalogManaging,
        projectRepository: any ProjectRepository,
        preparedMediaCleanup: PreparedMediaCleanup,
        subtitleImporter: any SubtitleImporting,
        editTimelineService: any EditTimelineEditing,
        projectPreparer: any ProjectPreparing,
        projectPreparationConfiguration: @escaping ProjectPreparationConfigurationProvider,
        projectTranscriber: any TranscribingProject,
        projectTranslator: any TranslatingProject,
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
        self.videoExportQueue = videoExportQueue
        self.settingsAccess = settingsAccess
        self.projectCatalog = projectCatalog
        self.projectRepository = projectRepository
        self.preparedMediaCleanup = preparedMediaCleanup
        self.subtitleImporter = subtitleImporter
        self.editTimelineService = editTimelineService
        self.projectPreparer = projectPreparer
        self.projectPreparationConfiguration = projectPreparationConfiguration
        self.projectTranscriber = projectTranscriber
        self.projectTranslator = projectTranslator
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
