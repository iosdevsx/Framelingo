import AppUpdate
import AppUpdateImpl
import ExportFeature
import ExportFeatureImpl
import Foundation
import HomeFeature
import HomeFeatureImpl
import MediaImpl
import PlayerFeatureImpl
import Project
import ProjectFeature
import ProjectFeatureImpl
import ProjectImpl
import ProjectPreparation
import ProjectPreparationImpl
import ProjectSession
import ProjectSessionImpl
import SettingsFeatureImpl
import SettingsImpl
import ShortsFeatureImpl
import SpeakerAnalysisImpl
import SpeechToText
import SpeechToTextImpl
import Subtitles
import SubtitlesImpl
import SubtitleEditorFeature
import SubtitleEditorFeatureImpl
import SwiftUI
import TimelineImpl
import TimelineFeatureImpl
import TranscriptionPipeline
import TranscriptionPipelineImpl
import TranslationImpl
import TranslationPipelineImpl
import VideoExportImpl
import VideoRendering
import VideoRenderingImpl

struct MacAppPlatformAdapters {
    let subtitleDocumentPicker: SubtitleDocumentPicker
    let outputRevealer: ExportOutputRevealing
    let diagnosticCopier: ExportDiagnosticCopying

    @MainActor
    static var live: Self {
        Self(
            subtitleDocumentPicker: AppKitSubtitleDocumentPickerAdapter().port,
            outputRevealer: AppKitOutputRevealAdapter().port,
            diagnosticCopier: AppKitDiagnosticCopyAdapter().port
        )
    }
}

@MainActor
enum MacAppComposition {
    static func makeProductionRootView() -> AnyView {
        AnyView(MainNavigationView(graph: makeNavigationGraph(
            infrastructure: makeInfrastructure(),
            platform: .live
        )))
    }

    static func makeUpdateChecker(startingUpdater: Bool) -> any AppUpdateChecking {
        AppUpdateAssembly.makeChecker(startingUpdater: startingUpdater)
    }

    static func makeNavigationGraph(
        infrastructure: MacAppInfrastructure,
        platform: MacAppPlatformAdapters
    ) -> MacAppNavigationGraph {
        let session = makeProjectSession(infrastructure: infrastructure)
        let runtime = MacAppWorkspaceRuntime(
            session: session,
            initialProject: infrastructure.mockProject,
            preparedMediaCleanup: infrastructure.preparedMediaCleanup,
            projectCatalog: infrastructure.projectCatalog
        )
        let activeProjectExportSettings = SessionActiveProjectExportSettingsAdapter(
            session: session
        )
        let projectComponents = makeProjectComponents(
            infrastructure: infrastructure,
            platform: platform
        )
        let activitySource = CapabilityActivitySourceAdapter(
            session: session,
            videoExportQueue: infrastructure.videoExportQueue
        ).source
        let activityOverlay = ExportFeatureAssembly.makeActivityOverlay(
            source: activitySource,
            outputRevealer: platform.outputRevealer,
            diagnosticCopier: platform.diagnosticCopier
        )

        let screens = MacAppScreenFactories(
            makeHome: {
                AnyView(HomeFeatureAssembly.makeView(
                    projectCatalog: infrastructure.projectCatalog,
                    projectRepository: infrastructure.projectRepository,
                    projectFileService: infrastructure.projectFileService,
                    mediaMetadataService: infrastructure.mediaMetadataProvider,
                    fileManager: infrastructure.fileManager,
                    mockProject: infrastructure.mockProject,
                    mockSubtitles: infrastructure.mockSubtitles,
                    projectOpening: HomeProjectOpening(open: runtime.open)
                ))
            },
            makeProject: { projectMode in
                AnyView(ProjectFeatureAssembly.makeView(
                    dependencies: ProjectFeatureDependencies(
                        session: session,
                        subtitleDocumentPicker: platform.subtitleDocumentPicker
                    ),
                    projectMode: projectMode,
                    components: projectComponents
                ))
            },
            makeSettings: {
                AnyView(SettingsFeatureAssembly.makeView(
                    settingsAccess: infrastructure.settingsAccess,
                    activeProjectExportSettings: activeProjectExportSettings,
                    whisperInstaller: infrastructure.whisperModelManager,
                    parakeetModelStore: infrastructure.parakeetModelManager,
                    usesEmbeddedVideoRenderingBackend: infrastructure.usesEmbeddedVideoRenderingBackend,
                    makeFFmpegService: infrastructure.makeFFmpegService,
                    fileManager: infrastructure.fileManager
                ))
            },
            activityOverlay: activityOverlay
        )
        return MacAppNavigationGraph(runtime: runtime, screens: screens)
    }

    static func makeInfrastructure(fileManager: FileManager = .default) -> MacAppInfrastructure {
        let settingsManager = SettingsAssembly.makeManager()
        let settingsAccess = settingsManager.access
        let settings = settingsAccess.snapshot.settings
        let makeFFmpegService: FFmpegServiceBuilder = { settings in
            VideoRenderingAssembly.makeDefaultService(
                preferredExecutableURL: URL(fileURLWithPath: settings.ffmpegPath)
            )
        }
        let ffmpegService = makeFFmpegService(settings)
        let subtitleParser = SubtitlesAssembly.makeParser()
        let subtitleExporter = SubtitlesAssembly.makeExporter()
        let subtitleScriptGenerator = VideoRenderingAssembly.makeSubtitleScriptGenerator()
        let projectRepository = ProjectAssembly.makeRepository(fileManager: fileManager)
        let projectFileService = ProjectAssembly.makeFileService()
        let translationService = TranslationAssembly.makeMockService()
        let speakerDiarizationEngine = SpeakerAnalysisAssembly.makeFluidAudioDiarizationEngine()
        let subtitleAlignmentEngine = SpeakerAnalysisAssembly.makeWordLevelAlignmentEngine()
        let mediaMetadataProvider = MediaAssembly.makeMetadataProvider()
        let waveformLoader = MediaAssembly.makeWaveformLoader()
        let speechToTextProviderResolver = SpeechToTextAssembly.makeProviderResolver(
            subtitleParser: subtitleParser
        )
        let audioPreparationService = VideoRenderingAssembly.makeAudioPreparationService(
            ffmpegService: ffmpegService
        )
        let preparedMediaCleanup = PreparedMediaCleanup { mediaURL in
            try audioPreparationService.removePreparedAudio(for: mediaURL)
        }
        let projectCatalog = ProjectAssembly.makeCatalog(
            repository: projectRepository,
            preparedMediaCleanup: preparedMediaCleanup
        )
        projectCatalog.register(MacMockData.project)
        let videoExportQueue = VideoExportAssembly.makeQueue(
            makeFFmpegService: { makeFFmpegService(settingsAccess.snapshot.settings) },
            subtitleScriptGenerator: subtitleScriptGenerator,
            subtitleExportService: subtitleExporter,
            fileManager: fileManager
        )
        let projectPreparer = ProjectPreparationAssembly.makeProjectPreparer(
            mediaMetadataProvider: mediaMetadataProvider,
            waveformLoader: waveformLoader,
            makeFFmpegService: { configuration in
                VideoRenderingAssembly.makeDefaultService(
                    preferredExecutableURL: URL(fileURLWithPath: configuration.ffmpegExecutablePath)
                )
            },
            fileSystem: .live(fileManager: fileManager)
        )
        let projectTranscriber = TranscriptionPipelineAssembly.makeTranscriber(
            projectRepository: projectRepository,
            speechToTextProviderResolver: speechToTextProviderResolver,
            speakerDiarizationEngine: speakerDiarizationEngine,
            subtitleAlignmentEngine: subtitleAlignmentEngine,
            makeFFmpegService: { configuration in
                VideoRenderingAssembly.makeDefaultService(
                    preferredExecutableURL: URL(fileURLWithPath: configuration.ffmpegExecutablePath)
                )
            },
            fileSystem: .live(fileManager: fileManager)
        )
        let projectTranslator = TranslationPipelineAssembly.makeTranslator(
            projectRepository: projectRepository,
            translationService: translationService
        )

        return MacAppInfrastructure(
            videoExportQueue: videoExportQueue,
            settingsAccess: settingsAccess,
            projectCatalog: projectCatalog,
            projectRepository: projectRepository,
            preparedMediaCleanup: preparedMediaCleanup,
            subtitleImporter: SubtitlesAssembly.makeImporter(),
            subtitleExportService: subtitleExporter,
            editTimelineService: TimelineAssembly.makeEditService(),
            projectPreparer: projectPreparer,
            projectPreparationConfiguration: {
                ProjectPreparationConfiguration(
                    ffmpegExecutablePath: settingsAccess.snapshot.settings.ffmpegPath
                )
            },
            projectTranscriber: projectTranscriber,
            projectTranslator: projectTranslator,
            mediaMetadataProvider: mediaMetadataProvider,
            makeFFmpegService: makeFFmpegService,
            projectFileService: projectFileService,
            whisperModelManager: SpeechToTextAssembly.makeWhisperModelManager(),
            parakeetModelManager: SpeechToTextAssembly.makeParakeetModelManager(),
            usesEmbeddedVideoRenderingBackend: VideoRenderingAssembly.usesEmbeddedBackend,
            fileManager: fileManager,
            mockProject: MacMockData.project,
            mockSubtitles: MacMockData.subtitles
        )
    }

    private static func makeProjectSession(
        infrastructure: MacAppInfrastructure
    ) -> DefaultProjectSession {
        DefaultProjectSession(dependencies: ProjectSessionDependencies(
            repository: infrastructure.projectRepository,
            historyLimit: 200,
            editTimelineService: infrastructure.editTimelineService,
            effects: ProjectSessionEffectDependencies(
                projectPreparer: infrastructure.projectPreparer,
                preparationConfiguration: infrastructure.projectPreparationConfiguration,
                projectTranscriber: infrastructure.projectTranscriber,
                transcriptionConfiguration: {
                    let settings = infrastructure.settingsAccess.snapshot.settings
                    return TranscriptionPipelineConfiguration(
                        ffmpegExecutablePath: settings.ffmpegPath,
                        speechToText: SpeechToTextProviderConfiguration(
                            providerName: settings.speechToTextProviderName,
                            whisperExecutableURL: fileURL(from: settings.whisperExecutablePath),
                            whisperModelURL: fileURL(from: settings.whisperModelPath),
                            whisperModelName: settings.whisperModelName,
                            whisperVADEnabled: settings.whisperVADEnabled,
                            whisperVADModelURL: fileURL(from: settings.whisperVADModelPath)
                        )
                    )
                },
                projectTranslator: infrastructure.projectTranslator,
                subtitleImporter: infrastructure.subtitleImporter,
                subtitleExporter: infrastructure.subtitleExportService,
                projectFileService: infrastructure.projectFileService,
                videoExportQueue: infrastructure.videoExportQueue
            )
        ))
    }

    static func makeProjectComponents(
        infrastructure: MacAppInfrastructure,
        platform: MacAppPlatformAdapters
    ) -> ProjectFeatureComponents {
        ProjectFeatureComponents(
            player: PlayerFeatureAssembly.makeFactory(),
            timeline: TimelineFeatureAssembly.makeFactory(),
            subtitleEditor: SubtitleEditorFeatureAssembly.makeFactory(),
            shorts: ShortsFeatureAssembly.makeFactory(),
            export: ExportFeatureAssembly.makeFactory(
                mediaMetadataService: infrastructure.mediaMetadataProvider,
                outputRevealer: platform.outputRevealer,
                diagnosticCopier: platform.diagnosticCopier
            )
        )
    }

    private static func fileURL(from path: String) -> URL? {
        let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }
}
