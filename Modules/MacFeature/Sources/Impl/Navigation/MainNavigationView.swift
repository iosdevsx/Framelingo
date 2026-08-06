import Application
import DesignSystem
import ExportFeatureImpl
import ExportFeature
import HomeFeature
import HomeFeatureImpl
import MacFeature
import Project
import ProjectFeature
import ProjectFeatureImpl
import SettingsFeatureImpl
import SubtitleEditorFeature
import SwiftUI

struct MainNavigationView: View {
    @EnvironmentObject private var appState: AppState
    let dependencies: MacFeatureDependencies

    @StateObject private var shell: MacProductShell
    @State private var selectedSpeakerID: String? = nil
    @State private var showShortcuts = false
    private let activeProjectExportSettings: any ActiveProjectExportSettingsManaging
    private let subtitleDocumentPicker: SubtitleDocumentPicker
    private let activityOverlay: AnyView

    @AppStorage("Framelingo.subtitleLayout") private var subtitleLayout: SubtitleLayoutMode = .split
    @AppStorage("Framelingo.showTranslation") private var showTranslation: Bool = false
    @AppStorage("Framelingo.showWarnings") private var showWarnings: Bool = false
    @AppStorage("Framelingo.density") private var density: EditorDensity = .comfy
    @AppStorage("Framelingo.accentColorName") private var accentColorName: String = AccentColorName.blue.rawValue
    @AppStorage("Framelingo.sidebarCollapsed") private var sidebarCollapsed: Bool = false

    init(dependencies: MacFeatureDependencies) {
        self.dependencies = dependencies
        let shell = MacProductShell(
            selectedProject: dependencies.mockProject,
            preparedMediaCleanup: dependencies.preparedMediaCleanup,
            projectCatalog: dependencies.projectCatalog
        )
        _shell = StateObject(wrappedValue: shell)
        activeProjectExportSettings = ShellActiveProjectExportSettingsAdapter(
            shell: shell,
            projectRepository: dependencies.projectRepository,
            projectCatalog: dependencies.projectCatalog
        )
        subtitleDocumentPicker = AppKitSubtitleDocumentPickerAdapter().port

        let activitySource = AppStateActivitySourceAdapter(appState: dependencies.appState).source
        activityOverlay = ExportFeatureAssembly.makeActivityOverlay(
            source: activitySource,
            outputRevealer: AppKitOutputRevealAdapter().port,
            diagnosticCopier: AppKitDiagnosticCopyAdapter().port
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                project: shell.selectedProject,
                workspaceMode: $shell.workspaceMode,
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
        .alert(
            "Project Error",
            isPresented: Binding(
                get: { shell.failure != nil },
                set: { if !$0 { shell.clearFailure() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shell.failure?.message ?? "")
        }
        .sheet(isPresented: $showShortcuts) {
            KeyboardShortcutsSheet()
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if shell.workspaceMode == .settings {
            SettingsFeatureAssembly.makeView(
                settingsAccess: dependencies.settingsAccess,
                activeProjectExportSettings: activeProjectExportSettings,
                whisperInstaller: dependencies.whisperModelManager,
                parakeetModelStore: dependencies.parakeetModelManager,
                usesEmbeddedVideoRenderingBackend: dependencies.usesEmbeddedVideoRenderingBackend,
                makeFFmpegService: dependencies.makeFFmpegService,
                fileManager: dependencies.fileManager
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if shell.hasOpenedProject && shell.selectedProject != nil {
            ZStack(alignment: .topTrailing) {
                ProjectFeatureAssembly.makeView(
                    appState: appState,
                    dependencies: ProjectFeatureDependencies(
                        projectRepository: dependencies.projectRepository,
                        projectCatalog: dependencies.projectCatalog,
                        settingsAccess: dependencies.settingsAccess,
                        subtitleImporter: dependencies.subtitleImporter,
                        projectFileService: dependencies.projectFileService,
                        editTimelineService: dependencies.editTimelineService,
                        projectPreparationWorkflow: dependencies.projectPreparationWorkflow,
                        projectTranscriptionWorkflow: dependencies.projectTranscriptionWorkflow,
                        projectTranslationWorkflow: dependencies.projectTranslationWorkflow,
                        selection: shell.selectionAccess,
                        subtitleDocumentPicker: subtitleDocumentPicker
                    ),
                    projectMode: $shell.projectMode,
                    components: dependencies.projectFeatureComponents
                )
                .id(shell.selectedProject?.id)

                activityOverlay
                    .padding(.top, 58)
                    .padding(.trailing, 16)
            }
        } else {
            HomeFeatureAssembly.makeView(
                projectCatalog: dependencies.projectCatalog,
                projectRepository: dependencies.projectRepository,
                projectFileService: dependencies.projectFileService,
                mediaMetadataService: dependencies.mediaMetadataProvider,
                fileManager: dependencies.fileManager,
                mockProject: dependencies.mockProject,
                mockSubtitles: dependencies.mockSubtitles,
                projectOpening: HomeProjectOpening(open: shell.open)
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
