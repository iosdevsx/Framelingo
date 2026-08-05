import Application
import DesignSystem
import ExportFeatureImpl
import HomeFeatureImpl
import MacFeature
import Project
import ProjectFeature
import ProjectFeatureImpl
import SettingsFeatureImpl
import SwiftUI

struct MainNavigationView: View {
    @EnvironmentObject private var appState: AppState
    let dependencies: MacFeatureDependencies

    @State private var workspaceMode: AppWorkspaceMode = .subtitles
    @State private var projectMode: ProjectWorkspaceMode = .subtitles
    @State private var selectedSpeakerID: String? = nil
    @State private var showShortcuts = false
    // Starts on HomeView regardless of appState.selectedProject (matches original behaviour)
    @State private var hasOpenedProject: Bool = false

    @AppStorage("Framelingo.subtitleLayout") private var subtitleLayout: SubtitleLayoutMode = .split
    @AppStorage("Framelingo.showTranslation") private var showTranslation: Bool = false
    @AppStorage("Framelingo.showWarnings") private var showWarnings: Bool = false
    @AppStorage("Framelingo.density") private var density: EditorDensity = .comfy
    @AppStorage("Framelingo.accentColorName") private var accentColorName: String = AccentColorName.blue.rawValue
    @AppStorage("Framelingo.sidebarCollapsed") private var sidebarCollapsed: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                project: appState.selectedProject,
                workspaceMode: $workspaceMode,
                subtitleLayout: $subtitleLayout,
                showTranslation: $showTranslation,
                showWarnings: $showWarnings,
                selectedSpeakerID: $selectedSpeakerID,
                isCollapsed: $sidebarCollapsed,
                onShowShortcuts: { showShortcuts = true }
            )

            Divider()

            contentArea
        }
        .frame(minWidth: 900, minHeight: 600)
        .onChange(of: workspaceMode) { _, mode in
            switch mode {
            case .videoEditor: projectMode = .edit
            case .subtitles:   projectMode = .subtitles
            case .shorts:      projectMode = .shorts
            case .settings:    break
            }
        }
        .onChange(of: projectMode) { _, mode in
            // Keep the sidebar highlight in sync when a workspace switches the
            // project mode programmatically (e.g. "Create short from cue").
            switch mode {
            case .subtitles where workspaceMode != .subtitles: workspaceMode = .subtitles
            case .edit where workspaceMode != .videoEditor:    workspaceMode = .videoEditor
            case .shorts where workspaceMode != .shorts:       workspaceMode = .shorts
            default: break
            }
        }
        .onChange(of: appState.selectedProject?.id) { _, _ in
            workspaceMode = .subtitles
            projectMode = .subtitles
        }
        .sheet(isPresented: $showShortcuts) {
            KeyboardShortcutsSheet()
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if workspaceMode == .settings {
            SettingsFeatureAssembly.makeView(
                appState: appState,
                whisperInstaller: dependencies.whisperModelManager,
                parakeetModelStore: dependencies.parakeetModelManager,
                usesEmbeddedVideoRenderingBackend: dependencies.usesEmbeddedVideoRenderingBackend,
                makeFFmpegService: dependencies.projectViewModelDependencies.makeFFmpegService,
                fileManager: dependencies.fileManager
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if hasOpenedProject && appState.selectedProject != nil {
            ZStack(alignment: .topTrailing) {
                ProjectFeatureAssembly.makeView(
                    appState: appState,
                    viewModel: ProjectViewModel(
                        appState: appState,
                        dependencies: dependencies.projectViewModelDependencies
                    ),
                    projectMode: $projectMode,
                    makeExportVideoViewModel: { project in
                        ExportFeatureAssembly.makeVideoViewModel(
                            project: project,
                            settings: project.videoExportSettings,
                            ffmpegService: dependencies.projectViewModelDependencies.makeFFmpegService(appState.settings),
                            subtitleScriptGenerator: dependencies.projectViewModelDependencies.subtitleScriptGenerator,
                            mediaMetadataService: dependencies.projectViewModelDependencies.mediaMetadataProvider,
                            fileManager: dependencies.fileManager
                        )
                    }
                )
                .id(appState.selectedProject?.id)

                ExportFeatureAssembly.makeActivityOverlay(appState: appState)
                    .padding(.top, 58)
                    .padding(.trailing, 16)
            }
        } else {
            HomeFeatureAssembly.makeView(
                appState: appState,
                projectFileService: dependencies.projectFileService,
                mediaMetadataService: dependencies.projectViewModelDependencies.mediaMetadataProvider,
                fileManager: dependencies.fileManager,
                mockProject: dependencies.mockProject,
                mockSubtitles: dependencies.mockSubtitles,
                onOpenProject: { _ in
                    hasOpenedProject = true
                    workspaceMode = .subtitles
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct KeyboardShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Text("Coming soon")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400, height: 300)
    }
}
