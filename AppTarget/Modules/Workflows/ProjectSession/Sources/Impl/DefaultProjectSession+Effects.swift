import Foundation
import Project
import ProjectPreparation
import ProjectSession
import Shorts
import Subtitles
import TranscriptionPipeline
import TranslationPipeline
import VideoExport
import VideoRendering

@MainActor
extension DefaultProjectSession {
    public func prepare() async {
        guard let project else {
            updateEffects(preparation: .failed(failure(.preparation, .noActiveProject)))
            return
        }
        guard let dependencies = effectDependencies else {
            updateEffects(preparation: .failed(failure(.preparation, .capabilityUnavailable)))
            return
        }

        let token = nextPreparationGeneration()
        let projectID = project.id
        updateEffects(
            preparation: .running(nil),
            derivedMedia: .init(projectID: projectID)
        )
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runPreparation(
                project: project,
                projectID: projectID,
                token: token,
                dependencies: dependencies
            )
        }
        setPreparationTask(task)
        await task.value
    }

    public func transcribe() async {
        guard let project else {
            updateEffects(transcription: .failed(failure(.transcription, .noActiveProject)))
            return
        }
        guard let dependencies = effectDependencies else {
            updateEffects(transcription: .failed(failure(.transcription, .capabilityUnavailable)))
            return
        }

        cancelPendingAutosaveForReplacingEffect()
        let token = nextTranscriptionGeneration()
        let projectID = project.id
        updateEffects(transcription: .running(nil))
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runTranscription(
                project: project,
                projectID: projectID,
                token: token,
                dependencies: dependencies
            )
        }
        setTranscriptionTask(task)
        await task.value
    }

    public func clearTranscriptionState() {
        guard case .running = effectsState.transcription else {
            updateEffects(transcription: .idle)
            return
        }
    }

    public func translate() async {
        guard let project else {
            updateEffects(translation: .failed(failure(.translation, .noActiveProject)))
            return
        }
        guard !project.subtitles.isEmpty else {
            updateEffects(translation: .failed(failure(.translation, .noSubtitles)))
            return
        }
        guard let dependencies = effectDependencies else {
            updateEffects(translation: .failed(failure(.translation, .capabilityUnavailable)))
            return
        }

        cancelPendingAutosaveForReplacingEffect()
        let token = nextTranslationGeneration()
        let projectID = project.id
        updateEffects(translation: .running)
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runTranslation(
                project: project,
                projectID: projectID,
                token: token,
                dependencies: dependencies
            )
        }
        setTranslationTask(task)
        await task.value
    }

    public func previewSubtitleImport(from url: URL) async {
        guard let project else {
            updateEffects(subtitleImport: .failed(failure(.subtitleImport, .noActiveProject)))
            return
        }
        guard let dependencies = effectDependencies else {
            updateEffects(subtitleImport: .failed(failure(.subtitleImport, .capabilityUnavailable)))
            return
        }

        let token = nextImportGeneration()
        let projectID = project.id
        updateEffects(subtitleImport: .loading)
        let task = Task { [weak self] in
            do {
                let preview = try await dependencies.subtitleImporter.importSubtitles(from: url)
                guard let self, self.matches(projectID: projectID, importing: token) else { return }
                self.updateEffects(subtitleImport: .preview(preview))
                self.setImportTask(nil)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.matches(projectID: projectID, importing: token) else { return }
                self.updateEffects(subtitleImport: .failed(self.failure(
                    .subtitleImport,
                    .operationFailed,
                    error: error
                )))
                self.setImportTask(nil)
            }
        }
        setImportTask(task)
        await task.value
    }

    public func clearSubtitleImportPreview() {
        _ = nextImportGeneration()
        setImportTask(nil)
        updateEffects(subtitleImport: .idle)
    }

    public func applySubtitleImport(
        _ preview: SubtitleImportPreview,
        mode: SubtitleImportMode,
        destination: SubtitleImportDestination
    ) -> ProjectSessionEditResult {
        guard var candidate = project else {
            updateEffects(subtitleImport: .failed(failure(.subtitleImport, .noActiveProject)))
            return .unchanged
        }
        candidate.subtitles = SubtitleImportMergePolicy().merge(
            current: candidate.subtitles,
            imported: preview.segments,
            mode: mode,
            destination: destination
        )
        let selectedID = candidate.subtitles.first?.id
        let selection = selectedID.map {
            ProjectSessionCueSelectionState(primaryCueID: $0, selectedCueIDs: [$0], anchorCueID: $0)
        } ?? .empty
        let didChange = install(
            candidate: candidate,
            interaction: ProjectSessionInteractionState(
                cueSelection: selection,
                playback: interactionState.playback,
                timeline: interactionState.timeline,
                shorts: interactionState.shorts
            )
        )
        updateEffects(subtitleImport: .idle)
        return ProjectSessionEditResult(didChange: didChange, selectedID: selectedID)
    }

    public func exportSubtitles(kind: SubtitleExportKind, to url: URL) async {
        guard let project else {
            updateEffects(export: .failed(failure(.subtitleExport, .noActiveProject)))
            return
        }
        guard let dependencies = effectDependencies else {
            updateEffects(export: .failed(failure(.subtitleExport, .capabilityUnavailable)))
            return
        }
        let token = nextExportGeneration()
        let projectID = project.id
        updateEffects(export: .running(.subtitleExport))
        let task = Task { [weak self] in
            do {
                try await dependencies.subtitleExporter.export(
                    request: SubtitleExportRequest(
                        segments: project.subtitles,
                        speakerLabels: project.speakerLabels,
                        options: project.speakerExportOptions
                    ),
                    kind: kind,
                    destinationURL: url
                )
                guard let self, self.matches(projectID: projectID, exporting: token) else { return }
                self.updateEffects(export: .completed(.subtitleExport, url))
                self.setExportTask(nil)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.matches(projectID: projectID, exporting: token) else { return }
                self.updateEffects(export: .failed(self.failure(.subtitleExport, .operationFailed, error: error)))
                self.setExportTask(nil)
            }
        }
        setExportTask(task)
        await task.value
    }

    public func exportProject(to url: URL) async {
        guard let project else {
            updateEffects(export: .failed(failure(.projectExport, .noActiveProject)))
            return
        }
        guard let dependencies = effectDependencies else {
            updateEffects(export: .failed(failure(.projectExport, .capabilityUnavailable)))
            return
        }
        let token = nextExportGeneration()
        let projectID = project.id
        updateEffects(export: .running(.projectExport))
        do {
            try dependencies.projectFileService.exportProject(project, to: url)
            guard matches(projectID: projectID, exporting: token) else { return }
            updateEffects(export: .completed(.projectExport, url))
        } catch {
            guard matches(projectID: projectID, exporting: token) else { return }
            updateEffects(export: .failed(failure(.projectExport, .operationFailed, error: error)))
        }
    }

    public func enqueueVideoExport(settings: VideoExportSettings, outputURL: URL) {
        guard var project else {
            updateEffects(export: .failed(failure(.videoExport, .noActiveProject)))
            return
        }
        guard let dependencies = effectDependencies else {
            updateEffects(export: .failed(failure(.videoExport, .capabilityUnavailable)))
            return
        }
        project.videoExportSettings = settings
        _ = install(
            candidate: project,
            metadata: ProjectSessionTransactionMetadata(
                history: .none,
                persistence: .autosave,
                eventKind: .changed
            )
        )
        dependencies.videoExportQueue.enqueue(.fullProject(FullProjectVideoExportRequest(
            project: self.project ?? project,
            settings: settings,
            sourceInfo: effectsState.derivedMedia.videoSourceInfo,
            outputURL: outputURL
        )))
        updateEffects(export: .queued(.videoExport, count: 1))
    }

    public func enqueueShortsExport(shortIDs: [UUID], to directoryURL: URL) {
        guard let project else {
            updateEffects(export: .failed(failure(.shortsExport, .noActiveProject)))
            return
        }
        guard let dependencies = effectDependencies else {
            updateEffects(export: .failed(failure(.shortsExport, .capabilityUnavailable)))
            return
        }
        let requestedIDs = Set(shortIDs)
        let shorts = project.shorts.filter { requestedIDs.contains($0.id) }
        guard !shorts.isEmpty else {
            updateEffects(export: .failed(failure(.shortsExport, .invalidInput)))
            return
        }
        let items = ShortsExportPlanner().plan(ShortsExportPlanningInput(
            projectName: project.displayName,
            shorts: shorts,
            settings: project.shortsExportSettings,
            encodingSettings: project.videoExportSettings,
            editTimeline: project.editTimeline,
            subtitles: project.subtitles,
            sourceInfo: effectsState.derivedMedia.videoSourceInfo,
            destinationDirectory: directoryURL
        ))
        dependencies.videoExportQueue.enqueue(ShortsVideoExportBatchRequest(
            projectID: project.id,
            mediaURL: project.mediaFile.originalURL,
            speakerLabels: project.speakerLabels,
            speakerExportOptions: project.speakerExportOptions,
            items: items
        ))
        updateEffects(export: .queued(.shortsExport, count: items.count))
    }

    private func runPreparation(
        project: Project,
        projectID: UUID,
        token: UInt,
        dependencies: ProjectSessionEffectDependencies
    ) async {
        do {
            let output = try await dependencies.projectPreparer.prepare(
                ProjectPreparationRequest(
                    project: project,
                    configuration: dependencies.preparationConfiguration()
                ),
                events: { [weak self] event in
                    self?.acceptPreparation(event, projectID: projectID, token: token)
                }
            )
            guard matches(projectID: projectID, preparation: token) else { return }
            _ = install(candidate: output.project, metadata: effectMetadata(persistence: .autosave))
            updateEffects(
                preparation: .completed(output.outcome),
                derivedMedia: ProjectSessionDerivedMediaState(
                    projectID: projectID,
                    waveformPeaks: output.waveformPeaks,
                    videoSourceInfo: output.videoSourceInfo
                )
            )
            setPreparationTask(nil)
        } catch is CancellationError {
            return
        } catch {
            guard matches(projectID: projectID, preparation: token) else { return }
            updateEffects(preparation: .failed(failure(.preparation, .operationFailed, error: error)))
            setPreparationTask(nil)
        }
    }

    private func acceptPreparation(_ event: ProjectPreparationEvent, projectID: UUID, token: UInt) {
        guard matches(projectID: projectID, preparation: token) else { return }
        switch event {
        case .projectChanged(let candidate):
            _ = install(candidate: candidate, metadata: effectMetadata(persistence: .none))
        case .progress(let progress):
            updateEffects(preparation: .running(progress))
        }
    }

    private func runTranscription(
        project: Project,
        projectID: UUID,
        token: UInt,
        dependencies: ProjectSessionEffectDependencies
    ) async {
        do {
            let output = try await dependencies.projectTranscriber.transcribe(
                TranscriptionPipelineRequest(
                    project: project,
                    configuration: dependencies.transcriptionConfiguration()
                ),
                events: { [weak self] event in
                    self?.acceptTranscription(event, projectID: projectID, token: token)
                }
            )
            guard matches(projectID: projectID, transcription: token) else { return }
            _ = install(candidate: output.project, metadata: effectMetadata(persistence: .none))
            updateEffects(transcription: .completed(output.warning))
            setTranscriptionTask(nil)
        } catch is CancellationError {
            guard matches(projectID: projectID, transcription: token) else { return }
            updateEffects(transcription: .idle)
            setTranscriptionTask(nil)
        } catch {
            guard matches(projectID: projectID, transcription: token) else { return }
            updateEffects(transcription: .failed(failure(.transcription, .operationFailed, error: error)))
            setTranscriptionTask(nil)
        }
    }

    private func acceptTranscription(_ event: TranscriptionPipelineEvent, projectID: UUID, token: UInt) {
        guard matches(projectID: projectID, transcription: token) else { return }
        switch event {
        case .projectChanged(let candidate):
            _ = install(candidate: candidate, metadata: effectMetadata(persistence: .none))
        case .progress(let progress):
            updateEffects(transcription: .running(progress))
        }
    }

    private func runTranslation(
        project: Project,
        projectID: UUID,
        token: UInt,
        dependencies: ProjectSessionEffectDependencies
    ) async {
        do {
            let output = try await dependencies.projectTranslator.translate(
                TranslationPipelineRequest(project: project),
                events: { [weak self] event in
                    self?.acceptTranslation(event, projectID: projectID, token: token)
                }
            )
            guard matches(projectID: projectID, translation: token) else { return }
            _ = install(candidate: output.project, metadata: effectMetadata(persistence: .none))
            updateEffects(translation: .completed)
            setTranslationTask(nil)
        } catch is CancellationError {
            guard matches(projectID: projectID, translation: token) else { return }
            updateEffects(translation: .idle)
            setTranslationTask(nil)
        } catch {
            guard matches(projectID: projectID, translation: token) else { return }
            updateEffects(translation: .failed(failure(.translation, .operationFailed, error: error)))
            setTranslationTask(nil)
        }
    }

    private func acceptTranslation(_ event: TranslationPipelineEvent, projectID: UUID, token: UInt) {
        guard matches(projectID: projectID, translation: token) else { return }
        _ = install(candidate: event.project, metadata: effectMetadata(persistence: .none))
    }

    private func effectMetadata(
        persistence: ProjectSessionPersistencePolicy
    ) -> ProjectSessionTransactionMetadata {
        ProjectSessionTransactionMetadata(
            history: .none,
            persistence: persistence,
            eventKind: .changed
        )
    }

    private func failure(
        _ kind: ProjectSessionEffectKind,
        _ reason: ProjectSessionEffectFailureReason,
        error: Error? = nil
    ) -> ProjectSessionEffectFailure {
        ProjectSessionEffectFailure(
            kind: kind,
            reason: reason,
            diagnostic: error?.localizedDescription
        )
    }
}
