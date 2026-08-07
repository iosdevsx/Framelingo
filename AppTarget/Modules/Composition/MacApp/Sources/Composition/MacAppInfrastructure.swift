import Foundation
import Media
import Project
import ProjectPreparation
import Settings
import SpeechToText
import Subtitles
import Timeline
import TranscriptionPipeline
import TranslationPipeline
import VideoExport
import VideoRendering

typealias FFmpegServiceBuilder = (AppSettings) -> any FFmpegService

/// API-typed infrastructure selected by the macOS product composer. This value
/// never leaves the composition boundary or reaches navigation Views.
struct MacAppInfrastructure {
    let videoExportQueue: any VideoExportQueue
    let settingsAccess: SettingsAccess
    let projectCatalog: any ProjectCatalogManaging
    let projectRepository: any ProjectRepository
    let preparedMediaCleanup: PreparedMediaCleanup
    let subtitleImporter: any SubtitleImporting
    let subtitleExportService: any SubtitleExportService
    let editTimelineService: any EditTimelineEditing
    let projectPreparer: any ProjectPreparing
    let projectPreparationConfiguration: ProjectPreparationConfigurationProvider
    let projectTranscriber: any TranscribingProject
    let projectTranslator: any TranslatingProject
    let mediaMetadataProvider: any MediaMetadataProviding
    let makeFFmpegService: FFmpegServiceBuilder
    let projectFileService: any ProjectFileServicing
    let whisperModelManager: any WhisperModelManaging
    let parakeetModelManager: any ParakeetModelManaging
    let usesEmbeddedVideoRenderingBackend: Bool
    let fileManager: FileManager
    let mockProject: Project
    let mockSubtitles: [SubtitleSegment]
}
