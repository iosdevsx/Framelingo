import AppKit
import Application
import ApplicationImpl
import AppUpdate
import AppUpdateImpl
import Foundation
import MacFeature
import MediaImpl
import ProjectImpl
import SettingsImpl
import SpeakerAnalysisImpl
import SpeechToTextImpl
import Subtitles
import SubtitlesImpl
import TimelineImpl
import TranslationImpl
import UniformTypeIdentifiers
import VideoRendering
import VideoRenderingImpl

@MainActor
enum MacCompositionRoot {
    static func makeDependencies() -> MacFeatureDependencies {
        let fileManager = FileManager.default
        let settings = SettingsAssembly.loadSettings()
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

        let appState = ApplicationAssembly.makeAppState(
            recentProjects: [MacMockData.project],
            selectedProject: MacMockData.project,
            settings: settings,
            dependencies: AppStateDependencies(
                projectRepository: projectRepository,
                subtitleExportService: SubtitlesAssembly.makeExporter(),
                translationService: translationService,
                speakerDiarizationEngine: speakerDiarizationEngine,
                subtitleAlignmentEngine: subtitleAlignmentEngine,
                audioPreparationService: VideoRenderingAssembly.makeAudioPreparationService(
                    ffmpegService: ffmpegService
                ),
                makeFFmpegService: makeFFmpegService,
                subtitleScriptGenerator: subtitleScriptGenerator,
                fileManager: fileManager,
                saveSettings: { settings in
                    SettingsAssembly.saveSettings(settings)
                },
                revealVideoExport: { url in
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                },
                copyText: { value in
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }
            )
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

        return MacFeatureDependencies(
            appState: appState,
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
