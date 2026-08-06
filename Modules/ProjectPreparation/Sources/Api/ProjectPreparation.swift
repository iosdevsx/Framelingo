import Foundation
import Project
import VideoRendering

/// The only product setting needed to select the audio extraction backend.
public struct ProjectPreparationConfiguration: Equatable, Sendable {
    public let ffmpegExecutablePath: String

    public init(ffmpegExecutablePath: String) {
        self.ffmpegExecutablePath = ffmpegExecutablePath
    }
}

public typealias ProjectPreparationConfigurationProvider =
    @MainActor () -> ProjectPreparationConfiguration

public struct ProjectPreparationRequest {
    public let project: Project
    public let configuration: ProjectPreparationConfiguration

    public init(project: Project, configuration: ProjectPreparationConfiguration) {
        self.project = project
        self.configuration = configuration
    }
}

public enum ProjectPreparationPhase: Equatable, Sendable {
    case readingSourceMetadata
    case readingDuration
    case preparingWaveform
}

public struct ProjectPreparationProgress: Equatable, Sendable {
    public let phase: ProjectPreparationPhase
    public let fractionCompleted: Double?
    /// Diagnostic/provider detail. Presentation may choose whether to expose it.
    public let providerDetail: String?

    public init(
        phase: ProjectPreparationPhase,
        fractionCompleted: Double?,
        providerDetail: String? = nil
    ) {
        self.phase = phase
        self.fractionCompleted = fractionCompleted
        self.providerDetail = providerDetail
    }
}

public enum ProjectPreparationEvent {
    case progress(ProjectPreparationProgress)
    case projectChanged(Project)
}

public typealias ProjectPreparationEventHandler = (ProjectPreparationEvent) async -> Void

public enum ProjectPreparationDegradation: Equatable, Sendable {
    case waveformUnavailable
    case waveformUnavailableAndCleanupFailed(message: String)
}

public enum ProjectPreparationOutcome: Equatable, Sendable {
    case ready
    case degraded(ProjectPreparationDegradation)
}

public struct ProjectPreparationOutput {
    public let project: Project
    public let waveformPeaks: [Double]
    public let videoSourceInfo: VideoSourceInfo?
    public let outcome: ProjectPreparationOutcome

    public init(
        project: Project,
        waveformPeaks: [Double],
        videoSourceInfo: VideoSourceInfo?,
        outcome: ProjectPreparationOutcome
    ) {
        self.project = project
        self.waveformPeaks = waveformPeaks
        self.videoSourceInfo = videoSourceInfo
        self.outcome = outcome
    }
}

public enum ProjectPreparationError: Error, Equatable, Sendable {
    case temporaryAudioCleanupFailed(message: String)
    case cancellationAndCleanupFailed(message: String)
}

public protocol ProjectPreparing {
    func prepare(
        _ request: ProjectPreparationRequest,
        events: @escaping ProjectPreparationEventHandler
    ) async throws -> ProjectPreparationOutput
}
