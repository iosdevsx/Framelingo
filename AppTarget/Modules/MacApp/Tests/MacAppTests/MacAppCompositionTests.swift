import ExportFeature
import PlayerFeature
import Project
import ProjectFeature
import ShortsFeature
import Subtitles
import SubtitleEditorFeature
import SwiftUI
import TimelineFeature
import XCTest

@testable import MacApp

@MainActor
final class MacAppCompositionTests: XCTestCase {
    @FocusState private var focusedSubtitleField: SubtitleEditorFocus?

    func testProductRootSelectsComponentsAndConstructsEveryProjectWorkspaceMode() {
        let dependencies = MacAppComposition.makeInfrastructure()
        let graph = MacAppComposition.makeNavigationGraph(
            infrastructure: dependencies,
            platform: .live
        )
        XCTAssertEqual(
            dependencies.projectPreparationConfiguration().ffmpegExecutablePath,
            dependencies.settingsAccess.snapshot.settings.ffmpegPath
        )
        _ = graph.screens.makeHome()
        _ = graph.screens.makeSettings()
        for initialMode in ProjectWorkspaceMode.allCases {
            var mode = initialMode
            _ = graph.screens.makeProject(Binding(get: { mode }, set: { mode = $0 }))
        }

        graph.runtime.open(dependencies.mockProject)
        XCTAssertEqual(graph.runtime.session.snapshot.project?.id, dependencies.mockProject.id)
        XCTAssertEqual(graph.runtime.shell.selectedProjectID, dependencies.mockProject.id)
    }

    func testWorkspaceSessionsHaveIndependentWindowLifetimes() {
        let dependencies = MacAppComposition.makeInfrastructure()
        let first = MacAppComposition.makeNavigationGraph(
            infrastructure: dependencies,
            platform: .live
        ).runtime
        let second = MacAppComposition.makeNavigationGraph(
            infrastructure: dependencies,
            platform: .live
        ).runtime
        let firstProject = dependencies.mockProject
        let secondProject = Project(
            id: UUID(),
            name: "Second window",
            createdAt: firstProject.createdAt,
            updatedAt: firstProject.updatedAt,
            mediaFile: firstProject.mediaFile,
            sourceLanguage: firstProject.sourceLanguage,
            targetLanguage: firstProject.targetLanguage,
            subtitles: firstProject.subtitles,
            wordTimings: firstProject.wordTimings,
            speakers: firstProject.speakers,
            speakerLabels: firstProject.speakerLabels,
            speakerSegments: firstProject.speakerSegments,
            status: firstProject.status,
            videoExportSettings: firstProject.videoExportSettings,
            speakerExportOptions: firstProject.speakerExportOptions,
            editTimeline: firstProject.editTimeline,
            shorts: firstProject.shorts,
            shortsExportSettings: firstProject.shortsExportSettings
        )

        first.open(firstProject)
        second.open(secondProject)
        _ = first.session.updateTargetLanguage("German")

        XCTAssertEqual(first.session.snapshot.project?.id, firstProject.id)
        XCTAssertEqual(first.session.snapshot.project?.targetLanguage, "German")
        XCTAssertEqual(second.session.snapshot.project?.id, secondProject.id)
        XCTAssertEqual(second.session.snapshot.project?.targetLanguage, secondProject.targetLanguage)

        first.session.close()
        XCTAssertNil(first.session.snapshot.project)
        XCTAssertEqual(second.session.snapshot.project?.id, secondProject.id)
    }

    func testConcreteCapabilityAdaptersAcceptEveryProjectSurfaceRequest() throws {
        let dependencies = MacAppComposition.makeInfrastructure()
        let components = MacAppComposition.makeProjectComponents(
            infrastructure: dependencies,
            platform: .live
        )
        let project = dependencies.mockProject

        _ = components.player.makeProjectVideoPreview(
            ProjectVideoPreviewRequest(
                state: ProjectVideoPreviewState(
                    project: project,
                    player: nil,
                    isPlaying: false,
                    currentTimeMs: 0,
                    showsControls: true,
                    videoSourceInfo: nil
                ),
                actions: ProjectVideoPreviewActions(
                    togglePlayback: {},
                    updateSettings: { _, _ in }
                )
            )
        )

        var subtitles = project.subtitles
        var selectedSegmentID: UUID?
        var zoom = 1.0
        var scrollRequest = 0
        var showsWaveform = true
        _ = components.timeline.makeSubtitleTimeline(
            SubtitleTimelineRequest(
                state: SubtitleTimelineState(
                    currentTimeMs: 0,
                    durationMs: project.mediaFile.durationMs ?? 0,
                    waveformPeaks: [],
                    speakers: project.speakers
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
                    seek: { _ in },
                    beginTextEditing: { _ in },
                    translatedTextChange: { _, _ in },
                    endTextEditing: {}
                ),
                keyboardActions: TimelineKeyboardActions(onStep: { _ in })
            )
        )
        _ = components.timeline.makeEditTimeline(
            EditTimelineRequest(
                state: EditTimelineState(
                    timeline: dependencies.editTimelineService.makeInitialTimeline(durationMs: 1_000),
                    subtitles: project.subtitles,
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

        let editorState = SubtitleEditorState(
            subtitles: project.subtitles,
            speakers: project.speakers,
            speakerLabels: project.speakerLabels,
            selectedSegmentID: nil,
            selectedCueIDs: [],
            activeSegmentID: nil,
            autosaveErrorMessage: nil
        )
        let editorActions = SubtitleEditorActions(
            selectSegment: { _, _, _ in },
            updateSubtitle: { SubtitleEditorUpdateResult(segment: $0, errorMessage: nil) },
            addSegmentAfter: { _ in nil },
            splitSegment: { _ in nil },
            mergeWithNextSegment: { _ in nil },
            deleteSegment: { _ in nil },
            createShortFromSelectedCues: {},
            beginTextEdit: { _ in },
            endTextEdit: {},
            currentErrorMessage: { nil }
        )
        _ = components.subtitleEditor.makeCueList(
            SubtitleCueListRequest(
                state: editorState,
                actions: editorActions,
                focusedField: $focusedSubtitleField,
                onSeek: { _ in },
                onError: { _ in }
            )
        )
        _ = components.subtitleEditor.makeEditorPane(
            SubtitleEditorPaneRequest(
                state: editorState,
                actions: editorActions,
                onSeek: { _ in }
            )
        )
        _ = components.subtitleEditor.makeSubtitleEditor(
            SubtitleEditorRequest(
                state: editorState,
                actions: editorActions,
                focusedField: $focusedSubtitleField,
                onSeek: { _ in },
                onError: { _ in }
            )
        )
        let importPreview = SubtitleImportPreview(
            fileURL: URL(fileURLWithPath: "/tmp/input.srt"),
            format: .srt,
            detectedEncodingName: "UTF-8",
            segments: project.subtitles,
            warnings: []
        )
        _ = components.subtitleEditor.makeImportPreview(
            SubtitleImportPreviewRequest(
                preview: importPreview,
                hasExistingSubtitles: true,
                onCancel: {},
                onImport: { _, _ in }
            )
        )

        _ = components.shorts.makeWorkspace(
            ShortsWorkspaceRequest(
                state: ShortsWorkspaceState(
                    subtitles: project.subtitles,
                    shorts: project.shorts,
                    exportSettings: project.shortsExportSettings,
                    currentTimeMs: 0,
                    selectedShortID: nil,
                    suggestions: [],
                    suggestionMessage: nil,
                    videoSourceInfo: nil
                ),
                actions: makeShortsActions(),
                player: nil,
                onSeek: { _ in }
            )
        )

        _ = components.export.makeVideoSheet(
            VideoExportPresentationRequest(
                project: project,
                actions: VideoExportPresentationActions { _ in }
            )
        )
        _ = components.export.makeSubtitleOptionsSheet(
            SubtitleExportOptionsRequest(
                state: SubtitleExportOptionsState(
                    options: project.speakerExportOptions,
                    hasSpeakerLabels: !project.speakerLabels.isEmpty
                ),
                actions: SubtitleExportOptionsActions { _ in },
                kind: .translatedSRT,
                onCancel: {},
                onExport: {}
            )
        )
    }

    private func makeShortsActions() -> ShortsWorkspaceActions {
        ShortsWorkspaceActions(
            selectShort: { _ in },
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
