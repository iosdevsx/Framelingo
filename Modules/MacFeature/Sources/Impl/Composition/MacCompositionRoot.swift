import AppKit
import Application
import ApplicationImpl
import AppUpdate
import AppUpdateImpl
import Foundation
import MacFeature
import MediaImpl
import PlayerFeatureImpl
import Project
import ProjectImpl
import ProjectFeature
import SettingsImpl
import ShortsFeatureImpl
import SpeakerAnalysisImpl
import SpeechToTextImpl
import Subtitles
import SubtitlesImpl
import SubtitleEditorFeatureImpl
import TimelineImpl
import TimelineFeatureImpl
import TranslationImpl
import UniformTypeIdentifiers
import VideoRendering
import VideoRenderingImpl
import ExportFeatureImpl

@MainActor
enum MacCompositionRoot {
    static func makeDependencies() -> MacFeatureDependencies {
        let fileManager = FileManager.default
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
        let projectCatalog = ProjectAssembly.makeCatalog(
            repository: projectRepository,
            preparedMediaCleanup: PreparedMediaCleanup { mediaURL in
                try audioPreparationService.removePreparedAudio(for: mediaURL)
            }
        )
        projectCatalog.register(MacMockData.project)

        let appState = ApplicationAssembly.makeAppState(
            selectedProject: MacMockData.project,
            dependencies: AppStateDependencies(
                subtitleExportService: SubtitlesAssembly.makeExporter(),
                translationService: translationService,
                speakerDiarizationEngine: speakerDiarizationEngine,
                subtitleAlignmentEngine: subtitleAlignmentEngine,
                audioPreparationService: audioPreparationService,
                makeFFmpegService: makeFFmpegService,
                subtitleScriptGenerator: subtitleScriptGenerator,
                fileManager: fileManager,
                currentSettings: { settingsAccess.snapshot.settings },
                revealVideoExport: { url in
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                },
                copyText: { value in
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }
            )
        )
        let activeProjectExportSettings = AppStateActiveProjectExportSettingsAdapter(
            appState: appState,
            projectRepository: projectRepository,
            projectCatalog: projectCatalog
        )

        let projectPreparationWorkflow = ApplicationWorkflowAssembly.makeProjectPreparationWorkflow(
                mediaMetadataProvider: mediaMetadataProvider,
                waveformLoader: waveformLoader,
                makeFFmpegService: makeFFmpegService,
                fileManager: fileManager
            )
        let projectTranscriptionWorkflow = ApplicationWorkflowAssembly.makeProjectTranscriptionWorkflow(
                projectRepository: projectRepository,
                speechToTextProviderResolver: speechToTextProviderResolver,
                speakerDiarizationEngine: speakerDiarizationEngine,
                subtitleAlignmentEngine: subtitleAlignmentEngine,
                makeFFmpegService: makeFFmpegService,
                fileManager: fileManager
            )
        let projectTranslationWorkflow = ApplicationWorkflowAssembly.makeProjectTranslationWorkflow(
                projectRepository: projectRepository,
                translationService: translationService
            )
        let projectFeatureComponents = ProjectFeatureComponents(
            player: PlayerFeatureAssembly.makeFactory(),
            timeline: TimelineFeatureAssembly.makeFactory(),
            subtitleEditor: SubtitleEditorFeatureAssembly.makeFactory(),
            shorts: ShortsFeatureAssembly.makeFactory(),
            export: ExportFeatureAssembly.makeFactory(
                makeFFmpegService: { makeFFmpegService(settingsAccess.snapshot.settings) },
                subtitleScriptGenerator: subtitleScriptGenerator,
                mediaMetadataService: mediaMetadataProvider,
                fileManager: fileManager
            )
        )

        return MacFeatureDependencies(
            appState: appState,
            settingsAccess: settingsAccess,
            projectCatalog: projectCatalog,
            projectRepository: projectRepository,
            activeProjectExportSettings: activeProjectExportSettings,
            subtitleImporter: SubtitlesAssembly.makeImporter(),
            editTimelineService: TimelineAssembly.makeEditService(),
            projectPreparationWorkflow: projectPreparationWorkflow,
            projectTranscriptionWorkflow: projectTranscriptionWorkflow,
            projectTranslationWorkflow: projectTranslationWorkflow,
            pickSubtitleFile: pickSubtitleFile,
            mediaMetadataProvider: mediaMetadataProvider,
            subtitleScriptGenerator: subtitleScriptGenerator,
            makeFFmpegService: makeFFmpegService,
            projectFileService: projectFileService,
            projectFeatureComponents: projectFeatureComponents,
            whisperModelManager: SpeechToTextAssembly.makeWhisperModelManager(),
            parakeetModelManager: SpeechToTextAssembly.makeParakeetModelManager(),
            usesEmbeddedVideoRenderingBackend: VideoRenderingAssembly.usesEmbeddedBackend,
            fileManager: fileManager,
            mockProject: MacMockData.project,
            mockSubtitles: MacMockData.subtitles
        )
    }

    private static func pickSubtitleFile() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Import Subtitles"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = SubtitleFileFormat.allSupportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}
