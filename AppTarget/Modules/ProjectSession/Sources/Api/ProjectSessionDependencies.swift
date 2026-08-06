import Foundation
import Project
import ProjectPreparation
import Subtitles
import Timeline
import TranscriptionPipeline
import TranslationPipeline
import VideoExport

public struct ProjectSessionEffectDependencies {
    public let projectPreparer: any ProjectPreparing
    public let preparationConfiguration: ProjectPreparationConfigurationProvider
    public let projectTranscriber: any TranscribingProject
    public let transcriptionConfiguration: @MainActor () -> TranscriptionPipelineConfiguration
    public let projectTranslator: any TranslatingProject
    public let subtitleImporter: any SubtitleImporting
    public let subtitleExporter: any SubtitleExportService
    public let projectFileService: any ProjectFileServicing
    public let videoExportQueue: any VideoExportQueue

    public init(
        projectPreparer: any ProjectPreparing,
        preparationConfiguration: @escaping ProjectPreparationConfigurationProvider,
        projectTranscriber: any TranscribingProject,
        transcriptionConfiguration: @escaping @MainActor () -> TranscriptionPipelineConfiguration,
        projectTranslator: any TranslatingProject,
        subtitleImporter: any SubtitleImporting,
        subtitleExporter: any SubtitleExportService,
        projectFileService: any ProjectFileServicing,
        videoExportQueue: any VideoExportQueue
    ) {
        self.projectPreparer = projectPreparer
        self.preparationConfiguration = preparationConfiguration
        self.projectTranscriber = projectTranscriber
        self.transcriptionConfiguration = transcriptionConfiguration
        self.projectTranslator = projectTranslator
        self.subtitleImporter = subtitleImporter
        self.subtitleExporter = subtitleExporter
        self.projectFileService = projectFileService
        self.videoExportQueue = videoExportQueue
    }
}

public struct ProjectSessionDocumentChangeSink: Sendable {
    private let sendAction: @MainActor @Sendable (ProjectSessionDocumentChangeEvent) -> Void

    public init(send: @escaping @MainActor @Sendable (ProjectSessionDocumentChangeEvent) -> Void) {
        sendAction = send
    }

    @MainActor
    public func send(_ event: ProjectSessionDocumentChangeEvent) {
        sendAction(event)
    }

    public static let none = ProjectSessionDocumentChangeSink { _ in }
}

public struct ProjectSessionSleeper: Sendable {
    private let sleepAction: @MainActor @Sendable (Duration) async throws -> Void

    public init(sleep: @escaping @MainActor @Sendable (Duration) async throws -> Void) {
        sleepAction = sleep
    }

    @MainActor
    public func sleep(for duration: Duration) async throws {
        try await sleepAction(duration)
    }

    public static let continuous = ProjectSessionSleeper { duration in
        try await Task.sleep(for: duration)
    }
}

public struct ProjectSessionDependencies {
    public let repository: any ProjectRepository
    public let documentChangeSink: ProjectSessionDocumentChangeSink
    public let historyLimit: Int
    public let autosaveDelay: Duration
    public let sleeper: ProjectSessionSleeper
    public let now: @MainActor () -> Date
    public let editTimelineService: (any EditTimelineEditing)?
    public let effects: ProjectSessionEffectDependencies?

    public init(
        repository: any ProjectRepository,
        documentChangeSink: ProjectSessionDocumentChangeSink = .none,
        historyLimit: Int = 50,
        autosaveDelay: Duration = .milliseconds(500),
        sleeper: ProjectSessionSleeper = .continuous,
        now: @escaping @MainActor () -> Date = Date.init,
        editTimelineService: (any EditTimelineEditing)? = nil,
        effects: ProjectSessionEffectDependencies? = nil
    ) {
        self.repository = repository
        self.documentChangeSink = documentChangeSink
        self.historyLimit = max(historyLimit, 0)
        self.autosaveDelay = autosaveDelay
        self.sleeper = sleeper
        self.now = now
        self.editTimelineService = editTimelineService
        self.effects = effects
    }
}
