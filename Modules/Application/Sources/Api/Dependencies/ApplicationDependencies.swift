import Foundation
import Media
import Project
import Settings
import SpeakerAnalysis
import Subtitles
import Translation
import VideoRendering

public typealias FFmpegServiceBuilder = (AppSettings) -> any FFmpegService
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
