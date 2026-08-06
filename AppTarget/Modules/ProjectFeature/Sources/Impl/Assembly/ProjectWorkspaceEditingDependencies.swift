import Project
import SubtitleEditorFeature
import Subtitles
import Timeline

public struct ProjectWorkspaceEditingDependencies {
    let subtitleImporter: any SubtitleImporting
    let subtitleExportService: any SubtitleExportService
    let projectFileService: any ProjectFileServicing
    let editTimelineService: any EditTimelineEditing
    let subtitleDocumentPicker: SubtitleDocumentPicker

    public init(
        subtitleImporter: any SubtitleImporting,
        subtitleExportService: any SubtitleExportService,
        projectFileService: any ProjectFileServicing,
        editTimelineService: any EditTimelineEditing,
        subtitleDocumentPicker: SubtitleDocumentPicker
    ) {
        self.subtitleImporter = subtitleImporter
        self.subtitleExportService = subtitleExportService
        self.projectFileService = projectFileService
        self.editTimelineService = editTimelineService
        self.subtitleDocumentPicker = subtitleDocumentPicker
    }
}
