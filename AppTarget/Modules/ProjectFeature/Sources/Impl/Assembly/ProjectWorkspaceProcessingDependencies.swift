import ProjectPreparation
import TranscriptionPipeline
import TranslationPipeline

public struct ProjectWorkspaceProcessingDependencies {
    let projectPreparer: any ProjectPreparing
    let projectPreparationConfiguration: ProjectPreparationConfigurationProvider
    let projectTranscriber: any TranscribingProject
    let transcriptionActivity: any TranscriptionActivityTracking
    let projectTranslator: any TranslatingProject

    public init(
        projectPreparer: any ProjectPreparing,
        projectPreparationConfiguration: @escaping ProjectPreparationConfigurationProvider,
        projectTranscriber: any TranscribingProject,
        transcriptionActivity: any TranscriptionActivityTracking,
        projectTranslator: any TranslatingProject
    ) {
        self.projectPreparer = projectPreparer
        self.projectPreparationConfiguration = projectPreparationConfiguration
        self.projectTranscriber = projectTranscriber
        self.transcriptionActivity = transcriptionActivity
        self.projectTranslator = projectTranslator
    }
}
