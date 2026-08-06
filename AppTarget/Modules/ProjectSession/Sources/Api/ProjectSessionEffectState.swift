import Foundation
import ProjectPreparation
import Subtitles
import TranscriptionPipeline
import TranslationPipeline
import VideoRendering

public enum ProjectSessionEffectKind: Equatable, Sendable {
    case preparation
    case transcription
    case translation
    case subtitleImport
    case subtitleExport
    case projectExport
    case videoExport
    case shortsExport
}

public enum ProjectSessionEffectFailureReason: Equatable, Sendable {
    case capabilityUnavailable
    case noActiveProject
    case noSubtitles
    case invalidInput
    case operationFailed
}

public struct ProjectSessionEffectFailure: Error, Equatable, Sendable {
    public let kind: ProjectSessionEffectKind
    public let reason: ProjectSessionEffectFailureReason
    public let diagnostic: String?

    public init(
        kind: ProjectSessionEffectKind,
        reason: ProjectSessionEffectFailureReason,
        diagnostic: String? = nil
    ) {
        self.kind = kind
        self.reason = reason
        self.diagnostic = diagnostic
    }
}

public enum ProjectSessionPreparationState: Equatable {
    case idle
    case running(ProjectPreparationProgress?)
    case completed(ProjectPreparationOutcome)
    case failed(ProjectSessionEffectFailure)
}

public enum ProjectSessionTranscriptionState: Equatable {
    case idle
    case running(TranscriptionPipelineProgress?)
    case completed(TranscriptionPipelineWarning?)
    case failed(ProjectSessionEffectFailure)
}

public enum ProjectSessionTranslationState: Equatable {
    case idle
    case running
    case completed
    case failed(ProjectSessionEffectFailure)
}

public enum ProjectSessionImportState: Equatable {
    case idle
    case loading
    case preview(SubtitleImportPreview)
    case failed(ProjectSessionEffectFailure)
}

public enum ProjectSessionExportState: Equatable {
    case idle
    case running(ProjectSessionEffectKind)
    case completed(ProjectSessionEffectKind, URL)
    case queued(ProjectSessionEffectKind, count: Int)
    case failed(ProjectSessionEffectFailure)
}

public struct ProjectSessionDerivedMediaState: Equatable {
    public let projectID: UUID?
    public let waveformPeaks: [Double]
    public let videoSourceInfo: VideoSourceInfo?

    public init(
        projectID: UUID? = nil,
        waveformPeaks: [Double] = [],
        videoSourceInfo: VideoSourceInfo? = nil
    ) {
        self.projectID = projectID
        self.waveformPeaks = waveformPeaks
        self.videoSourceInfo = videoSourceInfo
    }

    public static var empty: Self { Self() }
}

public struct ProjectSessionEffectsState: Equatable {
    public let preparation: ProjectSessionPreparationState
    public let transcription: ProjectSessionTranscriptionState
    public let translation: ProjectSessionTranslationState
    public let subtitleImport: ProjectSessionImportState
    public let export: ProjectSessionExportState
    public let derivedMedia: ProjectSessionDerivedMediaState

    public init(
        preparation: ProjectSessionPreparationState = .idle,
        transcription: ProjectSessionTranscriptionState = .idle,
        translation: ProjectSessionTranslationState = .idle,
        subtitleImport: ProjectSessionImportState = .idle,
        export: ProjectSessionExportState = .idle,
        derivedMedia: ProjectSessionDerivedMediaState = .empty
    ) {
        self.preparation = preparation
        self.transcription = transcription
        self.translation = translation
        self.subtitleImport = subtitleImport
        self.export = export
        self.derivedMedia = derivedMedia
    }

    public static var empty: Self { Self() }
}
