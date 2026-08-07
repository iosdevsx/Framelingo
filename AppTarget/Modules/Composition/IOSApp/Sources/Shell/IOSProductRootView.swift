import PlayerFeature
import Project
import SubtitleEditorFeature
import SwiftUI

struct IOSProductRootView: View {
    @State private var model: IOSAppModel

    init(model: IOSAppModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            if let project = model.openedProject {
                IOSWorkspaceView(
                    model: model,
                    projectName: project.displayName,
                    preparedShareURL: model.preparedShareURL,
                    close: model.closeWorkspace,
                    save: model.saveProject,
                    prepareShare: model.prepareProjectShare
                )
            } else {
                IOSHomeView(
                    projects: model.recentProjects,
                    open: model.openRecentProject,
                    importProject: model.requestProjectImport,
                    importMedia: model.requestMediaImport
                )
            }
        }
        .task {
            await model.loadRecentProjects()
        }
        .fileImporter(
            isPresented: $model.isDocumentPickerPresented,
            allowedContentTypes: model.allowedDocumentTypes,
            allowsMultipleSelection: false
        ) { result in
            Task {
                await model.handleDocumentSelection(result)
            }
        }
        .alert(
            "Framelingo",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onDisappear {
            Task {
                await model.sceneDidClose()
            }
        }
    }
}

private struct IOSHomeView: View {
    let projects: [Project]
    let open: (UUID) async -> Void
    let importProject: () -> Void
    let importMedia: () -> Void

    var body: some View {
        List(projects) { project in
            Button {
                Task {
                    await open(project.id)
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.displayName)
                        .font(.headline)
                    Text(project.updatedAt, format: .dateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "video",
                    description: Text("Project and video import are added by the iOS adapters.")
                )
            }
        }
        .navigationTitle("Framelingo")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Open Project", systemImage: "doc", action: importProject)
                Button("Import Video", systemImage: "video.badge.plus", action: importMedia)
            }
        }
    }
}

private struct IOSWorkspaceView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let model: IOSAppModel
    let projectName: String
    let preparedShareURL: URL?
    let close: () async -> Void
    let save: () async -> Void
    let prepareShare: () async -> Void

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(spacing: 0) {
                    IOSWorkspacePlayerSection(request: model.playerRequest)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    Divider()
                    IOSWorkspaceEditorSection(
                        state: model.subtitleEditorState,
                        actions: model.subtitleEditorActions
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    IOSWorkspacePlayerSection(request: model.playerRequest)
                        .padding()
                    Divider()
                    IOSWorkspaceEditorSection(
                        state: model.subtitleEditorState,
                        actions: model.subtitleEditorActions
                    )
                        .frame(maxHeight: .infinity)
                }
            }
        }
        .navigationTitle(projectName)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Projects", systemImage: "chevron.backward") {
                    Task { await close() }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu("Process", systemImage: "waveform") {
                    Button("Prepare Media", systemImage: "film") {
                        Task { @MainActor in await model.prepareMedia() }
                    }
                    Button("Transcribe", systemImage: "captions.bubble") {
                        Task { @MainActor in await model.transcribe() }
                    }
                    Button("Translate", systemImage: "character.bubble") {
                        Task { @MainActor in await model.translate() }
                    }
                }
                Button("Save", systemImage: "square.and.arrow.down") {
                    Task { await save() }
                }
                if let preparedShareURL {
                    ShareLink(item: preparedShareURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button("Prepare Share", systemImage: "square.and.arrow.up") {
                        Task { await prepareShare() }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            IOSProcessingStatusView(state: model.processingPresentation)
        }
    }

}

private struct IOSProcessingStatusView: View {
    let state: IOSProcessingPresentationState

    var body: some View {
        HStack(spacing: 10) {
            if state.isRunning {
                if let fraction = state.fractionCompleted {
                    ProgressView(value: fraction)
                        .frame(maxWidth: 120)
                } else {
                    ProgressView()
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.caption.weight(.semibold))
                if let detail = state.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .accessibilityElement(children: .combine)
    }
}

private struct IOSWorkspacePlayerSection: View {
    let request: ProjectVideoPreviewRequest?

    var body: some View {
        if let request {
            IOSPlayerView(request: request)
                .padding()
        } else {
            ContentUnavailableView(
                "Video Unavailable",
                systemImage: "video.slash",
                description: Text("Reopen the project or select its source video.")
            )
        }
    }
}

private struct IOSWorkspaceEditorSection: View {
    let state: SubtitleEditorState
    let actions: SubtitleEditorActions

    var body: some View {
        IOSSubtitleEditorView(
            state: state,
            actions: actions
        )
    }
}
