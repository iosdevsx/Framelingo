import Application
@MainActor
public enum ApplicationAssembly {
    public static func makeAppState(
        dependencies: AppStateDependencies
    ) -> AppState {
        AppState(
            subtitleExportService: dependencies.subtitleExportService,
            translationService: dependencies.translationService,
            speakerDiarizationEngine: dependencies.speakerDiarizationEngine,
            subtitleAlignmentEngine: dependencies.subtitleAlignmentEngine,
            audioPreparationService: dependencies.audioPreparationService
        )
    }
}
