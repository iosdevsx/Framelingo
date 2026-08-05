import Application
import Foundation
import Project
import Translation

final class DefaultProjectTranslationWorkflow: ProjectTranslationWorkflow {
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
        _ request: ProjectTranslationRequest,
        events: @escaping ProjectProcessingEventHandler
    ) async throws -> ProjectTranslationOutput {
        guard !request.project.subtitles.isEmpty else {
            throw ProjectTranslationError.noSubtitles
        }

        var project = request.project
        do {
            project.status = .translating
            try await publishAndSave(project, events: events)
            try Task.checkCancellation()

            let result = try await translationService.translateSubtitles(
                SubtitleTranslationInput(
                    segments: project.subtitles,
                    sourceLanguage: project.sourceLanguage,
                    targetLanguage: project.targetLanguage,
                    style: .natural
                )
            )
            try Task.checkCancellation()

            guard result.segments.count == project.subtitles.count else {
                throw ProjectTranslationError.segmentCountMismatch
            }

            project.subtitles = project.subtitles.enumerated().map { index, segment in
                var segment = segment
                segment.translatedText = result.segments[index].translatedText
                return segment
            }
            project.status = .ready
            project.updatedAt = Date()
            try await publishAndSave(project, events: events)
            return ProjectTranslationOutput(project: project)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let failure = translationError(from: error)
            project.status = .failed(failure.errorDescription ?? "Translation failed.")
            project.updatedAt = Date()
            do {
                try await publishAndSave(project, events: events)
            } catch {
                throw ProjectTranslationError.persistenceFailed(
                    operation: failure.errorDescription ?? "Translation failed.",
                    persistence: localizedMessage(from: error, fallback: "Project save failed.")
                )
            }
            throw failure
        }
    }

    private func publishAndSave(
        _ project: Project,
        events: @escaping ProjectProcessingEventHandler
    ) async throws {
        await events(.projectChanged(project))
        try await projectRepository.saveProject(project)
    }

    private func translationError(from error: Error) -> ProjectTranslationError {
        if let error = error as? ProjectTranslationError { return error }
        return .failed(localizedMessage(from: error, fallback: "Translation failed."))
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
