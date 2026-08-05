import ExportFeature
import Foundation
import PlayerFeature
import ProjectFeature
import Shorts
import ShortsFeature
import Subtitles
import SubtitleEditorFeature
import SwiftUI
import Timeline
import TimelineFeature
import VideoRendering
import XCTest

@MainActor
final class CapabilityFactoryContractTests: XCTestCase {
    func testAPIFactoriesRecordRequestsAndForwardRepresentativeActions() {
        let project = TestDoubles.project()
        var playerRequests = 0
        var playbackToggles = 0
        let player = PlayerFeatureFactory { request in
            playerRequests += 1
            request.actions.togglePlayback()
            return AnyView(EmptyView())
        }
        _ = player.makeProjectVideoPreview(
            ProjectVideoPreviewRequest(
                state: ProjectVideoPreviewState(
                    project: project,
                    player: nil,
                    isPlaying: false,
                    currentTimeMs: 125,
                    showsControls: true,
                    videoSourceInfo: nil
                ),
                actions: ProjectVideoPreviewActions(
                    togglePlayback: { playbackToggles += 1 },
                    updateSettings: { _, _ in }
                )
            )
        )

        var subtitles = project.subtitles
        var selectedSegmentID: UUID?
        var zoom = 1.0
        var scrollRequest = 0
        var showsWaveform = true
        var subtitleTimelineRequests = 0
        var editTimelineRequests = 0
        var seeks: [Int] = []
        var steps: [Int] = []
        let timeline = TimelineFeatureFactory(
            makeSubtitleTimeline: { request in
                subtitleTimelineRequests += 1
                request.actions.seek(to: 500)
                request.keyboardActions.step(1)
                return AnyView(EmptyView())
            },
            makeEditTimeline: { _ in
                editTimelineRequests += 1
                return AnyView(EmptyView())
            }
        )
        _ = timeline.makeSubtitleTimeline(
            SubtitleTimelineRequest(
                state: SubtitleTimelineState(
                    currentTimeMs: 0,
                    durationMs: 1_000,
                    waveformPeaks: [],
                    speakers: []
                ),
                bindings: SubtitleTimelineBindings(
                    subtitles: Binding(get: { subtitles }, set: { subtitles = $0 }),
                    selectedSegmentID: Binding(
                        get: { selectedSegmentID },
                        set: { selectedSegmentID = $0 }
                    ),
                    zoomFactor: Binding(get: { zoom }, set: { zoom = $0 }),
                    scrollToPlayheadRequest: Binding(
                        get: { scrollRequest },
                        set: { scrollRequest = $0 }
                    ),
                    showsWaveform: Binding(
                        get: { showsWaveform },
                        set: { showsWaveform = $0 }
                    )
                ),
                actions: SubtitleTimelineActions(
                    seek: { seeks.append($0) },
                    beginTextEditing: { _ in },
                    translatedTextChange: { _, _ in },
                    endTextEditing: {}
                ),
                keyboardActions: TimelineKeyboardActions(onStep: { steps.append($0) })
            )
        )
        _ = timeline.makeEditTimeline(
            EditTimelineRequest(
                state: EditTimelineState(
                    timeline: EditTimeline(clips: [], totalDurationMs: 0),
                    subtitles: subtitles,
                    currentTimeMs: 0,
                    rangeStartMs: nil,
                    rangeEndMs: nil
                ),
                bindings: EditTimelineBindings(
                    selectedClipID: .constant(nil),
                    zoomFactor: .constant(1)
                ),
                actions: EditTimelineActions(seek: { _ in }, selectClip: { _ in }),
                keyboardActions: TimelineKeyboardActions(onStep: { _ in })
            )
        )

        var importRequests = 0
        var importCancellations = 0
        let subtitleEditor = SubtitleEditorFeatureFactory(
            makeCueList: { _ in AnyView(EmptyView()) },
            makeEditorPane: { _ in AnyView(EmptyView()) },
            makeSubtitleEditor: { _ in AnyView(EmptyView()) },
            makeImportPreview: { request in
                importRequests += 1
                request.cancel()
                return AnyView(EmptyView())
            }
        )
        _ = subtitleEditor.makeImportPreview(
            SubtitleImportPreviewRequest(
                preview: SubtitleImportPreview(
                    fileURL: URL(fileURLWithPath: "/tmp/input.srt"),
                    format: .srt,
                    detectedEncodingName: "UTF-8",
                    segments: subtitles,
                    warnings: []
                ),
                hasExistingSubtitles: true,
                onCancel: { importCancellations += 1 },
                onImport: { _, _ in }
            )
        )

        var shortsRequests = 0
        var shortSelections = 0
        var shortsSeeks: [Int] = []
        let shorts = ShortsFeatureFactory { request in
            shortsRequests += 1
            request.actions.selectShort(id: nil)
            request.seek(to: 750)
            return AnyView(EmptyView())
        }
        _ = shorts.makeWorkspace(
            ShortsWorkspaceRequest(
                state: ShortsWorkspaceState(
                    subtitles: subtitles,
                    shorts: [],
                    exportSettings: ShortsExportSettings(),
                    currentTimeMs: 0,
                    selectedShortID: nil,
                    suggestions: [],
                    suggestionMessage: nil,
                    videoSourceInfo: nil
                ),
                actions: makeShortsActions { shortSelections += 1 },
                player: nil,
                onSeek: { shortsSeeks.append($0) }
            )
        )

        var videoExportRequests = 0
        var exportSubmissions = 0
        var subtitleOptionsRequests = 0
        let export = ExportFeatureFactory(
            makeVideoSheet: { request in
                videoExportRequests += 1
                request.actions.submit(
                    VideoExportSubmission(
                        project: request.project,
                        settings: VideoExportSettings(),
                        sourceInfo: nil,
                        outputURL: URL(fileURLWithPath: "/tmp/output.mp4")
                    )
                )
                return AnyView(EmptyView())
            },
            makeSubtitleOptionsSheet: { _ in
                subtitleOptionsRequests += 1
                return AnyView(EmptyView())
            }
        )
        _ = export.makeVideoSheet(
            VideoExportPresentationRequest(
                project: project,
                actions: VideoExportPresentationActions { _ in exportSubmissions += 1 }
            )
        )
        _ = export.makeSubtitleOptionsSheet(
            SubtitleExportOptionsRequest(
                state: SubtitleExportOptionsState(
                    options: SubtitleExportOptions(),
                    hasSpeakerLabels: false
                ),
                actions: SubtitleExportOptionsActions { _ in },
                kind: .translatedSRT,
                onCancel: {},
                onExport: {}
            )
        )

        _ = ProjectFeatureComponents(
            player: player,
            timeline: timeline,
            subtitleEditor: subtitleEditor,
            shorts: shorts,
            export: export
        )

        XCTAssertEqual(playerRequests, 1)
        XCTAssertEqual(playbackToggles, 1)
        XCTAssertEqual(subtitleTimelineRequests, 1)
        XCTAssertEqual(editTimelineRequests, 1)
        XCTAssertEqual(seeks, [500])
        XCTAssertEqual(steps, [1])
        XCTAssertEqual(importRequests, 1)
        XCTAssertEqual(importCancellations, 1)
        XCTAssertEqual(shortsRequests, 1)
        XCTAssertEqual(shortSelections, 1)
        XCTAssertEqual(shortsSeeks, [750])
        XCTAssertEqual(videoExportRequests, 1)
        XCTAssertEqual(exportSubmissions, 1)
        XCTAssertEqual(subtitleOptionsRequests, 1)
    }

    private func makeShortsActions(onSelect: @escaping () -> Void) -> ShortsWorkspaceActions {
        ShortsWorkspaceActions(
            selectShort: { _ in onSelect() },
            addShortAtPlayhead: {},
            deleteShort: { _ in },
            updateShort: { _, _, _ in },
            beginInteractiveShortEdit: {},
            endInteractiveShortEdit: { _ in },
            addCropPointAtPlayhead: { _ in },
            updateShortCropOffset: { _, _, _ in },
            deleteShortCropKeyframe: { _, _ in },
            updateExportSettings: { _ in },
            updateSubtitleStyle: { _, _ in },
            beginInteractiveSubtitleStyleEdit: {},
            endInteractiveSubtitleStyleEdit: { _ in },
            generateSuggestions: {},
            acceptSuggestion: { _ in },
            dismissSuggestion: { _ in },
            exportShorts: { _, _ in }
        )
    }
}
