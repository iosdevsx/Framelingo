import Foundation
import Media
import Settings
import SpeakerAnalysis
import Subtitles
import Translation
import VideoRendering

public typealias FFmpegServiceBuilder = (AppSettings) -> any FFmpegService
public struct AppStateDependencies {
    public var subtitleExportService: any SubtitleExportService
    public var translationService: any TranslationOrchestrating
    public var speakerDiarizationEngine: any SpeakerDiarizationEngine
    public var subtitleAlignmentEngine: any SubtitleAlignmentEngine
    public var audioPreparationService: any AudioPreparationService
    public var makeFFmpegService: FFmpegServiceBuilder
    public var subtitleScriptGenerator: any SubtitleScriptGenerating
    public var fileManager: FileManager
    public var currentSettings: @MainActor () -> AppSettings
    public var revealVideoExport: @MainActor (URL) -> Void
    public var copyText: @MainActor (String) -> Void

    public init(
        subtitleExportService: any SubtitleExportService,
        translationService: any TranslationOrchestrating,
        speakerDiarizationEngine: any SpeakerDiarizationEngine,
        subtitleAlignmentEngine: any SubtitleAlignmentEngine,
        audioPreparationService: any AudioPreparationService,
        makeFFmpegService: @escaping FFmpegServiceBuilder,
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        fileManager: FileManager = .default,
        currentSettings: @escaping @MainActor () -> AppSettings,
        revealVideoExport: @escaping @MainActor (URL) -> Void,
        copyText: @escaping @MainActor (String) -> Void
    ) {
        self.subtitleExportService = subtitleExportService
        self.translationService = translationService
        self.speakerDiarizationEngine = speakerDiarizationEngine
        self.subtitleAlignmentEngine = subtitleAlignmentEngine
        self.audioPreparationService = audioPreparationService
        self.makeFFmpegService = makeFFmpegService
        self.subtitleScriptGenerator = subtitleScriptGenerator
        self.fileManager = fileManager
        self.currentSettings = currentSettings
        self.revealVideoExport = revealVideoExport
        self.copyText = copyText
    }
}
