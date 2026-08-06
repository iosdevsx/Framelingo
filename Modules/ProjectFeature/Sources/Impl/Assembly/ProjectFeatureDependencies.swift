import Application
import Foundation
import Project
import ProjectFeature
import ProjectPreparation
import TranscriptionPipeline
import Settings
import Subtitles
import Timeline
import SubtitleEditorFeature

/// Composition inputs for the project workspace. Concrete implementations are
/// supplied by MacFeatureImpl, while the workspace ViewModel stays internal.
public struct ProjectFeatureDependencies {
    let projectRepository: any ProjectRepository
    let projectCatalog: any ProjectCatalogManaging
    let settingsAccess: SettingsAccess
    let subtitleImporter: any SubtitleImporting
    let projectFileService: any ProjectFileServicing
    let editTimelineService: any EditTimelineEditing
    let projectPreparer: any ProjectPreparing
    let projectPreparationConfiguration: ProjectPreparationConfigurationProvider
    let projectTranscriber: any TranscribingProject
    let projectTranslationWorkflow: any ProjectTranslationWorkflow
    let selection: ProjectSelectionAccess
    let subtitleDocumentPicker: SubtitleDocumentPicker

    public init(
        projectRepository: any ProjectRepository,
        projectCatalog: any ProjectCatalogManaging,
        settingsAccess: SettingsAccess,
        subtitleImporter: any SubtitleImporting,
        projectFileService: any ProjectFileServicing,
        editTimelineService: any EditTimelineEditing,
        projectPreparer: any ProjectPreparing,
        projectPreparationConfiguration: @escaping ProjectPreparationConfigurationProvider,
        projectTranscriber: any TranscribingProject,
        projectTranslationWorkflow: any ProjectTranslationWorkflow,
        selection: ProjectSelectionAccess,
        subtitleDocumentPicker: SubtitleDocumentPicker
    ) {
        self.projectRepository = projectRepository
        self.projectCatalog = projectCatalog
        self.settingsAccess = settingsAccess
        self.subtitleImporter = subtitleImporter
        self.projectFileService = projectFileService
        self.editTimelineService = editTimelineService
        self.projectPreparer = projectPreparer
        self.projectPreparationConfiguration = projectPreparationConfiguration
        self.projectTranscriber = projectTranscriber
        self.projectTranslationWorkflow = projectTranslationWorkflow
        self.selection = selection
        self.subtitleDocumentPicker = subtitleDocumentPicker
    }
}
