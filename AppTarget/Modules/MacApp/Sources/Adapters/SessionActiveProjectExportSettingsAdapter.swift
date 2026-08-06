import Project
import ProjectSession
import VideoRendering

@MainActor
final class SessionActiveProjectExportSettingsAdapter: ActiveProjectExportSettingsManaging {
    var current: VideoExportSettings? { session.snapshot.project?.videoExportSettings }

    private let session: any ProjectSessionSubtitleEditing & ProjectSessionObserving

    init(session: any ProjectSessionSubtitleEditing & ProjectSessionObserving) {
        self.session = session
    }

    func update(_ settings: VideoExportSettings) {
        _ = session.updateVideoExportSettings(settings, undoable: true)
    }
}
