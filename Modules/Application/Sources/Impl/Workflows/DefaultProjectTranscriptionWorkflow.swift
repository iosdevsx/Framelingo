import Application
import Foundation
import Project
import Settings
import SpeakerAnalysis
import SpeechToText
import Subtitles
import Timeline
import VideoRendering

final class DefaultProjectTranscriptionWorkflow: ProjectTranscriptionWorkflow {
    private let projectRepository: any ProjectRepository
    private let speechToTextProviderResolver: any SpeechToTextProviderResolving
    private let speakerDiarizationEngine: any SpeakerDiarizationEngine
    private let subtitleAlignmentEngine: any SubtitleAlignmentEngine
    private let makeFFmpegService: FFmpegServiceBuilder
    private let fileManager: FileManager
    private let temporaryDirectory: URL

    init(
        projectRepository: any ProjectRepository,
        speechToTextProviderResolver: any SpeechToTextProviderResolving,
        speakerDiarizationEngine: any SpeakerDiarizationEngine,
        subtitleAlignmentEngine: any SubtitleAlignmentEngine,
        makeFFmpegService: @escaping FFmpegServiceBuilder,
        fileManager: FileManager,
        temporaryDirectory: URL
    ) {
        self.projectRepository = projectRepository
        self.speechToTextProviderResolver = speechToTextProviderResolver
        self.speakerDiarizationEngine = speakerDiarizationEngine
        self.subtitleAlignmentEngine = subtitleAlignmentEngine
        self.makeFFmpegService = makeFFmpegService
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory
    }

    func transcribe(
        _ request: ProjectTranscriptionRequest,
        events: @escaping ProjectProcessingEventHandler
    ) async throws -> ProjectTranscriptionOutput {
        var project = request.project
        let audioURL = temporaryURL(projectID: project.id, prefix: "audio", extension: "wav")
        var extractedTemporaryURL = audioURL
        var transcriptionCompleted = false

        do {
            project.status = .extractingAudio
            try await publishAndSave(project, events: events)
            try Task.checkCancellation()

            let clips = try transcriptionClips(for: project)
            let extractedAudioURL = try await makeFFmpegService(request.settings).extractAudio(
                from: project.mediaFile.originalURL,
                to: audioURL,
                clips: clips
            )
            extractedTemporaryURL = extractedAudioURL
            try Task.checkCancellation()
            await events(.progress(value: 0.15, status: "Transcribing audio..."))

            project.status = .transcribing
            project.updatedAt = Date()
            try await publishAndSave(project, events: events)

            let provider = try speechToTextProviderResolver.resolve(
                configuration: speechToTextConfiguration(from: request.settings)
            )
            let result = try await provider.transcribe(
                TranscriptionInput(
                    audioURL: extractedAudioURL,
                    videoURL: project.mediaFile.originalURL,
                    sourceLanguage: project.sourceLanguage,
                    progressHandler: { progress, status in
                        await events(.progress(value: progress, status: status))
                    }
                )
            )
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

            return ProjectTranscriptionOutput(
                project: project,
                completionMessage: transcriptionCompletionMessage(
                    diarizationFailureMessage: diarizationOutcome.failureMessage
                )
            )
        } catch is CancellationError {
            do {
                try removeTemporaryFileIfPresent(at: extractedTemporaryURL)
            } catch {
                throw ProjectTranscriptionError.cancellationAndCleanupFailed(
                    localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                )
            }
            throw CancellationError()
        } catch {
            if transcriptionCompleted {
                throw ProjectTranscriptionError.temporaryFileCleanupFailed(
                    localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                )
            }

            let failure = transcriptionError(from: error)
            project.status = .failed(failure.errorDescription ?? "Transcription failed.")
            project.updatedAt = Date()

            do {
                try await publishAndSave(project, events: events)
            } catch {
                let persistence = localizedMessage(from: error, fallback: "Project save failed.")
                let operation = failure.errorDescription ?? "Transcription failed."
                let persistenceFailure = ProjectTranscriptionError.persistenceFailed(
                    operation: operation,
                    persistence: persistence
                )
                do {
                    try removeTemporaryFileIfPresent(at: extractedTemporaryURL)
                } catch {
                    throw ProjectTranscriptionError.operationAndCleanupFailed(
                        operation: persistenceFailure.errorDescription ?? operation,
                        cleanup: localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                    )
                }
                throw persistenceFailure
            }

            do {
                try removeTemporaryFileIfPresent(at: extractedTemporaryURL)
            } catch {
                throw ProjectTranscriptionError.operationAndCleanupFailed(
                    operation: failure.errorDescription ?? "Transcription failed.",
                    cleanup: localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
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

    private func performDiarizationAndAlignment(
        for project: Project,
        audioURL: URL,
        events: @escaping ProjectProcessingEventHandler
    ) async throws -> (project: Project, failureMessage: String?) {
        do {
            await events(.progress(value: 0.95, status: "Analyzing speakers..."))
            let speakerSegments = try await speakerDiarizationEngine.diarize(audioURL: audioURL)
            try Task.checkCancellation()

            await events(.progress(value: 0.99, status: "Aligning subtitles..."))
            let words = project.wordTimings.isEmpty
                ? syntheticWordTimings(from: project.subtitles)
                : project.wordTimings
            let alignedSubtitles = try await subtitleAlignmentEngine.align(
                words: words,
                existingCues: project.subtitles.map(subtitleAlignmentCue(from:)),
                speakerSegments: speakerSegments,
                options: SubtitleAlignmentOptions()
            )

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
        } catch let error as CancellationError {
            throw error
        } catch {
            return (project, localizedMessage(from: error, fallback: "Speaker analysis failed."))
        }
    }

    private func transcriptionClips(for project: Project) throws -> [ExportClipRange]? {
        do {
            return try ExportClipPlanResolver.clips(for: project)
        } catch ExportClipPlanError.emptyPlan {
            throw ProjectTranscriptionError.emptyEditTimeline
        }
    }

    private func transcriptionError(from error: Error) -> ProjectTranscriptionError {
        if let error = error as? ProjectTranscriptionError {
            return error
        }
        if case FFmpegServiceError.notFound = error {
            return .ffmpegNotFound
        }
        return .failed(localizedMessage(from: error, fallback: "Transcription failed."))
    }

    private func transcriptionCompletionMessage(diarizationFailureMessage: String?) -> String? {
        guard let diarizationFailureMessage else { return nil }
        let warning = "Transcription complete. Speaker analysis failed; subtitle timings were not refined."
        let detail = diarizationFailureMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? warning : "\(warning) \(detail)"
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

    private func speechToTextConfiguration(from settings: AppSettings) -> SpeechToTextProviderConfiguration {
        SpeechToTextProviderConfiguration(
            providerName: settings.speechToTextProviderName,
            whisperExecutableURL: fileURL(from: settings.whisperExecutablePath),
            whisperModelURL: fileURL(from: settings.whisperModelPath),
            whisperModelName: settings.whisperModelName,
            whisperVADEnabled: settings.whisperVADEnabled,
            whisperVADModelURL: fileURL(from: settings.whisperVADModelPath)
        )
    }

    private func fileURL(from path: String) -> URL? {
        let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    private func temporaryURL(projectID: UUID, prefix: String, extension: String) -> URL {
        temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            .appendingPathExtension(`extension`)
    }

    private func removeTemporaryFileIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
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
