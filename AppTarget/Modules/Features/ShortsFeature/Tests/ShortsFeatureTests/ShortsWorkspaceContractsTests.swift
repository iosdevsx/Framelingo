import Foundation
import Shorts
import ShortsFeature
@testable import ShortsFeatureImpl
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

    @Test
    func contextualPanelKeepsClipsAndEditingMutuallyExclusive() {
        #expect(ShortsContextPanelMode.allCases == [.clips, .edit])
        #expect(ShortsContextPanelMode.clips.title == "Clips")
        #expect(ShortsContextPanelMode.edit.title == "Edit")
    }
}
