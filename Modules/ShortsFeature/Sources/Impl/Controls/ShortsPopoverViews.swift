import Application
import DesignSystem
import Project
import Shorts
import Subtitles
import VideoRendering
import AppKit
import SwiftUI

struct ShortsSettingsPopover: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Shorts Settings", systemImage: "gearshape")
                .font(.headline)

            Picker("Default platform", selection: settingsBinding(\.platform)) {
                ForEach(ShortsPlatform.allCases) { platform in
                    Text(platform.displayName).tag(platform)
                }
            }

            Picker("Default framing", selection: settingsBinding(\.reframing)) {
                ForEach(ShortsReframing.allCases) { reframing in
                    Text(reframing.displayName).tag(reframing)
                }
            }

            Divider()

            Toggle("Snap edges to subtitles", isOn: settingsBinding(\.snapToCues))
            Toggle("Burn subtitles into video", isOn: settingsBinding(\.burnSubtitlesIntoVideo))

            Text("Use the paintbrush beside the Shorts preview to edit caption appearance.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .controlSize(.small)
        .padding(14)
        .frame(width: 280)
    }

    private func settingsBinding<Value>(
        _ keyPath: WritableKeyPath<ShortsExportSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: { project.shortsExportSettings[keyPath: keyPath] },
            set: { value in
                var settings = project.shortsExportSettings
                settings[keyPath: keyPath] = value
                viewModel.updateShortsExportSettings(settings)
            }
        )
    }
}

struct ShortsSubtitleAppearancePopover: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Shorts Caption Style", systemImage: "paintbrush")
                .font(.headline)

            Form {
                Section("Text") {
                    Picker("Source", selection: styleBinding(\.subtitleTextMode)) {
                        ForEach(SubtitleTextMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Picker("Font", selection: styleBinding(\.fontName)) {
                        ForEach(availableFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }

                    LabeledContent("Size · \(Int(style.fontSize.rounded()))pt") {
                        Slider(
                            value: styleBinding(\.fontSize, registerUndo: false),
                            in: 32...112,
                            step: 1,
                            onEditingChanged: updateInteractiveStyleEdit
                        )
                        .frame(width: 150)
                    }

                    ColorPicker(
                        "Text color",
                        selection: textColorBinding,
                        supportsOpacity: false
                    )

                    Stepper(
                        "Maximum lines: \(style.maxLines)",
                        value: styleBinding(\.maxLines),
                        in: 1...3
                    )
                }

                Section("Background") {
                    Toggle("Background", isOn: styleBinding(\.backgroundEnabled))

                    if style.backgroundEnabled {
                        ColorPicker(
                            "Fill color",
                            selection: backgroundColorBinding,
                            supportsOpacity: false
                        )

                        LabeledContent("Opacity · \(percent(style.backgroundOpacity))") {
                            Slider(
                                value: styleBinding(\.backgroundOpacity, registerUndo: false),
                                in: 0...1,
                                step: 0.05,
                                onEditingChanged: updateInteractiveStyleEdit
                            )
                            .frame(width: 150)
                        }

                        LabeledContent("Corners · \(Int(style.backgroundCornerRadius.rounded()))px") {
                            Slider(
                                value: styleBinding(\.backgroundCornerRadius, registerUndo: false),
                                in: 0...48,
                                step: 1,
                                onEditingChanged: updateInteractiveStyleEdit
                            )
                            .frame(width: 150)
                        }

                        Toggle("Border", isOn: styleBinding(\.borderEnabled))

                        if style.borderEnabled {
                            ColorPicker(
                                "Border color",
                                selection: borderColorBinding,
                                supportsOpacity: false
                            )

                            LabeledContent("Width · \(String(format: "%.1f", style.borderWidth))px") {
                                Slider(
                                    value: styleBinding(\.borderWidth, registerUndo: false),
                                    in: 0.5...8,
                                    step: 0.5,
                                    onEditingChanged: updateInteractiveStyleEdit
                                )
                                .frame(width: 150)
                            }

                            LabeledContent("Border opacity · \(percent(style.borderOpacity))") {
                                Slider(
                                    value: styleBinding(\.borderOpacity, registerUndo: false),
                                    in: 0...1,
                                    step: 0.05,
                                    onEditingChanged: updateInteractiveStyleEdit
                                )
                                .frame(width: 150)
                            }
                        }
                    }
                }

                Section("Position") {
                    Picker("Preset", selection: positionBinding) {
                        ForEach(SubtitlePosition.allCases) { position in
                            Text(position.displayName).tag(position)
                        }
                    }

                    Button("Reset Shorts Position") {
                        resetPosition()
                    }

                    Button("Restore Visible Caption Defaults") {
                        viewModel.updateShortsSubtitleStyle(
                            ShortsExportSettings.defaultSubtitleStyle
                        )
                    }

                    Text("Drag the caption directly on the preview for precise placement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .padding(14)
        .frame(width: 390, height: 590)
    }

    private var style: VideoExportSettings {
        viewModel.project?.shortsExportSettings.subtitleStyle
            ?? project.shortsExportSettings.subtitleStyle
    }

    private var availableFonts: [String] {
        let systemFonts = NSFontManager.shared.availableFontFamilies.sorted()
        return systemFonts.contains(style.fontName)
            ? systemFonts
            : ([style.fontName] + systemFonts).filter { !$0.isEmpty }
    }

    private func styleBinding<Value>(
        _ keyPath: WritableKeyPath<VideoExportSettings, Value>,
        registerUndo: Bool = true
    ) -> Binding<Value> {
        Binding(
            get: { style[keyPath: keyPath] },
            set: { value in
                var updated = style
                updated[keyPath: keyPath] = value
                viewModel.updateShortsSubtitleStyle(updated, registerUndo: registerUndo)
            }
        )
    }

    private var positionBinding: Binding<SubtitlePosition> {
        Binding(
            get: { style.subtitlePosition },
            set: { position in
                var updated = style
                updated.subtitlePosition = position
                updated.subtitlePositionX = 0.5
                updated.subtitlePositionY = position.defaultYOffset
                viewModel.updateShortsSubtitleStyle(updated)
            }
        )
    }

    private var textColorBinding: Binding<Color> {
        colorBinding(
            red: \.textColorRed,
            green: \.textColorGreen,
            blue: \.textColorBlue
        )
    }

    private var backgroundColorBinding: Binding<Color> {
        colorBinding(
            red: \.backgroundColorRed,
            green: \.backgroundColorGreen,
            blue: \.backgroundColorBlue
        )
    }

    private var borderColorBinding: Binding<Color> {
        colorBinding(
            red: \.borderColorRed,
            green: \.borderColorGreen,
            blue: \.borderColorBlue
        )
    }

    private func colorBinding(
        red: WritableKeyPath<VideoExportSettings, Double>,
        green: WritableKeyPath<VideoExportSettings, Double>,
        blue: WritableKeyPath<VideoExportSettings, Double>
    ) -> Binding<Color> {
        Binding(
            get: {
                Color(
                    red: clamped(style[keyPath: red]),
                    green: clamped(style[keyPath: green]),
                    blue: clamped(style[keyPath: blue])
                )
            },
            set: { color in
                let components = colorComponents(color)
                var updated = style
                updated[keyPath: red] = components.red
                updated[keyPath: green] = components.green
                updated[keyPath: blue] = components.blue
                viewModel.updateShortsSubtitleStyle(updated)
            }
        )
    }

    private func updateInteractiveStyleEdit(_ isEditing: Bool) {
        if isEditing {
            viewModel.beginInteractiveShortsSubtitleStyleEdit()
        } else {
            viewModel.endInteractiveShortsSubtitleStyleEdit()
        }
    }

    private func resetPosition() {
        let defaults = ShortsExportSettings.defaultSubtitleStyle
        var updated = style
        updated.subtitlePosition = defaults.subtitlePosition
        updated.subtitlePositionX = defaults.subtitlePositionX
        updated.subtitlePositionY = defaults.subtitlePositionY
        viewModel.updateShortsSubtitleStyle(updated)
    }

    private func colorComponents(_ color: Color) -> (red: Double, green: Double, blue: Double) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .white
        return (
            clamped(Double(nsColor.redComponent)),
            clamped(Double(nsColor.greenComponent)),
            clamped(Double(nsColor.blueComponent))
        )
    }

    private func percent(_ value: Double) -> String {
        "\(Int((clamped(value) * 100).rounded()))%"
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

struct ShortsExportOptionsPopover: View {
    let project: Project
    let shorts: [ShortDefinition]
    @ObservedObject var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var exportsSRT: Bool

    init(
        project: Project,
        shorts: [ShortDefinition],
        viewModel: ProjectViewModel
    ) {
        self.project = project
        self.shorts = shorts
        self.viewModel = viewModel
        _exportsSRT = State(initialValue: project.shortsExportSettings.exportSRTSidecar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                shorts.count == 1 ? "Export Short" : "Export \(shorts.count) Shorts",
                systemImage: "square.and.arrow.up"
            )
            .font(.headline)

            Toggle("Export .srt next to video", isOn: $exportsSRT)

            Text("SRT is useful for selectable captions uploaded separately to YouTube or another platform.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }

                Spacer()

                Button("Choose Folder…", action: chooseFolderAndExport)
                    .buttonStyle(.borderedProminent)
                    .disabled(shorts.isEmpty)
            }
        }
        .controlSize(.small)
        .padding(14)
        .frame(width: 310)
    }

    private func chooseFolderAndExport() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.message = shorts.count == 1
            ? "Choose a folder for the exported short"
            : "Choose a folder for the \(shorts.count) exported shorts"

        dismiss()
        guard panel.runModal() == .OK, let directory = panel.url else {
            return
        }

        var settings = project.shortsExportSettings
        settings.exportSRTSidecar = exportsSRT
        viewModel.updateShortsExportSettings(settings)
        viewModel.exportShorts(shorts, to: directory)
    }
}

