import Application
import ExportFeature
import ProjectFeature
import ShortsFeature
import SubtitleEditorFeature
import SwiftUI

public enum ProjectFeatureAssembly {
    @MainActor
    public static func makeView(
        appState: AppState,
        dependencies: ProjectFeatureDependencies,
        projectMode: Binding<ProjectWorkspaceMode>,
        components: ProjectFeatureComponents
    ) -> some View {
        ProjectFeatureRootView(
            appState: appState,
            dependencies: dependencies,
            projectMode: projectMode,
            components: components
        )
    }
}

@MainActor
private struct ProjectFeatureRootView: View {
    @StateObject private var viewModel: ProjectViewModel
    @Binding private var projectMode: ProjectWorkspaceMode

    private let appState: AppState
    private let components: ProjectFeatureComponents
    private let subtitleEditorActions: SubtitleEditorActions
    private let shortsWorkspaceActions: ShortsWorkspaceActions
    private let subtitleExportOptionsActions: SubtitleExportOptionsActions

    init(
        appState: AppState,
        dependencies: ProjectFeatureDependencies,
        projectMode: Binding<ProjectWorkspaceMode>,
        components: ProjectFeatureComponents
    ) {
        let viewModel = ProjectViewModel(
            appState: appState,
            dependencies: dependencies
        )
        self.appState = appState
        _viewModel = StateObject(wrappedValue: viewModel)
        _projectMode = projectMode
        self.components = components
        self.subtitleEditorActions = SubtitleEditorActions(
            selectSegment: viewModel.selectSegment,
            updateSubtitle: { segment in
                viewModel.updateSubtitle(segment)
                return SubtitleEditorUpdateResult(
                    segment: viewModel.project?.subtitles.first(where: { $0.id == segment.id }),
                    errorMessage: viewModel.autosaveErrorMessage
                )
            },
            addSegmentAfter: viewModel.addSegmentAfter,
            splitSegment: viewModel.splitSegment,
            mergeWithNextSegment: viewModel.mergeWithNextSegment,
            deleteSegment: viewModel.deleteSegment,
            createShortFromSelectedCues: viewModel.createShortFromSelectedCues,
            beginTextEdit: viewModel.beginSubtitleTextEdit,
            endTextEdit: viewModel.endSubtitleTextEdit,
            currentErrorMessage: { viewModel.autosaveErrorMessage }
        )
        self.shortsWorkspaceActions = ShortsWorkspaceActions(
            selectShort: { viewModel.shortsSelectedShortID = $0 },
            addShortAtPlayhead: viewModel.addShortAtPlayhead,
            deleteShort: viewModel.deleteShort,
            updateShort: { id, undoActionName, mutate in
                viewModel.updateShort(
                    id: id,
                    undoActionName: undoActionName,
                    mutate: mutate
                )
            },
            beginInteractiveShortEdit: viewModel.beginInteractiveShortEdit,
            endInteractiveShortEdit: viewModel.endInteractiveShortEdit,
            addCropPointAtPlayhead: viewModel.addCropPointAtPlayhead,
            updateShortCropOffset: { id, timelineTimeMs, offsetX in
                viewModel.updateShortCropOffset(
                    id: id,
                    timelineTimeMs: timelineTimeMs,
                    offsetX: offsetX
                )
            },
            deleteShortCropKeyframe: { shortID, keyframeID in
                viewModel.deleteShortCropKeyframe(
                    shortID: shortID,
                    keyframeID: keyframeID
                )
            },
            updateExportSettings: viewModel.updateShortsExportSettings,
            updateSubtitleStyle: { style, registerUndo in
                viewModel.updateShortsSubtitleStyle(style, registerUndo: registerUndo)
            },
            beginInteractiveSubtitleStyleEdit: viewModel.beginInteractiveShortsSubtitleStyleEdit,
            endInteractiveSubtitleStyleEdit: viewModel.endInteractiveShortsSubtitleStyleEdit,
            generateSuggestions: viewModel.generateShortsSuggestions,
            acceptSuggestion: viewModel.acceptShortSuggestion,
            dismissSuggestion: viewModel.dismissShortSuggestion,
            exportShorts: viewModel.exportShorts
        )
        self.subtitleExportOptionsActions = SubtitleExportOptionsActions(
            update: viewModel.updateSpeakerExportOptions
        )
    }

    var body: some View {
        ProjectView(
            viewModel: viewModel,
            projectMode: $projectMode,
            components: components,
            subtitleEditorActions: subtitleEditorActions,
            shortsWorkspaceActions: shortsWorkspaceActions,
            subtitleExportOptionsActions: subtitleExportOptionsActions
        )
        .environmentObject(appState)
    }
}
