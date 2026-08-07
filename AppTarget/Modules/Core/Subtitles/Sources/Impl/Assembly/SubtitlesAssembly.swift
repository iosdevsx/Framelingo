import Subtitles

public enum SubtitlesAssembly {
    public static func makeImporter() -> any SubtitleImporting {
        SubtitleImportService()
    }

    public static func makeExporter() -> any SubtitleExportService {
        FileSubtitleExportService()
    }

    public static func makeTimecodeService() -> any SubtitleTimecodeService {
        DefaultSubtitleTimecodeService()
    }

    public static func makeParser() -> any SubtitleParsing {
        DefaultSubtitleParser()
    }

}
