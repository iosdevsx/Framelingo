import Application
import Project
import Settings

@MainActor
public enum ApplicationAssembly {
    public static func makeAppState(
        recentProjects: [Project],
        selectedProject: Project?,
        settings: AppSettings,
        dependencies: AppStateDependencies
    ) -> AppState {
        AppState(
            recentProjects: recentProjects,
            selectedProject: selectedProject,
            settings: settings,
            projectRepository: dependencies.projectRepository,
            subtitleExportService: dependencies.subtitleExportService,
            translationService: dependencies.translationService,
            speakerDiarizationEngine: dependencies.speakerDiarizationEngine,
            subtitleAlignmentEngine: dependencies.subtitleAlignmentEngine,
            audioPreparationService: dependencies.audioPreparationService,
            makeFFmpegService: dependencies.makeFFmpegService,
            subtitleScriptGenerator: dependencies.subtitleScriptGenerator,
            fileManager: dependencies.fileManager,
            saveSettings: dependencies.saveSettings,
            revealVideoExport: dependencies.revealVideoExport,
            copyText: dependencies.copyText
        )
    }
}
