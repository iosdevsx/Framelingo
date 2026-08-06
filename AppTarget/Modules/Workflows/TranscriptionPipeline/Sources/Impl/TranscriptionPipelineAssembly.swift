import Foundation
import Project
import SpeakerAnalysis
import SpeechToText
import TranscriptionPipeline
import VideoRendering

public typealias TranscriptionPipelineFFmpegServiceBuilder =
    (TranscriptionPipelineConfiguration) -> any FFmpegService

public struct TranscriptionPipelineFileSystem {
    let fileExists: (URL) -> Bool
    let removeItem: (URL) throws -> Void

    public init(
        fileExists: @escaping (URL) -> Bool,
        removeItem: @escaping (URL) throws -> Void
    ) {
        self.fileExists = fileExists
        self.removeItem = removeItem
    }

    public static func live(fileManager: FileManager = .default) -> Self {
        Self(
            fileExists: { fileManager.fileExists(atPath: $0.path) },
            removeItem: { try fileManager.removeItem(at: $0) }
        )
    }
}

public enum TranscriptionPipelineAssembly {
    @MainActor
    public static func makeActivityTracker() -> any TranscriptionActivityTracking {
        DefaultTranscriptionActivityTracker()
    }

    public static func makeTranscriber(
        projectRepository: any ProjectRepository,
        speechToTextProviderResolver: any SpeechToTextProviderResolving,
        speakerDiarizationEngine: any SpeakerDiarizationEngine,
        subtitleAlignmentEngine: any SubtitleAlignmentEngine,
        makeFFmpegService: @escaping TranscriptionPipelineFFmpegServiceBuilder,
        fileSystem: TranscriptionPipelineFileSystem = .live(),
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) -> any TranscribingProject {
        DefaultTranscriptionPipeline(
            projectRepository: projectRepository,
            speechToTextProviderResolver: speechToTextProviderResolver,
            speakerDiarizationEngine: speakerDiarizationEngine,
            subtitleAlignmentEngine: subtitleAlignmentEngine,
            makeFFmpegService: makeFFmpegService,
            fileSystem: fileSystem,
            temporaryDirectory: temporaryDirectory
        )
    }
}
