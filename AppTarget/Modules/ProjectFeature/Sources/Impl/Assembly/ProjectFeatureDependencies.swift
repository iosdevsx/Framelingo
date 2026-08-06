import VideoExport
import ProjectSession

/// Feature-scoped groups keep data, editing, processing, and export boundaries explicit.
public struct ProjectFeatureDependencies {
    let data: ProjectWorkspaceDataDependencies
    let editing: ProjectWorkspaceEditingDependencies
    let processing: ProjectWorkspaceProcessingDependencies
    let videoExportQueue: any VideoExportQueue
    let session: any ProjectSessionWorkspace

    public init(
        data: ProjectWorkspaceDataDependencies,
        editing: ProjectWorkspaceEditingDependencies,
        processing: ProjectWorkspaceProcessingDependencies,
        videoExportQueue: any VideoExportQueue,
        session: any ProjectSessionWorkspace
    ) {
        self.data = data
        self.editing = editing
        self.processing = processing
        self.videoExportQueue = videoExportQueue
        self.session = session
    }
}
