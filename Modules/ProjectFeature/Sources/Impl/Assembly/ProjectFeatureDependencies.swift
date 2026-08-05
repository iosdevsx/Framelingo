import Application
import Foundation
import Project
import Subtitles
import Timeline

/// Composition inputs for the project workspace. Concrete implementations are
/// supplied by MacFeatureImpl, while the workspace ViewModel stays internal.
public struct ProjectFeatureDependencies {
    let subtitleImporter: any SubtitleImporting
    let projectFileService: any ProjectFileServicing
    let editTimelineService: any EditTimelineEditing
    let projectPreparationWorkflow: any ProjectPreparationWorkflow
    let projectTranscriptionWorkflow: any ProjectTranscriptionWorkflow
    let projectTranslationWorkflow: any ProjectTranslationWorkflow
    let pickSubtitleFile: @MainActor () async -> URL?

    public init(
        subtitleImporter: any SubtitleImporting,
        projectFileService: any ProjectFileServicing,
        editTimelineService: any EditTimelineEditing,
        projectPreparationWorkflow: any ProjectPreparationWorkflow,
        projectTranscriptionWorkflow: any ProjectTranscriptionWorkflow,
        projectTranslationWorkflow: any ProjectTranslationWorkflow,
        pickSubtitleFile: @escaping @MainActor () async -> URL?
    ) {
        self.subtitleImporter = subtitleImporter
        self.projectFileService = projectFileService
        self.editTimelineService = editTimelineService
        self.projectPreparationWorkflow = projectPreparationWorkflow
        self.projectTranscriptionWorkflow = projectTranscriptionWorkflow
        self.projectTranslationWorkflow = projectTranslationWorkflow
        self.pickSubtitleFile = pickSubtitleFile
    }
}
