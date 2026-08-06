import VideoExport

/// Feature-scoped groups keep data, editing, processing, and export boundaries explicit.
public struct ProjectFeatureDependencies {
    let data: ProjectWorkspaceDataDependencies
    let editing: ProjectWorkspaceEditingDependencies
    let processing: ProjectWorkspaceProcessingDependencies
    let videoExportQueue: any VideoExportQueue

    public init(
        data: ProjectWorkspaceDataDependencies,
        editing: ProjectWorkspaceEditingDependencies,
        processing: ProjectWorkspaceProcessingDependencies,
        videoExportQueue: any VideoExportQueue
    ) {
        self.data = data
        self.editing = editing
        self.processing = processing
        self.videoExportQueue = videoExportQueue
    }
}
