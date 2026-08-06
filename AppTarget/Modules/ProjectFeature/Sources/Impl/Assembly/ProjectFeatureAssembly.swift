import ExportFeature
import ProjectFeature
import ProjectSession
import ShortsFeature
import SubtitleEditorFeature
import SwiftUI

public enum ProjectFeatureAssembly {
    @MainActor
    public static func makeView(
        dependencies: ProjectFeatureDependencies,
        projectMode: Binding<ProjectWorkspaceMode>,
        components: ProjectFeatureComponents
    ) -> some View {
        ProjectFeatureRootView(
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

    private let components: ProjectFeatureComponents

    init(
        dependencies: ProjectFeatureDependencies,
        projectMode: Binding<ProjectWorkspaceMode>,
        components: ProjectFeatureComponents
    ) {
        _viewModel = StateObject(
            wrappedValue: ProjectViewModel(dependencies: dependencies)
        )
        _projectMode = projectMode
        self.components = components
    }

    private var subtitleEditorActions: SubtitleEditorActions {
        let editing = viewModel.subtitleEditingPort
        let observing = viewModel.sessionObservingPort
        let selection = viewModel.selectionPlaybackPort
        let history = viewModel.historyPort
        let shortsEditing = viewModel.shortsEditingPort
        return SubtitleEditorActions(
            selectSegment: { id, extending, toggling in
                selection.selectCue(id: id, extending: extending, toggling: toggling)
            },
            updateSubtitle: { segment in
                let result = editing.updateSubtitle(segment)
                return SubtitleEditorUpdateResult(
                    segment: observing.snapshot.project?.subtitles.first(where: { $0.id == segment.id }),
                    errorMessage: result.message
                )
            },
            addSegmentAfter: { editing.addSegmentAfter(id: $0).selectedID },
            splitSegment: { editing.splitSegment(id: $0).selectedID },
            mergeWithNextSegment: { editing.mergeWithNextSegment(id: $0).selectedID },
            deleteSegment: { editing.deleteSegment(id: $0).selectedID },
            createShortFromSelectedCues: {
                if shortsEditing.createShortFromSelectedCues().didChange {
                    projectMode = .shorts
                }
            },
            beginTextEdit: { _ in history.beginInteraction(named: "subtitle-text") },
            endTextEdit: { history.endInteraction(named: "subtitle-text") },
            currentErrorMessage: { viewModel.autosaveErrorMessage }
        )
    }

    private var shortsWorkspaceActions: ShortsWorkspaceActions {
        let editing = viewModel.shortsEditingPort
        let observing = viewModel.sessionObservingPort
        let history = viewModel.historyPort
        return ShortsWorkspaceActions(
            selectShort: { editing.selectShort(id: $0) },
            addShortAtPlayhead: { _ = editing.addShortAtPlayhead() },
            deleteShort: { _ = editing.deleteShort(id: $0) },
            updateShort: { id, undoActionName, mutate in
                guard var short = observing.snapshot.project?.shorts.first(where: { $0.id == id }) else { return }
                mutate(&short)
                _ = editing.replaceShort(short)
            },
            beginInteractiveShortEdit: { history.beginInteraction(named: "short-edit") },
            endInteractiveShortEdit: { _ in history.endInteraction(named: "short-edit") },
            addCropPointAtPlayhead: { _ = editing.addCropPointAtPlayhead(shortID: $0) },
            updateShortCropOffset: { id, timelineTimeMs, offsetX in
                _ = editing.updateShortCropOffset(id: id, timelineTimeMs: timelineTimeMs, offsetX: offsetX)
            },
            deleteShortCropKeyframe: { shortID, keyframeID in
                _ = editing.deleteShortCropKeyframe(shortID: shortID, keyframeID: keyframeID)
            },
            updateExportSettings: { _ = editing.updateShortsExportSettings($0) },
            updateSubtitleStyle: { style, registerUndo in
                _ = editing.updateShortsSubtitleStyle(style, undoable: registerUndo)
            },
            beginInteractiveSubtitleStyleEdit: { history.beginInteraction(named: "shorts-subtitle-style") },
            endInteractiveSubtitleStyleEdit: { _ in history.endInteraction(named: "shorts-subtitle-style") },
            generateSuggestions: editing.generateShortsSuggestions,
            acceptSuggestion: { _ = editing.acceptShortSuggestion(id: $0.id) },
            dismissSuggestion: { editing.dismissShortSuggestion(id: $0.id) },
            exportShorts: viewModel.exportShorts
        )
    }

    private var subtitleExportOptionsActions: SubtitleExportOptionsActions {
        let editing = viewModel.subtitleEditingPort
        return SubtitleExportOptionsActions(
            update: { _ = editing.updateSpeakerExportOptions($0) }
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
    }
}
