import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    @State private var section: SettingsSection = .tools
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("Framelingo.accentColorName") private var accentColorName: String = AccentColorName.blue.rawValue

    private var accent: Color {
        AccentColorName(rawValue: accentColorName)?.color ?? AccentColorName.blue.color
    }

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
            Divider()
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Sidebar

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .kerning(0.4)
                .textCase(.uppercase)
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 12)

            ForEach(SettingsSection.allCases) { item in
                settingsNavItem(item)
            }

            Spacer()
        }
        .frame(width: 200)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.02 : 0.015))
    }

    private func settingsNavItem(_ item: SettingsSection) -> some View {
        Button { section = item } label: {
            HStack(spacing: 9) {
                Image(systemName: item.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(section == item ? accent : .secondary)
                    .frame(width: 14)
                Text(item.label)
                    .font(.system(size: 12, weight: section == item ? .semibold : .medium))
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                section == item ? accent.opacity(colorScheme == .dark ? 0.2 : 0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                switch section {
                case .tools:      toolsSection
                case .appearance: appearanceSection
                case .shortcuts:  shortcutsSection
                case .about:      aboutSection
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    // MARK: - Tools section

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("Tools")
            sectionDescription("Framelingo relies on local binaries for transcription and media processing.")

            settingsCard {
                // Providers
                settingsRow(label: "Speech-to-Text") {
                    TextField("Provider", text: $viewModel.settings.speechToTextProviderName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }

                cardDivider

                settingsRow(label: "Translation") {
                    TextField("Provider", text: $viewModel.settings.translationProviderName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
            }

            sectionHeading2("Whisper (Local Transcription)")

            settingsCard {
                settingsRow(label: "Model") {
                    Picker("", selection: whisperModelBinding) {
                        ForEach(WhisperModel.allCases) { model in
                            Text("\(model.displayName) (\(model.approximateSizeText))").tag(model)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                    .disabled(viewModel.isInstallingWhisper)
                }

                cardDivider

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Task { await viewModel.installWhisper() }
                    } label: {
                        Label("Install Local Whisper", systemImage: "arrow.down.circle")
                    }
                    .disabled(viewModel.isInstallingWhisper)

                    if viewModel.isInstallingWhisper {
                        ProgressView(value: viewModel.whisperInstallProgress)
                            .frame(width: 240)
                    }

                    Text(viewModel.whisperStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !viewModel.settings.whisperExecutablePath.isEmpty {
                        Text("Binary: \(viewModel.settings.whisperExecutablePath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    if !viewModel.settings.whisperModelPath.isEmpty {
                        Text("Model: \(viewModel.settings.whisperModelPath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    if let msg = viewModel.whisperInstallMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(whisperInstallMessageColor)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            sectionHeading2("FFmpeg")

            settingsCard {
                if FFmpegServiceFactory.usesEmbeddedFFmpegKit {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Using embedded FFmpegKit")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                } else {
                    settingsRow(label: "Path") {
                        TextField("ffmpeg path", text: $viewModel.settings.ffmpegPath)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 240)
                            .onChange(of: viewModel.settings.ffmpegPath) { _, _ in viewModel.save() }
                    }

                    cardDivider

                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            Task { await viewModel.checkFFmpeg() }
                        } label: {
                            Label("Check FFmpeg", systemImage: "checkmark.circle")
                        }
                        .disabled(viewModel.isCheckingFFmpeg)

                        if let v = viewModel.ffmpegVersion {
                            Text(v).font(.caption).foregroundStyle(.secondary)
                        }
                        if let msg = viewModel.ffmpegCheckMessage {
                            Label(msg, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }

            Button("Save Settings") { viewModel.save() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Appearance section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("Editor Appearance")

            settingsCard {
                settingsRow(label: "Accent color") {
                    HStack(spacing: 8) {
                        ForEach(AccentColorName.allCases) { colorName in
                            accentColorSwatch(colorName)
                        }
                    }
                }
            }

            sectionHeading("Subtitle Style")
            sectionDescription("Controls how burned-in subtitles appear in exported video.")

            if viewModel.hasSelectedProject {
                subtitleStyleEditor
            } else {
                ContentUnavailableView("No Project Selected", systemImage: "film")
                    .frame(height: 160)
            }
        }
    }

    private func accentColorSwatch(_ colorName: AccentColorName) -> some View {
        let isSelected = accentColorName == colorName.rawValue
        return Button {
            accentColorName = colorName.rawValue
        } label: {
            ZStack {
                Circle()
                    .fill(colorName.color)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .help(colorName.displayName)
    }

    // MARK: - Subtitle style editor (preserved from original)

    private var subtitleStyleEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            subtitleStylePreview

            settingsCard {
                settingsRow(label: "Font") {
                    Picker("", selection: videoExportSettingsBinding(\.fontName)) {
                        ForEach(availableFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }

                cardDivider

                settingsRow(label: "Size · \(Int(viewModel.currentVideoExportSettings.fontSize))pt") {
                    Slider(value: videoExportSettingsBinding(\.fontSize), in: 18...72, step: 1)
                        .frame(width: 200)
                }

                cardDivider

                settingsRow(label: "Position") {
                    Picker("", selection: subtitlePositionBinding) {
                        ForEach(SubtitlePosition.allCases) { pos in
                            Text(pos.displayName).tag(pos)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                cardDivider

                settingsRow(label: "Text Color") {
                    ColorPicker("", selection: subtitleTextColorBinding, supportsOpacity: false)
                        .labelsHidden()
                }

                cardDivider

                settingsRow(label: "Background") {
                    Toggle("", isOn: videoExportSettingsBinding(\.backgroundEnabled))
                        .labelsHidden()
                }

                if viewModel.currentVideoExportSettings.backgroundEnabled {
                    cardDivider
                    settingsRow(label: "Background Color") {
                        ColorPicker("", selection: subtitleBackgroundColorBinding, supportsOpacity: false)
                            .labelsHidden()
                    }

                    cardDivider
                    settingsRow(label: "Opacity · \(Int((viewModel.currentVideoExportSettings.backgroundOpacity * 100).rounded()))%") {
                        Slider(value: videoExportSettingsBinding(\.backgroundOpacity), in: 0...1, step: 0.05)
                            .frame(width: 200)
                    }
                }

                cardDivider

                settingsRow(label: "Max Lines") {
                    Stepper(
                        "\(viewModel.currentVideoExportSettings.maxLines)",
                        value: videoExportSettingsBinding(\.maxLines),
                        in: 1...3
                    )
                }
            }

            Button("Reset Position") {
                var s = viewModel.currentVideoExportSettings
                s.subtitlePosition = .bottom
                s.subtitlePositionX = 0.5
                s.subtitlePositionY = SubtitlePosition.bottom.defaultYOffset
                viewModel.updateVideoExportSettings(s)
            }
        }
    }

    // MARK: - Shortcuts section

    private var shortcutsSection: some View {
        let groups: [(String, [(String, [String])])] = [
            ("Playback", [
                ("Play / pause", ["Space"]),
                ("Previous cue", ["⌥", "←"]),
                ("Next cue", ["⌥", "→"]),
                ("Jump back 1s", ["J"]),
                ("Jump forward 1s", ["L"]),
            ]),
            ("Editing", [
                ("New cue", ["⌘", "N"]),
                ("Split at playhead", ["⌘", "⇧", "S"]),
                ("Delete cue", ["⌫"]),
                ("Set in-point", ["I"]),
                ("Set out-point", ["O"]),
            ]),
            ("Navigation", [
                ("Find", ["⌘", "F"]),
                ("Show shortcuts", ["⌘", "?"]),
                ("Toggle warnings", ["⌘", "W"]),
            ]),
        ]

        return VStack(alignment: .leading, spacing: 20) {
            sectionHeading("Keyboard Shortcuts")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(groups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.0)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .kerning(0.4)
                            .textCase(.uppercase)
                            .padding(.bottom, 2)

                        ForEach(group.1, id: \.0) { item in
                            HStack {
                                Text(item.0)
                                    .font(.system(size: 12))
                                Spacer()
                                HStack(spacing: 3) {
                                    ForEach(item.1, id: \.self) { key in
                                        Text(key)
                                            .font(.system(size: 10, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                }
            }
        }
    }

    // MARK: - About section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("About")

            settingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Framelingo")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Version 1.0 (Alpha)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Reusable layout helpers

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
    }

    private func sectionHeading2(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func sectionDescription(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            Spacer()
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var cardDivider: some View {
        Divider()
            .padding(.horizontal, 12)
            .opacity(0.5)
    }

    // MARK: - Subtitle style preview (preserved)

    private var subtitleStylePreview: some View {
        let settings = viewModel.currentVideoExportSettings

        return ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color.black.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Text("Subtitle preview\nThe final video uses this style.")
                .font(.custom(settings.fontName, size: min(max(settings.fontSize * 0.72, 16), 44)).weight(.semibold))
                .foregroundStyle(subtitleTextColor(settings))
                .multilineTextAlignment(.center)
                .lineLimit(settings.maxLines)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    settings.backgroundEnabled
                        ? subtitleBackgroundColor(settings).opacity(settings.backgroundOpacity)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
                .padding()
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Bindings and helpers (preserved from original)

    private var whisperModelBinding: Binding<WhisperModel> {
        Binding(
            get: { viewModel.selectedWhisperModel },
            set: { viewModel.selectedWhisperModel = $0 }
        )
    }

    private var whisperInstallMessageColor: Color {
        viewModel.settings.speechToTextProviderName == SpeechToTextProviderName.localWhisper ? .secondary : .red
    }

    private var availableFonts: [String] {
        let families = NSFontManager.shared.availableFontFamilies.sorted()
        return families.contains(viewModel.currentVideoExportSettings.fontName)
            ? families
            : ([viewModel.currentVideoExportSettings.fontName] + families).filter { !$0.isEmpty }
    }

    private func videoExportSettingsBinding<Value>(
        _ keyPath: WritableKeyPath<VideoExportSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: { viewModel.currentVideoExportSettings[keyPath: keyPath] },
            set: { value in
                var settings = viewModel.currentVideoExportSettings
                settings[keyPath: keyPath] = value
                viewModel.updateVideoExportSettings(settings)
            }
        )
    }

    private var subtitlePositionBinding: Binding<SubtitlePosition> {
        Binding(
            get: { viewModel.currentVideoExportSettings.subtitlePosition },
            set: { position in
                var settings = viewModel.currentVideoExportSettings
                settings.subtitlePosition = position
                settings.subtitlePositionY = position.defaultYOffset
                settings.subtitlePositionX = 0.5
                viewModel.updateVideoExportSettings(settings)
            }
        )
    }

    private var subtitleTextColorBinding: Binding<Color> {
        Binding(
            get: { subtitleTextColor(viewModel.currentVideoExportSettings) },
            set: { color in
                var settings = viewModel.currentVideoExportSettings
                let c = colorComponents(color)
                settings.textColorRed = c.red
                settings.textColorGreen = c.green
                settings.textColorBlue = c.blue
                viewModel.updateVideoExportSettings(settings)
            }
        )
    }

    private var subtitleBackgroundColorBinding: Binding<Color> {
        Binding(
            get: { subtitleBackgroundColor(viewModel.currentVideoExportSettings) },
            set: { color in
                var settings = viewModel.currentVideoExportSettings
                let c = colorComponents(color)
                settings.backgroundColorRed = c.red
                settings.backgroundColorGreen = c.green
                settings.backgroundColorBlue = c.blue
                viewModel.updateVideoExportSettings(settings)
            }
        )
    }

    private func subtitleTextColor(_ settings: VideoExportSettings) -> Color {
        Color(
            red: min(max(settings.textColorRed, 0), 1),
            green: min(max(settings.textColorGreen, 0), 1),
            blue: min(max(settings.textColorBlue, 0), 1)
        )
    }

    private func subtitleBackgroundColor(_ settings: VideoExportSettings) -> Color {
        Color(
            red: min(max(settings.backgroundColorRed, 0), 1),
            green: min(max(settings.backgroundColorGreen, 0), 1),
            blue: min(max(settings.backgroundColorBlue, 0), 1)
        )
    }

    private func colorComponents(_ color: Color) -> (red: Double, green: Double, blue: Double) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .white
        return (
            red: min(max(Double(nsColor.redComponent), 0), 1),
            green: min(max(Double(nsColor.greenComponent), 0), 1),
            blue: min(max(Double(nsColor.blueComponent), 0), 1)
        )
    }
}

// MARK: - Settings section enum

private enum SettingsSection: String, CaseIterable, Identifiable {
    case tools
    case appearance
    case shortcuts
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tools:      return "Tools"
        case .appearance: return "Appearance"
        case .shortcuts:  return "Shortcuts"
        case .about:      return "About"
        }
    }

    var icon: String {
        switch self {
        case .tools:      return "gearshape"
        case .appearance: return "paintbrush"
        case .shortcuts:  return "keyboard"
        case .about:      return "film"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: SettingsViewModel(appState: AppState()))
    }
}
