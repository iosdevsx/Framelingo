import DesignSystem
import SwiftUI

struct MainNavigationView: View {
    private let runtime: MacAppWorkspaceRuntime
    private let screens: MacAppScreenFactories

    @StateObject private var shell: MacProductShell
    @State private var selectedSpeakerID: String?
    @State private var showShortcuts = false

    @AppStorage("Framelingo.subtitleLayout") private var subtitleLayout: SubtitleLayoutMode = .split
    @AppStorage("Framelingo.showTranslation") private var showTranslation = false
    @AppStorage("Framelingo.showWarnings") private var showWarnings = false
    @AppStorage("Framelingo.density") private var density: EditorDensity = .comfy
    @AppStorage("Framelingo.accentColorName") private var accentColorName = AccentColorName.blue.rawValue
    @AppStorage("Framelingo.sidebarCollapsed") private var sidebarCollapsed = false

    init(graph: MacAppNavigationGraph) {
        runtime = graph.runtime
        screens = graph.screens
        _shell = StateObject(wrappedValue: graph.runtime.shell)
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                project: runtime.session.snapshot.project,
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
            screens.makeSettings()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if shell.hasOpenedProject && runtime.session.snapshot.project != nil {
            ZStack(alignment: .topTrailing) {
                screens.makeProject($shell.projectMode)
                    .id(shell.selectedProjectID)

                screens.activityOverlay
                    .padding(.top, 58)
                    .padding(.trailing, 16)
            }
        } else {
            screens.makeHome()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct KeyboardShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.escape)
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
