import Foundation
import Project
import SpeakerAnalysis
import SpeechToText
import Subtitles
import TranscriptionPipeline
import VideoRendering

final class DefaultTranscriptionPipeline: TranscribingProject {
    private let projectRepository: any ProjectRepository
    private let speechToTextProviderResolver: any SpeechToTextProviderResolving
    private let speakerDiarizationEngine: any SpeakerDiarizationEngine
    private let subtitleAlignmentEngine: any SubtitleAlignmentEngine
    private let makeFFmpegService: TranscriptionPipelineFFmpegServiceBuilder
    private let fileSystem: TranscriptionPipelineFileSystem
    private let temporaryDirectory: URL

    init(
        projectRepository: any ProjectRepository,
        speechToTextProviderResolver: any SpeechToTextProviderResolving,
        speakerDiarizationEngine: any SpeakerDiarizationEngine,
        subtitleAlignmentEngine: any SubtitleAlignmentEngine,
        makeFFmpegService: @escaping TranscriptionPipelineFFmpegServiceBuilder,
        fileSystem: TranscriptionPipelineFileSystem,
        temporaryDirectory: URL
    ) {
        self.projectRepository = projectRepository
        self.speechToTextProviderResolver = speechToTextProviderResolver
        self.speakerDiarizationEngine = speakerDiarizationEngine
        self.subtitleAlignmentEngine = subtitleAlignmentEngine
        self.makeFFmpegService = makeFFmpegService
        self.fileSystem = fileSystem
        self.temporaryDirectory = temporaryDirectory
    }

    func transcribe(
        _ request: TranscriptionPipelineRequest,
        events: @escaping TranscriptionPipelineEventHandler
    ) async throws -> TranscriptionPipelineOutput {
        var project = request.project
        let audioURL = temporaryURL(projectID: project.id, prefix: "audio", extension: "wav")
        var extractedTemporaryURL = audioURL
        var transcriptionCompleted = false

        do {
            await events(.progress(TranscriptionPipelineProgress(
                phase: .extractingAudio,
                fractionCompleted: 0
            )))
            project.status = .extractingAudio
            try await publishAndSave(project, events: events)
            try Task.checkCancellation()

            let clips = try transcriptionClips(for: project)
            let extractedAudioURL: URL
            do {
                extractedAudioURL = try await makeFFmpegService(request.configuration).extractAudio(
                    from: project.mediaFile.originalURL,
                    to: audioURL,
                    clips: clips
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw renderingError(from: error)
            }
            extractedTemporaryURL = extractedAudioURL
            try Task.checkCancellation()
            await events(.progress(TranscriptionPipelineProgress(
                phase: .transcribing,
                fractionCompleted: 0.15
            )))

            project.status = .transcribing
            project.updatedAt = Date()
            try await publishAndSave(project, events: events)

            let provider: any SpeechToTextProvider
            do {
                provider = try speechToTextProviderResolver.resolve(
                    configuration: request.configuration.speechToText
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw providerError(from: error)
            }
            let result: TranscriptionResult
            do {
                result = try await provider.transcribe(
                    TranscriptionInput(
                        audioURL: extractedAudioURL,
                        videoURL: project.mediaFile.originalURL,
                        sourceLanguage: project.sourceLanguage,
                        progressHandler: { progress, detail in
                            await events(.progress(TranscriptionPipelineProgress(
                                phase: .transcribing,
                                fractionCompleted: progress,
                                providerDetail: detail
                            )))
                        }
                    )
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw providerError(from: error)
            }
            try Task.checkCancellation()

            project.subtitles = result.segments
            project.wordTimings = result.words
            if let detectedLanguage = result.detectedLanguage {
                project.sourceLanguage = detectedLanguage
            }
            if clips == nil, let durationMs = result.durationMs {
                project.mediaFile.durationMs = durationMs
            }

            let diarizationOutcome = try await performDiarizationAndAlignment(
                for: project,
                audioURL: extractedAudioURL,
                events: events
            )
            project = diarizationOutcome.project

            if let editedDurationMs = clips?.reduce(0, { $0 + $1.durationMs }) {
                project = projectByConstrainingTranscription(project, to: editedDurationMs)
            }

            project.status = .ready
            project.updatedAt = Date()
            try await publishAndSave(project, events: events)
            transcriptionCompleted = true
            try removeTemporaryFileIfPresent(at: extractedTemporaryURL)

            return TranscriptionPipelineOutput(
                project: project,
                warning: diarizationOutcome.warning
            )
        } catch is CancellationError {
            do {
                try removeTemporaryFileIfPresent(at: extractedTemporaryURL)
            } catch {
                throw TranscriptionPipelineError.cancellationAndCleanupFailed(
                    message: localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                )
            }
            throw CancellationError()
        } catch {
            if transcriptionCompleted {
                throw TranscriptionPipelineError.temporaryAudioCleanupFailed(
                    message: localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                )
            }

            let failure = transcriptionError(from: error)
            let operation = failure.errorDescription ?? "Transcription failed."
            project.status = .failed(operation)
            project.updatedAt = Date()

            do {
                try await publishAndSave(project, events: events)
            } catch {
                let persistence = localizedMessage(from: error, fallback: "Project save failed.")
                do {
                    try removeTemporaryFileIfPresent(at: extractedTemporaryURL)
                } catch {
                    throw TranscriptionPipelineError.persistenceAndCleanupFailed(
                        operation: operation,
                        persistence: persistence,
                        cleanup: localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                    )
                }
                throw TranscriptionPipelineError.persistenceFailed(
                    operation: operation,
                    persistence: persistence
                )
            }

            do {
                try removeTemporaryFileIfPresent(at: extractedTemporaryURL)
            } catch {
                throw TranscriptionPipelineError.operationAndCleanupFailed(
                    operation: operation,
                    cleanup: localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                )
            }
            throw failure
        }
    }

    private func publishAndSave(
        _ project: Project,
        events: @escaping TranscriptionPipelineEventHandler
    ) async throws {
        await events(.projectChanged(project))
        try await projectRepository.saveProject(project)
    }

    private func performDiarizationAndAlignment(
        for project: Project,
        audioURL: URL,
        events: @escaping TranscriptionPipelineEventHandler
    ) async throws -> (project: Project, warning: TranscriptionPipelineWarning?) {
        do {
            await events(.progress(TranscriptionPipelineProgress(
                phase: .analyzingSpeakers,
                fractionCompleted: 0.95
            )))
            let speakerSegments = try await speakerDiarizationEngine.diarize(audioURL: audioURL)
            try Task.checkCancellation()

            await events(.progress(TranscriptionPipelineProgress(
                phase: .aligningSubtitles,
                fractionCompleted: 0.99
            )))
            let words = project.wordTimings.isEmpty
                ? syntheticWordTimings(from: project.subtitles)
                : project.wordTimings
            let alignedSubtitles = try await subtitleAlignmentEngine.align(
                words: words,
                existingCues: project.subtitles.map(subtitleAlignmentCue(from:)),
                speakerSegments: speakerSegments,
                options: SubtitleAlignmentOptions()
            )
            try Task.checkCancellation()

            var alignedProject = project
            alignedProject.speakerSegments = speakerSegments
            alignedProject.speakerLabels = speakerLabels(
                for: speakerSegments,
                existingLabels: project.speakerLabels
            )
            alignedProject.subtitles = SubtitleTimingValidator.reindexed(
                alignedSubtitles.map(subtitleSegment(from:))
            )
            return (alignedProject, nil)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let detail = localizedMessage(from: error, fallback: "Speaker analysis failed.")
            return (project, .speakerAnalysisUnavailable(detail: detail))
        }
    }

    private func transcriptionClips(for project: Project) throws -> [ExportClipRange]? {
        do {
            return try ExportClipPlanResolver.clips(for: project)
        } catch ExportClipPlanError.emptyPlan {
            throw TranscriptionPipelineError.emptyEditTimeline
        }
    }

    private func renderingError(from error: Error) -> TranscriptionPipelineError {
        if case FFmpegServiceError.notFound = error {
            return .renderingServiceUnavailable
        }
        return .renderingFailed(message: localizedMessage(from: error, fallback: "Transcription failed."))
    }

    private func providerError(from error: Error) -> TranscriptionPipelineError {
        .providerFailed(message: localizedMessage(from: error, fallback: "Transcription failed."))
    }

    private func transcriptionError(from error: Error) -> TranscriptionPipelineError {
        if let error = error as? TranscriptionPipelineError {
            return error
        }
        return .operationFailed(message: localizedMessage(from: error, fallback: "Transcription failed."))
    }

    private func projectByConstrainingTranscription(_ project: Project, to durationMs: Int) -> Project {
        let durationSeconds = Double(durationMs) / 1_000
        var constrained = project
        constrained.subtitles = SubtitleTimingValidator.reindexed(
            project.subtitles.compactMap { segment in
                let startMs = max(0, segment.startMs)
                let endMs = min(durationMs, segment.endMs)
                guard startMs < durationMs, endMs > startMs else { return nil }
                var segment = segment
                segment.startMs = startMs
                segment.endMs = endMs
                return segment
            }
        )
        constrained.wordTimings = project.wordTimings.compactMap { word in
            let start = max(0, word.start)
            let end = min(durationSeconds, word.end)
            guard start < durationSeconds, end > start else { return nil }
            var word = word
            word.start = start
            word.end = end
            return word
        }
        constrained.speakerSegments = project.speakerSegments.compactMap { segment in
            let start = max(0, segment.start)
            let end = min(durationSeconds, segment.end)
            guard start < durationSeconds, end > start else { return nil }
            var segment = segment
            segment.start = start
            segment.end = end
            return segment
        }
        return constrained
    }

    private func subtitleAlignmentCue(from segment: SubtitleSegment) -> SubtitleAlignmentCue {
        SubtitleAlignmentCue(
            id: segment.id,
            index: segment.index,
            startMs: segment.startMs,
            endMs: segment.endMs,
            originalText: segment.originalText,
            translatedText: segment.translatedText,
            speakerId: segment.speakerId,
            confidence: segment.confidence,
            warnings: segment.warnings
        )
    }

    private func subtitleSegment(from cue: SubtitleAlignmentCue) -> SubtitleSegment {
        SubtitleSegment(
            id: cue.id,
            index: cue.index,
            startMs: cue.startMs,
            endMs: cue.endMs,
            originalText: cue.originalText,
            translatedText: cue.translatedText,
            speakerId: cue.speakerId,
            confidence: cue.confidence,
            warnings: cue.warnings
        )
    }

    private func speakerLabels(
        for speakerSegments: [SpeakerSegment],
        existingLabels: [SpeakerLabel]
    ) -> [SpeakerLabel] {
        let existing = Dictionary(uniqueKeysWithValues: existingLabels.map { ($0.id, $0.displayName) })
        return Set(speakerSegments.map(\.speakerId)).sorted().map { speakerID in
            SpeakerLabel(
                id: speakerID,
                displayName: existing[speakerID] ?? "Speaker \(speakerID + 1)"
            )
        }
    }

    private func syntheticWordTimings(from subtitles: [SubtitleSegment]) -> [WordTiming] {
        subtitles.flatMap { segment in
            let words = segment.originalText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard !words.isEmpty else { return [WordTiming]() }
            let start = Double(segment.startMs) / 1_000
            let end = Double(segment.endMs) / 1_000
            let duration = max(end - start, 0) / Double(words.count)
            return words.enumerated().map { index, word in
                WordTiming(
                    text: word,
                    start: start + Double(index) * duration,
                    end: start + Double(index + 1) * duration,
                    confidence: segment.confidence
                )
            }
        }
    }

    private func temporaryURL(projectID: UUID, prefix: String, extension: String) -> URL {
        temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            .appendingPathExtension(`extension`)
    }

    private func removeTemporaryFileIfPresent(at url: URL) throws {
        guard fileSystem.fileExists(url) else { return }
        try fileSystem.removeItem(url)
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
