import Foundation
import Shorts
import ShortsFeature
import Testing

@MainActor
struct ShortsWorkspaceContractsTests {
    @Test
    func stateResolvesSelectionWithoutOwningAnotherShortsArray() {
        let short = ShortDefinition(title: "Selected", startMs: 1_000, endMs: 3_000)
        let state = ShortsWorkspaceState(
            subtitles: [],
            shorts: [short],
            exportSettings: ShortsExportSettings(),
            currentTimeMs: 1_500,
            selectedShortID: short.id,
            suggestions: [],
            suggestionMessage: nil,
            videoSourceInfo: nil
        )

        #expect(state.selectedShort == short)
    }
}
