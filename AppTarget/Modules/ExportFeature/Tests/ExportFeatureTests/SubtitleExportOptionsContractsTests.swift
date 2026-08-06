import ExportFeature
import Subtitles
import Testing

@MainActor
struct SubtitleExportOptionsContractsTests {
    @Test
    func actionForwardsOnlySubtitleExportOptions() {
        var received: SubtitleExportOptions?
        let actions = SubtitleExportOptionsActions { received = $0 }
        var options = SubtitleExportOptions()
        options.includeSpeakerLabels = true

        actions.update(options)

        #expect(received == options)
    }
}
