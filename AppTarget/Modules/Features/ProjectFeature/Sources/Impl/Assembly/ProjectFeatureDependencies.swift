import ProjectSession
import SubtitleEditorFeature

/// ProjectFeature receives shared session APIs and a macOS URL-acquisition port.
public struct ProjectFeatureDependencies {
    let session: any ProjectSessionWorkspace
    let subtitleDocumentPicker: SubtitleDocumentPicker

    public init(
        session: any ProjectSessionWorkspace,
        subtitleDocumentPicker: SubtitleDocumentPicker
    ) {
        self.session = session
        self.subtitleDocumentPicker = subtitleDocumentPicker
    }
}
