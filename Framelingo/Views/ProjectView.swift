import AVFoundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProjectView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject var viewModel: ProjectViewModel
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var isPlaying = false
    @State private var alertMessage: String?
    @State private var mp4SuccessPath: String?
    @State private var mp4FailureResult: MP4ExportResult?
    @State private var exportVideoViewModel: ExportVideoViewModel?
    @State private var pendingSubtitleExportKind: SubtitleExportKind?
    @State private var accessedMediaURL: URL?
    @State private var timelineHeight = 180.0
    @Binding var projectMode: ProjectWorkspaceMode
    @State private var editPlaybackClipID: UUID?
    @AppStorage("Framelingo.timelineHeight") private var persistedTimelineHeight = 180.0
    @AppStorage("Framelingo.subtitleLayout") private var subtitleLayout: SubtitleLayoutMode = .split
    @State private var subtitleTimelineZoom = 1.0
    @State private var editTimelineZoom = 1.0
    @State private var showsSubtitleWaveform = true
    @State private var subtitleScrollToPlayheadRequest = 0
    @FocusState private var focusedEditorField: SubtitleEditorFocus?

    private let subtitleTimelineWaveformHeight = 74.0
    private let waveformToggleAnimation = Animation.smooth(duration: 0.28)

    var body: some View {
        Group {
            if let project = viewModel.project {
                projectContent(project)
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "film",
                    description: Text("Create or select a project from Home.")
                )
            }
        }
        .onAppear {
            timelineHeight = persistedTimelineHeight
            viewModel.loadSelectedProject()
            viewModel.prepareProjectForEditing()
            configurePlayerIfNeeded()
        }
        .onChange(of: viewModel.project?.id) { _, _ in
            viewModel.prepareProjectForEditing()
            configurePlayerIfNeeded()
        }
        .onChange(of: projectMode) { _, mode in
            if mode == .edit {
                viewModel.ensureEditTimeline()
                viewModel.pauseTimeline()
                isPlaying = false
                player?.pause()
            }
        }
        .onChange(of: focusedEditorField) { oldValue, newValue in
            if oldValue?.textEditSegmentID != newValue?.textEditSegmentID {
                viewModel.endSubtitleTextEdit()
            }

            if let segmentID = newValue?.textEditSegmentID {
                viewModel.beginSubtitleTextEdit(id: segmentID)
            }
        }
        .onDisappear {
            viewModel.endSubtitleTextEdit()
            removeTimeObserver()
            stopAccessingMediaURL()
        }
        .alert("Subtitle Error", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .alert("MP4 Export Complete", isPresented: mp4SuccessAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Saved to:\n\(mp4SuccessPath ?? "")")
        }
        .sheet(item: $mp4FailureResult) { result in
            MP4ExportResultView(result: result)
        }
        .sheet(item: $exportVideoViewModel) { exportViewModel in
            ExportVideoSheet(viewModel: exportViewModel) { exportViewModel in
                guard let outputURL = exportViewModel.outputURL else {
                    return
                }

                appState.enqueueVideoExport(
                    project: exportViewModel.project,
                    settings: exportViewModel.settings,
                    outputURL: outputURL
                )
            }
        }
        .sheet(item: $pendingSubtitleExportKind) { kind in
            if let project = viewModel.project {
                SubtitleExportOptionsSheet(
                    project: project,
                    viewModel: viewModel,
                    kind: kind,
                    onCancel: {
                        pendingSubtitleExportKind = nil
                    },
                    onExport: {
                        showSavePanel(for: kind)
                        pendingSubtitleExportKind = nil
                    }
                )
            }
        }
        .sheet(item: $viewModel.subtitleImportPreview) { preview in
            SubtitleImportPreviewSheet(
                preview: preview,
                hasExistingSubtitles: viewModel.project?.subtitles.isEmpty == false,
                onCancel: {
                    viewModel.subtitleImportPreview = nil
                },
                onImport: { mode, destination in
                    viewModel.applySubtitleImport(preview, mode: mode, destination: destination)
                }
            )
        }
        .onChange(of: viewModel.exportMessage) { _, message in
            alertMessage = message
            viewModel.exportMessage = nil
        }
        .onChange(of: viewModel.subtitleImportErrorMessage) { _, message in
            alertMessage = message
            viewModel.subtitleImportErrorMessage = nil
        }
        .onChange(of: viewModel.mp4ExportResult) { _, result in
            switch result {
            case .success(let outputPath):
                mp4SuccessPath = outputPath
            case .failure:
                mp4FailureResult = result
            case nil:
                break
            }
            viewModel.mp4ExportResult = nil
        }
        .background(shortcutButtons)
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    alertMessage = nil
                }
            }
        )
    }

    private var mp4SuccessAlertBinding: Binding<Bool> {
        Binding(
            get: { mp4SuccessPath != nil },
            set: { isPresented in
                if !isPresented {
                    mp4SuccessPath = nil
                }
            }
        )
    }

    private func projectContent(_ project: Project) -> some View {
        if viewModel.isPreparingProject || viewModel.projectPreparationProgress < 1 {
            return AnyView(ProjectPreparationView(
                projectName: project.displayName,
                progress: viewModel.projectPreparationProgress,
                status: viewModel.projectPreparationStatus
            ))
        }

        return AnyView(VStack(spacing: 0) {
            ProjectToolbarView(
                project: project,
                viewModel: viewModel,
                onExportVideo: {
                    guard !project.hasEditedTimeline else {
                        alertMessage = "Edited timeline export is not implemented yet."
                        return
                    }

                    exportVideoViewModel = viewModel.makeExportVideoViewModel(for: project)
                },
                onExportProjectFile: {
                    showProjectSavePanel(project)
                },
                onExportSubtitles: { kind in
                    pendingSubtitleExportKind = kind
                }
            )

            Divider()

            GeometryReader { geometry in
                let currentTimelineHeight = clampedTimelineHeight(for: geometry.size.height)

                Group {
                    switch projectMode {
                    case .subtitles:
                        subtitleWorkspace(project, geometry: geometry, timelineHeight: currentTimelineHeight)
                    case .edit:
                        editWorkspace(project, geometry: geometry, timelineHeight: currentTimelineHeight)
                    }
                }
            }
        })
    }

    private func subtitleWorkspace(
        _ project: Project,
        geometry: GeometryProxy,
        timelineHeight: Double
    ) -> some View {
        let visibleTimelineHeight = showsSubtitleWaveform
            ? timelineHeight
            : max(76, timelineHeight - subtitleTimelineWaveformHeight)

        return VStack(spacing: 0) {
            subtitleWorkspaceContent(project, height: max(260, geometry.size.height - visibleTimelineHeight - 43))

            timelineResizeHandle(totalHeight: geometry.size.height)

            unifiedTimelineToolbar(project)

            SubtitleTimelineView(
                subtitles: subtitlesBinding(project),
                selectedSegmentID: selectedSegmentBinding,
                currentTimeMs: viewModel.currentTimeMs,
                durationMs: viewModel.timelineDurationMs(for: project),
                waveformPeaks: viewModel.waveformPeaks,
                speakers: project.speakers,
                zoomFactor: $subtitleTimelineZoom,
                scrollToPlayheadRequest: $subtitleScrollToPlayheadRequest,
                showsWaveform: $showsSubtitleWaveform,
                onSeek: { seek(to: $0) },
                onBeginTextEditing: { viewModel.beginSubtitleTextEdit(id: $0) },
                onTranslatedTextChange: { viewModel.updateTimelineTranslatedText(segmentID: $0, text: $1) },
                onEndTextEditing: { viewModel.endSubtitleTextEdit() }
            )
            .frame(height: visibleTimelineHeight)
        }
        .clipped()
        .animation(waveformToggleAnimation, value: showsSubtitleWaveform)
    }

    @ViewBuilder
    private func subtitleWorkspaceContent(_ project: Project, height: CGFloat) -> some View {
        switch subtitleLayout {
        case .split:
            HSplitView {
                videoPreview(project, showsControls: false)
                    .frame(minWidth: 320, idealWidth: 540, minHeight: 260)
                editorPaneView(project)
                    .frame(minWidth: 260, minHeight: 260)
                cueListView(project)
                    .frame(minWidth: 300, minHeight: 260)
            }
            .frame(height: height)

        case .videoFocus:
            HSplitView {
                videoPreview(project, showsControls: false)
                    .frame(minWidth: 420, idealWidth: 680, minHeight: 260)
                VStack(spacing: 0) {
                    cueListView(project)
                        .frame(minHeight: 120)
                    Divider()
                    editorPaneView(project)
                        .frame(minHeight: 120)
                }
                .frame(minWidth: 280, minHeight: 260)
            }
            .frame(height: height)

        case .transcript:
            HSplitView {
                VStack(spacing: 0) {
                    videoPreview(project, showsControls: false)
                        .frame(minHeight: 120)
                    Divider()
                    editorPaneView(project)
                        .frame(minHeight: 120)
                }
                .frame(minWidth: 280, minHeight: 260)
                cueListView(project)
                    .frame(minWidth: 400, idealWidth: 620, minHeight: 260)
            }
            .frame(height: height)
        }
    }

    private func cueListView(_ project: Project) -> some View {
        CueListView(
            project: project,
            viewModel: viewModel,
            focusedField: $focusedEditorField,
            onSeek: { seek(to: $0) },
            onError: { alertMessage = $0 }
        )
        .padding(4)
    }

    private func editorPaneView(_ project: Project) -> some View {
        EditorPaneView(
            project: project,
            viewModel: viewModel,
            onSeek: { seek(to: $0) }
        )
        .padding(4)
    }

    private func editWorkspace(
        _ project: Project,
        geometry: GeometryProxy,
        timelineHeight: Double
    ) -> some View {
        VStack(spacing: 0) {
            videoPreview(project, showsControls: false)
                .frame(maxWidth: .infinity, minHeight: 260)
                .frame(height: max(260, geometry.size.height - timelineHeight - 43))

            timelineResizeHandle(totalHeight: geometry.size.height)

            unifiedTimelineToolbar(project)

            if let timeline = viewModel.resolvedEditTimeline(for: project), !timeline.isEmpty {
                EditTimelineView(
                    timeline: timeline,
                    subtitles: project.subtitles,
                    selectedClipID: Binding(
                        get: { viewModel.editModeSelectedClipID },
                        set: { viewModel.editModeSelectedClipID = $0 }
                    ),
                    currentTimeMs: viewModel.currentTimeMs,
                    rangeStartMs: viewModel.editRangeStartMs,
                    rangeEndMs: viewModel.editRangeEndMs,
                    onSeek: { seekEdit(to: $0) },
                    onSelectClip: { viewModel.editModeSelectedClipID = $0 },
                    zoomFactor: $editTimelineZoom
                )
                .frame(height: timelineHeight)
            } else {
                ContentUnavailableView(
                    "Video duration is unknown.",
                    systemImage: "timeline.selection",
                    description: Text("Open the video first.")
                )
                .frame(height: timelineHeight)
            }
        }
    }

    private func unifiedTimelineToolbar(_ project: Project) -> some View {
        let durationMs: Int? = projectMode == .edit ? viewModel.timelineDurationMs(for: project) : project.mediaFile.durationMs
        return ProjectPlaybackToolbarView(
            mode: projectMode,
            currentTimeMs: viewModel.currentTimeMs,
            durationMs: durationMs,
            isPlaying: isPlaying,
            viewModel: viewModel,
            onSeekToStart: {
                seekEdit(to: 0)
            },
            onTogglePlayback: {
                togglePlayback()
            },
            onScrollToPlayhead: {
                subtitleScrollToPlayheadRequest += 1
            },
            onRippleDelete: {
                pauseEditPlayback()
                viewModel.rippleDeleteSelectedRange()
                seekEdit(to: viewModel.currentTimeMs)
            },
            onCut: {
                viewModel.splitAtCurrentTime()
            },
            onDeleteClip: {
                pauseEditPlayback()
                viewModel.deleteSelectedClip()
                seekEdit(to: viewModel.currentTimeMs)
            },
            onZoomOut: {
                if projectMode == .edit {
                    editTimelineZoom = max(0.35, editTimelineZoom / 1.35)
                } else {
                    subtitleTimelineZoom = max(0.35, subtitleTimelineZoom / 1.35)
                }
            },
            onZoomIn: {
                if projectMode == .edit {
                    editTimelineZoom = min(6, editTimelineZoom * 1.35)
                } else {
                    subtitleTimelineZoom = min(6, subtitleTimelineZoom * 1.35)
                }
            },
            onFitZoom: {
                subtitleTimelineZoom = 1.0
                editTimelineZoom = 1.0
            }
        )
    }

    private func videoPreview(_ project: Project, showsControls: Bool = true) -> some View {
        ProjectVideoPreview(
            project: project,
            player: player,
            isPlaying: isPlaying,
            currentTimeMs: viewModel.currentTimeMs,
            showsControls: showsControls,
            onTogglePlayback: {
                togglePlayback()
            },
            onUpdateSettings: { settings, registerUndo in
                viewModel.updateVideoExportSettings(settings, registerUndo: registerUndo)
            }
        )
    }

    private func clampedTimelineHeight(for totalHeight: Double) -> Double {
        let maxHeight = max(150, totalHeight - 280)
        return min(max(timelineHeight, 150), min(420, maxHeight))
    }

    private func timelineResizeHandle(totalHeight: Double) -> some View {
        TimelineResizeHandle(
            height: $timelineHeight,
            totalHeight: totalHeight,
            onCommit: { persistedTimelineHeight = $0 }
        )
        .frame(height: 7)
    }

    private func subtitleEditor(_ project: Project) -> some View {
        SubtitleEditorView(
            project: project,
            viewModel: viewModel,
            focusedField: $focusedEditorField,
            onSeek: { seek(to: $0) },
            onError: { alertMessage = $0 }
        )
    }

    private func configurePlayerIfNeeded() {
        guard let mediaURL = viewModel.project?.mediaFile.originalURL else {
            return
        }

        if accessedMediaURL != mediaURL {
            stopAccessingMediaURL()
            _ = mediaURL.startAccessingSecurityScopedResource()
            accessedMediaURL = mediaURL
        }

        removeTimeObserver()
        player = AVPlayer(url: mediaURL)
        addTimeObserver()
        viewModel.seekTo(ms: 0)
        editPlaybackClipID = nil
        isPlaying = false
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let sourceMilliseconds = Int((time.seconds * 1_000).rounded())
            Task { @MainActor in
                if projectMode == .edit, isPlaying {
                    handleEditPlaybackTick(sourceTimeMs: sourceMilliseconds)
                } else if projectMode == .subtitles {
                    viewModel.seekTo(ms: sourceMilliseconds)
                }
            }
        }
    }

    private func removeTimeObserver() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private func stopAccessingMediaURL() {
        accessedMediaURL?.stopAccessingSecurityScopedResource()
        accessedMediaURL = nil
    }

    private func togglePlayback() {
        if projectMode == .edit {
            toggleEditPlayback()
            return
        }

        guard let player else {
            return
        }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }

        isPlaying.toggle()
    }

    private func seek(to milliseconds: Int) {
        let time = CMTime(seconds: Double(milliseconds) / 1_000, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        viewModel.seekTo(ms: milliseconds)
    }

    private func seekEdit(to milliseconds: Int) {
        let timelineDuration = viewModel.project.map { viewModel.timelineDurationMs(for: $0) } ?? 0
        let timelineMs = min(max(milliseconds, 0), timelineDuration)
        viewModel.seekTimeline(to: timelineMs)

        guard let sourceTimeMs = viewModel.timelineTimeToSourceTime(timelineMs) else {
            return
        }

        let time = CMTime(seconds: Double(sourceTimeMs) / 1_000, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        editPlaybackClipID = viewModel.editClip(atTimelineTime: timelineMs)?.id
    }

    private func toggleEditPlayback() {
        if isPlaying {
            pauseEditPlayback()
            return
        }

        guard player != nil else {
            return
        }

        guard let sourceTimeMs = viewModel.timelineTimeToSourceTime(viewModel.currentTimeMs) else {
            seekEdit(to: 0)
            return
        }

        editPlaybackClipID = viewModel.editClip(atTimelineTime: viewModel.currentTimeMs)?.id
        let time = CMTime(seconds: Double(sourceTimeMs) / 1_000, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            Task { @MainActor in
                viewModel.playTimeline()
                isPlaying = true
                player?.play()
            }
        }
    }

    private func pauseEditPlayback() {
        player?.pause()
        isPlaying = false
        viewModel.pauseTimeline()
    }

    private func handleEditPlaybackTick(sourceTimeMs: Int) {
        guard let advance = viewModel.editPlaybackAdvance(sourceTimeMs: sourceTimeMs, currentClipID: editPlaybackClipID) else {
            pauseEditPlayback()
            return
        }

        switch advance {
        case .paused:
            pauseEditPlayback()

        case .finished(let totalDurationMs):
            viewModel.seekTimeline(to: totalDurationMs)
            pauseEditPlayback()

        case .seekWithinClip(let timelineMs):
            viewModel.seekTimeline(to: timelineMs)

        case .advanceToNextClip(let nextClip):
            editPlaybackClipID = nextClip.id
            viewModel.seekTimeline(to: nextClip.timelineStartMs)
            let time = CMTime(seconds: Double(nextClip.sourceStartMs) / 1_000, preferredTimescale: 600)
            player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                player?.play()
            }
        }
    }

    private func selectAdjacentSegment(offset: Int) {
        guard focusedEditorField == nil,
              let subtitles = viewModel.project?.subtitles,
              !subtitles.isEmpty else {
            return
        }

        let currentIndex = viewModel.selectedSegmentID
            .flatMap { selectedID in subtitles.firstIndex(where: { $0.id == selectedID }) } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), subtitles.count - 1)
        let segment = subtitles[nextIndex]
        viewModel.selectSegment(id: segment.id)
        seek(to: segment.startMs)
    }

    private var shortcutButtons: some View {
        Group {
            Button("Toggle Playback") {
                if focusedEditorField == nil {
                    togglePlayback()
                }
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Save Project") {
                Task {
                    await viewModel.saveProject()
                }
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Export Translated SRT") {
                showSavePanel(for: .translatedSRT)
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(viewModel.project?.subtitles.isEmpty != false)

            Button("Undo") {
                viewModel.undo()
            }
            .keyboardShortcut("z", modifiers: .command)

            Button("Redo") {
                viewModel.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])

            Button("Previous Segment") {
                selectAdjacentSegment(offset: -1)
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button("Next Segment") {
                selectAdjacentSegment(offset: 1)
            }
            .keyboardShortcut(.downArrow, modifiers: [])

            Button("Edit Original Text") {
                if let selectedSegmentID = viewModel.selectedSegmentID {
                    focusedEditorField = .original(selectedSegmentID)
                }
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(viewModel.selectedSegmentID == nil)

            Button("Delete Selected Clip") {
                guard projectMode == .edit, focusedEditorField == nil else { return }
                pauseEditPlayback()
                viewModel.deleteSelectedClip()
                seekEdit(to: viewModel.currentTimeMs)
            }
            .keyboardShortcut(.delete, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private func showSavePanel(for kind: SubtitleExportKind) {
        let panel = NSSavePanel()
        panel.title = kind.title
        panel.prompt = "Export"
        panel.nameFieldStringValue = viewModel.suggestedExportFileName(for: kind)
        panel.allowedContentTypes = allowedContentTypes(for: kind)
        panel.allowsOtherFileTypes = false
        panel.isExtensionHidden = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        let exportURL = destinationURL.normalizedSubtitleExportURL(fileExtension: kind.fileExtension)

        Task {
            await viewModel.exportSubtitles(kind: kind, to: exportURL)
        }
    }

    private func showProjectSavePanel(_ project: Project) {
        let panel = NSSavePanel()
        panel.title = "Save Project File"
        panel.prompt = "Save"
        panel.nameFieldStringValue = "\(project.displayName).subtitleedit"
        panel.allowedContentTypes = projectContentTypes
        panel.allowsOtherFileTypes = false
        panel.isExtensionHidden = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        viewModel.exportProjectFile(to: destinationURL)
    }

    private func allowedContentTypes(for kind: SubtitleExportKind) -> [UTType] {
        if let type = UTType(filenameExtension: kind.fileExtension) {
            return [type]
        }

        return [.plainText]
    }

    private var projectContentTypes: [UTType] {
        [UTType(filenameExtension: "subtitleedit") ?? .json, .json]
    }

    private func subtitlesBinding(_ project: Project) -> Binding<[SubtitleSegment]> {
        Binding(
            get: { viewModel.project?.subtitles ?? project.subtitles },
            set: { viewModel.updateSubtitlesFromTimeline($0) }
        )
    }

    private var selectedSegmentBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedSegmentID },
            set: { viewModel.selectSegment(id: $0) }
        )
    }
}

private struct ProjectPreparationView: View {
    let projectName: String
    let progress: Double
    let status: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(projectName)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)

                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(max(progress, 0), 1))
                .progressViewStyle(.linear)
                .frame(width: 320)

            Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ProjectView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        ProjectView(viewModel: ProjectViewModel(appState: appState), projectMode: .constant(.subtitles))
            .environmentObject(appState)
    }
}

private extension URL {
    func normalizedSubtitleExportURL(fileExtension: String) -> URL {
        guard pathExtension.lowercased() != fileExtension.lowercased() else {
            return self
        }

        return deletingPathExtension().appendingPathExtension(fileExtension)
    }
}
