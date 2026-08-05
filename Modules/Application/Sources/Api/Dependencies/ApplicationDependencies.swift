import Foundation
import Media
import Project
import Settings
import SpeakerAnalysis
import SpeechToText
import Subtitles
import Timeline
import Translation
import VideoRendering

public typealias FFmpegServiceBuilder = (AppSettings) -> any FFmpegService
public typealias SubtitleFilePicker = @MainActor () async -> URL?

public struct AppStateDependencies {
    public var projectRepository: any ProjectRepository
    public var subtitleExportService: any SubtitleExportService
    public var translationService: any TranslationOrchestrating
    public var speakerDiarizationEngine: any SpeakerDiarizationEngine
    public var subtitleAlignmentEngine: any SubtitleAlignmentEngine
    public var audioPreparationService: any AudioPreparationService
    public var makeFFmpegService: FFmpegServiceBuilder
    public var subtitleScriptGenerator: any SubtitleScriptGenerating
    public var fileManager: FileManager
    public var saveSettings: @MainActor (AppSettings) -> Void
    public var revealVideoExport: @MainActor (URL) -> Void
    public var copyText: @MainActor (String) -> Void

    public init(
        projectRepository: any ProjectRepository,
        subtitleExportService: any SubtitleExportService,
        translationService: any TranslationOrchestrating,
        speakerDiarizationEngine: any SpeakerDiarizationEngine,
        subtitleAlignmentEngine: any SubtitleAlignmentEngine,
        audioPreparationService: any AudioPreparationService,
        makeFFmpegService: @escaping FFmpegServiceBuilder,
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        fileManager: FileManager = .default,
        saveSettings: @escaping @MainActor (AppSettings) -> Void,
        revealVideoExport: @escaping @MainActor (URL) -> Void,
        copyText: @escaping @MainActor (String) -> Void
    ) {
        self.projectRepository = projectRepository
        self.subtitleExportService = subtitleExportService
        self.translationService = translationService
        self.speakerDiarizationEngine = speakerDiarizationEngine
        self.subtitleAlignmentEngine = subtitleAlignmentEngine
        self.audioPreparationService = audioPreparationService
        self.makeFFmpegService = makeFFmpegService
        self.subtitleScriptGenerator = subtitleScriptGenerator
        self.fileManager = fileManager
        self.saveSettings = saveSettings
        self.revealVideoExport = revealVideoExport
        self.copyText = copyText
    }
}

public struct ProjectViewModelDependencies {
    public var subtitleImporter: any SubtitleImporting
    public var projectFileService: any ProjectFileServicing
    public var editTimelineService: any EditTimelineEditing
    public var projectPreparationWorkflow: any ProjectPreparationWorkflow
    public var projectTranscriptionWorkflow: any ProjectTranscriptionWorkflow
    public var projectTranslationWorkflow: any ProjectTranslationWorkflow
    public var pickSubtitleFile: SubtitleFilePicker

    public init(
        subtitleImporter: any SubtitleImporting,
        projectFileService: any ProjectFileServicing,
        editTimelineService: any EditTimelineEditing,
        projectPreparationWorkflow: any ProjectPreparationWorkflow,
        projectTranscriptionWorkflow: any ProjectTranscriptionWorkflow,
        projectTranslationWorkflow: any ProjectTranslationWorkflow,
        pickSubtitleFile: @escaping SubtitleFilePicker
    ) {
        self.subtitleImporter = subtitleImporter
        self.projectFileService = projectFileService
        self.editTimelineService = editTimelineService
        self.projectPreparationWorkflow = projectPreparationWorkflow
        self.projectTranscriptionWorkflow = projectTranscriptionWorkflow
        self.projectTranslationWorkflow = projectTranslationWorkflow
        self.pickSubtitleFile = pickSubtitleFile
    }
}
