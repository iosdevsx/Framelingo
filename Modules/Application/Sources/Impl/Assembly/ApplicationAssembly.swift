import Application
import Project

@MainActor
public enum ApplicationAssembly {
    public static func makeAppState(
        selectedProject: Project?,
        dependencies: AppStateDependencies
    ) -> AppState {
        AppState(
            selectedProject: selectedProject,
            subtitleExportService: dependencies.subtitleExportService,
            translationService: dependencies.translationService,
            speakerDiarizationEngine: dependencies.speakerDiarizationEngine,
            subtitleAlignmentEngine: dependencies.subtitleAlignmentEngine,
            audioPreparationService: dependencies.audioPreparationService,
            makeFFmpegService: dependencies.makeFFmpegService,
            subtitleScriptGenerator: dependencies.subtitleScriptGenerator,
            fileManager: dependencies.fileManager,
            currentSettings: dependencies.currentSettings,
            revealVideoExport: dependencies.revealVideoExport,
            copyText: dependencies.copyText
        )
    }
}
