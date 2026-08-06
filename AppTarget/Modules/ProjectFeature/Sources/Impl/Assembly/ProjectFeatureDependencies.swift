import Application
import Foundation
import Project
import ProjectFeature
import ProjectPreparation
import TranscriptionPipeline
import TranslationPipeline
import Settings
import Subtitles
import Timeline
import SubtitleEditorFeature
import VideoExport

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
    let projectTranslator: any TranslatingProject
    let selection: ProjectSelectionAccess
    let subtitleDocumentPicker: SubtitleDocumentPicker
    let videoExportQueue: any VideoExportQueue

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
        projectTranslator: any TranslatingProject,
        selection: ProjectSelectionAccess,
        subtitleDocumentPicker: SubtitleDocumentPicker,
        videoExportQueue: any VideoExportQueue
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
        self.projectTranslator = projectTranslator
        self.selection = selection
        self.subtitleDocumentPicker = subtitleDocumentPicker
        self.videoExportQueue = videoExportQueue
    }
}
