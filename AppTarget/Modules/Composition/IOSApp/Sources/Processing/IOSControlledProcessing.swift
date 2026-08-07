import Combine
import Foundation
import Project
import ProjectPreparation
import ProjectSession
import SpeechToText
import Subtitles
import TranscriptionPipeline
import TranslationPipeline
import VideoExport

struct IOSControlledProcessingOptions: Sendable {
    let delay: Duration
    let preparationFailure: String?
    let transcriptionFailure: String?
    let translationFailure: String?

    static let success = IOSControlledProcessingOptions(
        delay: .milliseconds(40),
        preparationFailure: nil,
        transcriptionFailure: nil,
        translationFailure: nil
    )
}

enum IOSControlledProcessingComposition {
    @MainActor
    static func makeEffects(
        projectFileService: any ProjectFileServicing,
        options: IOSControlledProcessingOptions
    ) -> ProjectSessionEffectDependencies {
        ProjectSessionEffectDependencies(
            projectPreparer: IOSControlledProjectPreparer(options: options),
            preparationConfiguration: {
                ProjectPreparationConfiguration(ffmpegExecutablePath: "controlled-ios")
            },
            projectTranscriber: IOSControlledProjectTranscriber(options: options),
            transcriptionConfiguration: {
                TranscriptionPipelineConfiguration(
                    ffmpegExecutablePath: "controlled-ios",
                    speechToText: SpeechToTextProviderConfiguration(
                        providerName: SpeechToTextProviderName.mock
                    )
                )
            },
            projectTranslator: IOSControlledProjectTranslator(options: options),
            subtitleImporter: IOSUnavailableSubtitleImporter(),
            subtitleExporter: IOSUnavailableSubtitleExporter(),
            projectFileService: projectFileService,
            videoExportQueue: IOSNoopVideoExportQueue()
        )
    }
}

private struct IOSControlledProjectPreparer: ProjectPreparing {
    let options: IOSControlledProcessingOptions

    func prepare(
        _ request: ProjectPreparationRequest,
        events: @escaping ProjectPreparationEventHandler
    ) async throws -> ProjectPreparationOutput {
        try await Task.sleep(for: options.delay)
        try Task.checkCancellation()
        if let failure = options.preparationFailure {
            throw IOSControlledProcessingError.failed(failure)
        }
        await events(.progress(.init(
            phase: .readingDuration,
            fractionCompleted: 1,
            providerDetail: "Controlled iOS preparation"
        )))
        return ProjectPreparationOutput(
            project: request.project,
            waveformPeaks: [],
            videoSourceInfo: nil,
            outcome: .ready
        )
    }
}

private struct IOSControlledProjectTranscriber: TranscribingProject {
    let options: IOSControlledProcessingOptions

    func transcribe(
        _ request: TranscriptionPipelineRequest,
        events: @escaping TranscriptionPipelineEventHandler
    ) async throws -> TranscriptionPipelineOutput {
        await events(.progress(.init(
            phase: .transcribing,
            fractionCompleted: 0.25,
            providerDetail: "Controlled iOS transcription"
        )))
        try await Task.sleep(for: options.delay)
        try Task.checkCancellation()
        if let failure = options.transcriptionFailure {
            throw IOSControlledProcessingError.failed(failure)
        }

        var project = request.project
        if project.subtitles.isEmpty {
            let duration = max(project.mediaFile.durationMs ?? 8_000, 2_000)
            let midpoint = max(1_000, duration / 2)
            project.subtitles = [
                SubtitleSegment(
                    id: UUID(),
                    index: 1,
                    startMs: 0,
                    endMs: midpoint,
                    originalText: "Controlled iOS transcription",
                    translatedText: ""
                ),
                SubtitleSegment(
                    id: UUID(),
                    index: 2,
                    startMs: midpoint,
                    endMs: duration,
                    originalText: "Edit these subtitles in the shared workspace",
                    translatedText: ""
                ),
            ]
        }
        project.status = .ready
        await events(.projectChanged(project))
        await events(.progress(.init(
            phase: .transcribing,
            fractionCompleted: 1,
            providerDetail: "Controlled iOS transcription"
        )))
        return TranscriptionPipelineOutput(project: project, warning: nil)
    }
}

private struct IOSControlledProjectTranslator: TranslatingProject {
    let options: IOSControlledProcessingOptions

    func translate(
        _ request: TranslationPipelineRequest,
        events: @escaping TranslationPipelineEventHandler
    ) async throws -> TranslationPipelineOutput {
        var translating = request.project
        translating.status = .translating
        await events(.translating(translating))
        try await Task.sleep(for: options.delay)
        try Task.checkCancellation()
        if let failure = options.translationFailure {
            throw IOSControlledProcessingError.failed(failure)
        }

        var ready = request.project
        for index in ready.subtitles.indices {
            ready.subtitles[index].translatedText = "[Mock] " + ready.subtitles[index].originalText
        }
        ready.status = .ready
        await events(.ready(ready))
        return TranslationPipelineOutput(project: ready)
    }
}

private enum IOSControlledProcessingError: Error, LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}

private struct IOSUnavailableSubtitleImporter: SubtitleImporting {
    func importSubtitles(from fileURL: URL) async throws -> SubtitleImportPreview {
        throw IOSControlledProcessingError.failed(
            "Subtitle import is not included in the initial iOS composition."
        )
    }
}

private struct IOSUnavailableSubtitleExporter: SubtitleExportService {
    func export(
        request: SubtitleExportRequest,
        kind: SubtitleExportKind,
        destinationURL: URL
    ) async throws {
        throw IOSControlledProcessingError.failed(
            "Subtitle export is not included in the initial iOS composition."
        )
    }

    func exportSRT(
        request: SubtitleExportRequest,
        textMode: SubtitleTextMode,
        destinationURL: URL
    ) async throws {
        throw IOSControlledProcessingError.failed(
            "Subtitle export is not included in the initial iOS composition."
        )
    }
}

@MainActor
private final class IOSNoopVideoExportQueue: VideoExportQueue {
    private let subject = CurrentValueSubject<[VideoExportJob], Never>([])
    var jobs: [VideoExportJob] { [] }
    var jobSnapshots: AnyPublisher<[VideoExportJob], Never> {
        subject.eraseToAnyPublisher()
    }

    func enqueue(_ request: VideoExportRequest) {}
    func enqueue(_ batch: ShortsVideoExportBatchRequest) {}
    func removeFinishedJob(id: UUID) {}
}
