import Application
import Project
import Translation

public enum ApplicationWorkflowAssembly {
    public static func makeProjectTranslationWorkflow(
        projectRepository: any ProjectRepository,
        translationService: any TranslationOrchestrating
    ) -> any ProjectTranslationWorkflow {
        DefaultProjectTranslationWorkflow(
            projectRepository: projectRepository,
            translationService: translationService
        )
    }
}
