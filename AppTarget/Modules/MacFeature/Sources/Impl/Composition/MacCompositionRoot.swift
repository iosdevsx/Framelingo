import AppUpdate
import AppUpdateImpl
import Foundation
import MacFeature
import MediaImpl
import PlayerFeatureImpl
import Project
import ProjectImpl
import ProjectFeature
import ProjectPreparation
import ProjectPreparationImpl
import TranscriptionPipeline
import TranscriptionPipelineImpl
import TranslationPipeline
import TranslationPipelineImpl
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
import VideoRendering
import VideoRenderingImpl
import VideoExport
import VideoExportImpl
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
        let outputRevealer = AppKitOutputRevealAdapter().port
        let diagnosticCopier = AppKitDiagnosticCopyAdapter().port

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
        let projectFeatureComponents = ProjectFeatureComponents(
            player: PlayerFeatureAssembly.makeFactory(),
            timeline: TimelineFeatureAssembly.makeFactory(),
            subtitleEditor: SubtitleEditorFeatureAssembly.makeFactory(),
            shorts: ShortsFeatureAssembly.makeFactory(),
            export: ExportFeatureAssembly.makeFactory(
                mediaMetadataService: mediaMetadataProvider,
                outputRevealer: outputRevealer,
                diagnosticCopier: diagnosticCopier
            )
        )

        return MacFeatureDependencies(
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

}
