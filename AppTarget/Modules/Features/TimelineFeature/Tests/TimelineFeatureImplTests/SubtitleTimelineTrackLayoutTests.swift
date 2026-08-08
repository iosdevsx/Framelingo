@testable import TimelineFeatureImpl
import TimelineFeature
import Testing

struct SubtitleTimelineTrackLayoutTests {
    @Test
    func presentationDefaultsPreserveSubtitleEditingAndSimplifyShorts() {
        #expect(SubtitleTimelinePresentation.subtitleEditor.content == .subtitles)
        #expect(SubtitleTimelinePresentation.subtitleEditor.showsCueTrack)
        #expect(SubtitleTimelinePresentation.shorts.content == .shorts)
        #expect(!SubtitleTimelinePresentation.shorts.showsCueTrack)
    }

    @Test
    func compactShortsTrackStaysBetweenRulerAndCues() {
        let layout = SubtitleTimelineTrackLayout(
            rulerHeight: 24,
            shortsHeight: 22,
            waveformHeight: 0,
            cueHeight: 34
        )

        #expect(layout.shortsTopY == 24)
        #expect(layout.waveformTopY == 46)
        #expect(layout.cueTopY == 50)
        #expect(layout.minimumContentHeight == 94)
    }

    @Test
    func expandedShortsTrackPlacesWaveformBeforeCues() {
        let layout = SubtitleTimelineTrackLayout(
            rulerHeight: 24,
            shortsHeight: 22,
            waveformHeight: 74,
            cueHeight: 34
        )

        #expect(layout.waveformTopY == 46)
        #expect(layout.cueTopY == 124)
    }

    @Test
    func waveformShrinksToKeepShortsAndCuesInsideTimeline() {
        let waveformHeight = SubtitleTimelineTrackLayout.resolvedWaveformHeight(
            isVisible: true,
            preferredHeight: 74,
            availableHeight: 146,
            rulerHeight: 24,
            shortsHeight: 22,
            cueHeight: 34
        )
        let layout = SubtitleTimelineTrackLayout(
            rulerHeight: 24,
            shortsHeight: 22,
            waveformHeight: waveformHeight,
            cueHeight: 34
        )

        #expect(waveformHeight == 52)
        #expect(layout.minimumContentHeight == 146)
    }
}
