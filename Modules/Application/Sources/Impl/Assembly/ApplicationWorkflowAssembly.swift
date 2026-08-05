import Application
import Foundation
import Media
import Project
import SpeakerAnalysis
import SpeechToText
import Translation

public enum ApplicationWorkflowAssembly {
    public static func makeProjectPreparationWorkflow(
        mediaMetadataProvider: any MediaMetadataProviding,
        waveformLoader: any WaveformLoading,
        makeFFmpegService: @escaping FFmpegServiceBuilder,
        fileManager: FileManager = .default,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) -> any ProjectPreparationWorkflow {
        DefaultProjectPreparationWorkflow(
            mediaMetadataProvider: mediaMetadataProvider,
            waveformLoader: waveformLoader,
            makeFFmpegService: makeFFmpegService,
            fileManager: fileManager,
            temporaryDirectory: temporaryDirectory
        )
    }

    public static func makeProjectTranscriptionWorkflow(
        projectRepository: any ProjectRepository,
        speechToTextProviderResolver: any SpeechToTextProviderResolving,
        speakerDiarizationEngine: any SpeakerDiarizationEngine,
        subtitleAlignmentEngine: any SubtitleAlignmentEngine,
        makeFFmpegService: @escaping FFmpegServiceBuilder,
        fileManager: FileManager = .default,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) -> any ProjectTranscriptionWorkflow {
        DefaultProjectTranscriptionWorkflow(
            projectRepository: projectRepository,
            speechToTextProviderResolver: speechToTextProviderResolver,
            speakerDiarizationEngine: speakerDiarizationEngine,
            subtitleAlignmentEngine: subtitleAlignmentEngine,
            makeFFmpegService: makeFFmpegService,
            fileManager: fileManager,
            temporaryDirectory: temporaryDirectory
        )
    }

    public static func makeProjectTranslationWorkflow(
        projectRepository: any ProjectRepository,
        translationService: any TranslationOrchestrating
    ) -> any ProjectTranslationWorkflow {
        DefaultProjectTranslationWorkflow(
            projectRepository: projectRepository,
            translationService: translationService
        )
    }
}
