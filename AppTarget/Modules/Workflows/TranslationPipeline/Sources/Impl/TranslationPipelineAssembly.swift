import Project
import Translation
import TranslationPipeline

public enum TranslationPipelineAssembly {
    public static func makeTranslator(
        projectRepository: any ProjectRepository,
        translationService: any TranslationOrchestrating
    ) -> any TranslatingProject {
        DefaultTranslationPipeline(
            projectRepository: projectRepository,
            translationService: translationService
        )
    }
}
