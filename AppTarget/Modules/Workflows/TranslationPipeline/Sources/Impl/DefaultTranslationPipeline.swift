import Foundation
import Project
import Translation
import TranslationPipeline

final class DefaultTranslationPipeline: TranslatingProject {
    private let projectRepository: any ProjectRepository
    private let translationService: any TranslationOrchestrating

    init(
        projectRepository: any ProjectRepository,
        translationService: any TranslationOrchestrating
    ) {
        self.projectRepository = projectRepository
        self.translationService = translationService
    }

    func translate(
        _ request: TranslationPipelineRequest,
        events: @escaping TranslationPipelineEventHandler
    ) async throws -> TranslationPipelineOutput {
        guard !request.project.subtitles.isEmpty else {
            throw TranslationPipelineError.noSubtitles
        }

        var project = request.project
        do {
            project.status = .translating
            try await publishAndSave(.translating(project), events: events)
            try Task.checkCancellation()

            let result: SubtitleTranslationResult
            do {
                result = try await translationService.translateSubtitles(
                    SubtitleTranslationInput(
                        segments: project.subtitles,
                        sourceLanguage: project.sourceLanguage,
                        targetLanguage: project.targetLanguage,
                        style: .natural
                    )
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw TranslationPipelineError.providerFailed(
                    message: localizedMessage(from: error, fallback: "Translation failed.")
                )
            }
            try Task.checkCancellation()

            guard result.segments.count == project.subtitles.count else {
                throw TranslationPipelineError.segmentCountMismatch
            }

            project.subtitles = project.subtitles.enumerated().map { index, segment in
                var updatedSegment = segment
                updatedSegment.translatedText = result.segments[index].translatedText
                return updatedSegment
            }
            project.status = .ready
            project.updatedAt = Date()
            try await publishAndSave(.ready(project), events: events)
            return TranslationPipelineOutput(project: project)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let failure = translationError(from: error)
            let operation = failure.errorDescription ?? "Translation failed."
            project.status = .failed(operation)
            project.updatedAt = Date()
            do {
                try await publishAndSave(.failed(project), events: events)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw TranslationPipelineError.persistenceFailed(
                    operation: operation,
                    persistence: localizedMessage(from: error, fallback: "Project save failed.")
                )
            }
            throw failure
        }
    }

    private func publishAndSave(
        _ event: TranslationPipelineEvent,
        events: @escaping TranslationPipelineEventHandler
    ) async throws {
        await events(event)
        try await projectRepository.saveProject(event.project)
    }

    private func translationError(from error: Error) -> TranslationPipelineError {
        if let error = error as? TranslationPipelineError {
            return error
        }
        return .operationFailed(
            message: localizedMessage(from: error, fallback: "Translation failed.")
        )
    }

    private func localizedMessage(from error: Error, fallback: String) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return description
        }
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? fallback : description
    }
}
