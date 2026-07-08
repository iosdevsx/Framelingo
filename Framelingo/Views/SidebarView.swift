import SwiftUI

struct SidebarView: View {
    let project: Project?
    @Binding var workspaceMode: AppWorkspaceMode
    @Binding var subtitleLayout: SubtitleLayoutMode
    @Binding var showTranslation: Bool
    @Binding var showWarnings: Bool
    @Binding var selectedSpeakerID: String?
    @Binding var isCollapsed: Bool
    let onShowShortcuts: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Group {
            if isCollapsed {
                collapsedSidebar
            } else {
                expandedSidebar
            }
        }
        .background(.ultraThinMaterial)
    }

    private var expandedSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            projectHeader
            Divider().opacity(0.5)
            scrollContent
            Divider().opacity(0.5)
            footer
        }
        .frame(width: 220)
    }

    private var collapsedSidebar: some View {
        VStack(spacing: 10) {
            collapseButton(systemName: "sidebar.left", help: "Show sidebar")
                .padding(.top, 42)

            Divider().opacity(0.5)

            VStack(spacing: 6) {
                CollapsedSidebarItem(
                    icon: "captions.bubble",
                    isSelected: workspaceMode == .subtitles,
                    help: "Subtitles",
                    action: { workspaceMode = .subtitles }
                )
                CollapsedSidebarItem(
                    icon: "scissors",
                    isSelected: workspaceMode == .videoEditor,
                    help: "Video editor",
                    action: { workspaceMode = .videoEditor }
                )
                CollapsedSidebarItem(
                    icon: "gearshape",
                    isSelected: workspaceMode == .settings,
                    help: "Settings",
                    action: { workspaceMode = .settings }
                )

                Divider().opacity(0.5).padding(.vertical, 4)

                CollapsedSidebarItem(
                    icon: "exclamationmark.triangle",
                    isSelected: showWarnings,
                    help: "Warnings",
                    action: { showWarnings.toggle() }
                )
                CollapsedSidebarItem(
                    icon: "globe",
                    isSelected: showTranslation,
                    help: "Target language",
                    action: { showTranslation.toggle() }
                )
                .disabled(project?.targetLanguage.isEmpty ?? true)
            }

            Spacer()

            CollapsedSidebarItem(
                icon: "keyboard",
                isSelected: false,
                help: "Keyboard shortcuts",
                action: onShowShortcuts
            )
            .padding(.bottom, 10)
        }
        .frame(width: 54)
    }

    // MARK: - Project header

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Project")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .kerning(0.4)
                .textCase(.uppercase)

            HStack(spacing: 6) {
                Image(systemName: "film")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(project?.displayName ?? "No project")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                collapseButton(systemName: "sidebar.left", help: "Hide sidebar")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 44) // space for traffic lights
        .padding(.bottom, 14)
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                workspaceSection
                librarySection
                speakersSection
                languagesSection
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Workspace section

    private var workspaceSection: some View {
        SidebarSection(title: "Workspace") {
            SidebarItem(
                icon: Image(systemName: "captions.bubble"),
                label: "Subtitles",
                isSelected: workspaceMode == .subtitles,
                action: { workspaceMode = .subtitles }
            )
            SidebarItem(
                icon: Image(systemName: "scissors"),
                label: "Video editor",
                isSelected: workspaceMode == .videoEditor,
                action: { workspaceMode = .videoEditor }
            )
            SidebarItem(
                icon: Image(systemName: "gearshape"),
                label: "Settings",
                isSelected: workspaceMode == .settings,
                action: { workspaceMode = .settings }
            )
        }
    }

    // MARK: - Library section

    private var librarySection: some View {
        let allCount = project?.subtitles.count ?? 0
        let warnCount = project?.subtitles.filter { !SubtitleWarningService.warnings(for: $0).isEmpty }.count ?? 0

        return SidebarSection(title: "Library") {
            SidebarItem(
                icon: Image(systemName: "folder"),
                label: "All cues",
                badge: allCount > 0 ? "\(allCount)" : nil,
                isSelected: false,
                action: {}
            )
            SidebarItem(
                icon: Image(systemName: "exclamationmark.triangle"),
                label: "Warnings",
                badge: warnCount > 0 ? "\(warnCount)" : nil,
                isSelected: showWarnings,
                action: { showWarnings.toggle() }
            )
            SidebarItem(
                icon: Image(systemName: "checkmark"),
                label: "Approved",
                badge: "0",
                isSelected: false,
                action: {}
            )
        }
    }

    // MARK: - Speakers section

    @ViewBuilder
    private var speakersSection: some View {
        if let project {
            SidebarSection(title: "Speakers") {
                ForEach(project.speakers) { speaker in
                    let count = project.subtitles.filter { $0.speaker == speaker.id }.count
                    SidebarItem(
                        dotColor: speaker.color,
                        label: speaker.name,
                        badge: count > 0 ? "\(count)" : nil,
                        isSelected: selectedSpeakerID == speaker.id,
                        action: {
                            selectedSpeakerID = selectedSpeakerID == speaker.id ? nil : speaker.id
                        }
                    )
                }
            }
        }
    }

    // MARK: - Languages section

    private var languagesSection: some View {
        SidebarSection(title: "Languages") {
            SidebarItem(
                icon: Image(systemName: "globe"),
                label: sourceLanguageLabel,
                isSelected: !showTranslation,
                action: {}
            )
            if let project, !project.targetLanguage.isEmpty {
                SidebarItem(
                    icon: Image(systemName: "globe"),
                    label: targetLanguageLabel(project),
                    badge: showTranslation ? "✓" : nil,
                    isSelected: showTranslation,
                    action: { showTranslation.toggle() }
                )
            }
            SidebarItem(
                icon: Image(systemName: "plus"),
                label: "Add language…",
                isSelected: false,
                action: {}
            )
        }
    }

    private var sourceLanguageLabel: String {
        let lang = project?.sourceLanguage ?? "English"
        return "\(lang) (source)"
    }

    private func targetLanguageLabel(_ project: Project) -> String {
        project.targetLanguage.isEmpty ? "Target language" : project.targetLanguage
    }

    // MARK: - Footer

    private var footer: some View {
        Button(action: onShowShortcuts) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 12))
                Text("Keyboard shortcuts")
                    .font(.system(size: 11))
                Spacer()
                Text("⌘?")
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func collapseButton(systemName: String, help: String) -> some View {
        Button {
            isCollapsed.toggle()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }
}

// MARK: - Sidebar section

private struct SidebarSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .kerning(0.4)
                .textCase(.uppercase)
                .padding(.horizontal, 18)
                .padding(.bottom, 4)

            content()
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Sidebar item

private struct SidebarItem: View {
    var icon: Image? = nil
    var dotColor: Color? = nil
    let label: String
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("Framelingo.accentColorName") private var accentColorName: String = AccentColorName.blue.rawValue

    private var accent: Color {
        AccentColorName(rawValue: accentColorName)?.color ?? AccentColorName.blue.color
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                leadingIcon
                    .frame(width: 14, alignment: .center)

                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 0)
            .frame(height: 26)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                isSelected
                    ? accent.opacity(colorScheme == .dark ? 0.2 : 0.12)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .foregroundStyle(isSelected ? .primary : .primary)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if let dotColor {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
        } else if let icon {
            icon
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? accent : .secondary)
        }
    }
}

private struct CollapsedSidebarItem: View {
    let icon: String
    let isSelected: Bool
    let help: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("Framelingo.accentColorName") private var accentColorName: String = AccentColorName.blue.rawValue

    private var accent: Color {
        AccentColorName(rawValue: accentColorName)?.color ?? AccentColorName.blue.color
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? accent : .secondary)
                .frame(width: 34, height: 30)
                .background(
                    isSelected
                        ? accent.opacity(colorScheme == .dark ? 0.2 : 0.12)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - App workspace mode

enum AppWorkspaceMode: Equatable {
    case subtitles
    case videoEditor
    case settings
}
