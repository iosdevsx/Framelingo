import Combine
import DesignSystem
import ExportFeatureImpl
import ExportFeature
import HomeFeature
import HomeFeatureImpl
import MacFeature
import Project
import ProjectFeature
import ProjectFeatureImpl
import ProjectSession
import ProjectSessionImpl
import SettingsFeatureImpl
import SpeechToText
import SubtitleEditorFeature
import SwiftUI
import TranscriptionPipeline

struct MainNavigationView: View {
    let dependencies: MacFeatureDependencies

    @StateObject private var shell: MacProductShell
    @State private var selectedSpeakerID: String? = nil
    @State private var showShortcuts = false
    private let activeProjectExportSettings: any ActiveProjectExportSettingsManaging
    private let subtitleDocumentPicker: SubtitleDocumentPicker
    private let activityOverlay: AnyView
    private let projectSession: DefaultProjectSession
    private let projectSessionProjection: AnyCancellable

    @AppStorage("Framelingo.subtitleLayout") private var subtitleLayout: SubtitleLayoutMode = .split
    @AppStorage("Framelingo.showTranslation") private var showTranslation: Bool = false
    @AppStorage("Framelingo.showWarnings") private var showWarnings: Bool = false
    @AppStorage("Framelingo.density") private var density: EditorDensity = .comfy
    @AppStorage("Framelingo.accentColorName") private var accentColorName: String = AccentColorName.blue.rawValue
    @AppStorage("Framelingo.sidebarCollapsed") private var sidebarCollapsed: Bool = false

    init(dependencies: MacFeatureDependencies) {
        self.dependencies = dependencies
        let projectSession = DefaultProjectSession(dependencies: ProjectSessionDependencies(
            repository: dependencies.projectRepository,
            historyLimit: 200,
            editTimelineService: dependencies.editTimelineService,
            effects: ProjectSessionEffectDependencies(
                projectPreparer: dependencies.projectPreparer,
                preparationConfiguration: dependencies.projectPreparationConfiguration,
                projectTranscriber: dependencies.projectTranscriber,
                transcriptionConfiguration: {
                    let settings = dependencies.settingsAccess.snapshot.settings
                    return TranscriptionPipelineConfiguration(
                        ffmpegExecutablePath: settings.ffmpegPath,
                        speechToText: SpeechToTextProviderConfiguration(
                            providerName: settings.speechToTextProviderName,
                            whisperExecutableURL: Self.fileURL(from: settings.whisperExecutablePath),
                            whisperModelURL: Self.fileURL(from: settings.whisperModelPath),
                            whisperModelName: settings.whisperModelName,
                            whisperVADEnabled: settings.whisperVADEnabled,
                            whisperVADModelURL: Self.fileURL(from: settings.whisperVADModelPath)
                        )
                    )
                },
                projectTranslator: dependencies.projectTranslator,
                subtitleImporter: dependencies.subtitleImporter,
                subtitleExporter: dependencies.subtitleExportService,
                projectFileService: dependencies.projectFileService,
                videoExportQueue: dependencies.videoExportQueue
            )
        ))
        self.projectSession = projectSession
        let shell = MacProductShell(
            selectedProject: dependencies.mockProject,
            preparedMediaCleanup: dependencies.preparedMediaCleanup,
            projectCatalog: dependencies.projectCatalog,
            closeWorkspace: projectSession.close
        )
        _shell = StateObject(wrappedValue: shell)
        activeProjectExportSettings = SessionActiveProjectExportSettingsAdapter(
            session: projectSession
        )
        subtitleDocumentPicker = AppKitSubtitleDocumentPickerAdapter().port
        projectSessionProjection = projectSession.snapshots
            .compactMap(\.project)
            .sink { [weak shell] project in
                shell?.refreshSummary(from: project)
                dependencies.projectCatalog.register(project)
            }

        let activitySource = CapabilityActivitySourceAdapter(
            session: projectSession,
            videoExportQueue: dependencies.videoExportQueue
        ).source
        activityOverlay = ExportFeatureAssembly.makeActivityOverlay(
            source: activitySource,
            outputRevealer: AppKitOutputRevealAdapter().port,
            diagnosticCopier: AppKitDiagnosticCopyAdapter().port
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                project: projectSession.snapshot.project,
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
        } else if shell.hasOpenedProject && projectSession.snapshot.project != nil {
            ZStack(alignment: .topTrailing) {
                ProjectFeatureAssembly.makeView(
                    dependencies: ProjectFeatureDependencies(
                        session: projectSession,
                        subtitleDocumentPicker: subtitleDocumentPicker
                    ),
                    projectMode: $shell.projectMode,
                    components: dependencies.projectFeatureComponents
                )
                .id(shell.selectedProjectID)

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
                projectOpening: HomeProjectOpening(open: { project in
                    shell.open(project)
                    projectSession.open(project)
                })
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private static func fileURL(from path: String) -> URL? {
        let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
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
