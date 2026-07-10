import AppKit
import SwiftUI

struct ExportVideoSheet: View {
    @ObservedObject var viewModel: ExportVideoViewModel
    var onStartExport: (ExportVideoViewModel) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingErrorAlert = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                outputSection
                subtitlesSection
                encodingSection
                previewSection

                if viewModel.isExporting || !viewModel.statusText.isEmpty {
                    statusSection
                }

                if let successOutputURL = viewModel.successOutputURL {
                    successSection(successOutputURL)
                }

                if let errorMessage = viewModel.errorMessage {
                    errorSection(errorMessage)
                }
            }
            .formStyle(.grouped)
            .disabled(viewModel.isExporting)

            Divider()

            footer
        }
        .frame(width: 620)
        .frame(minHeight: 560)
        .task {
            await viewModel.prepareForPresentation()
        }
        .onChange(of: viewModel.errorMessage) { _, message in
            isShowingErrorAlert = message != nil
        }
        .alert("Video Export Failed", isPresented: $isShowingErrorAlert) {
            Button("Copy Error") {
                copyErrorToPasteboard()
            }

            Button("OK", role: .cancel) {}
        } message: {
            Text(errorAlertText)
        }
    }

    private var outputSection: some View {
        Section("Output") {
            HStack {
                Text(viewModel.outputURL?.path ?? "No output file selected")
                    .foregroundStyle(viewModel.outputURL == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button("Choose...") {
                    viewModel.chooseOutputURL()
                }
            }
        }
    }

    private var subtitlesSection: some View {
        Section("Subtitles") {
            Picker("Text", selection: $viewModel.settings.subtitleTextMode) {
                ForEach(SubtitleTextMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            if viewModel.translatedModeHasNoText {
                Label("No translated text is available in these subtitles.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var encodingSection: some View {
        Section("Encoding") {
            Picker("Resolution", selection: $viewModel.settings.resolution) {
                ForEach(viewModel.availableResolutions) { resolution in
                    Text(resolution.displayName).tag(resolution)
                }
            }

            Picker("Frame Rate", selection: $viewModel.settings.frameRate) {
                ForEach(viewModel.availableFrameRates) { frameRate in
                    Text(frameRate.displayName).tag(frameRate)
                }
            }

            Picker("Codec", selection: $viewModel.settings.codec) {
                ForEach(VideoExportCodec.allCases) { codec in
                    Text(codec.displayName).tag(codec)
                }
            }

            Picker("Quality", selection: $viewModel.settings.quality) {
                ForEach(VideoExportQuality.allCases) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }

            Picker("Preset", selection: $viewModel.settings.preset) {
                ForEach(VideoExportPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
        }
    }

    private var previewSection: some View {
        let subtitleShape = RoundedRectangle(
            cornerRadius: max(0, viewModel.settings.backgroundCornerRadius)
        )

        return Section("Preview") {
            ZStack(alignment: previewAlignment) {
                LinearGradient(
                    colors: [Color.black.opacity(0.85), Color.gray.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Text("Subtitle preview")
                    .font(.custom(viewModel.settings.fontName, size: min(max(viewModel.settings.fontSize * 0.45, 14), 26)).weight(.semibold))
                    .foregroundStyle(subtitleTextColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(viewModel.settings.maxLines)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        viewModel.settings.backgroundEnabled
                            ? subtitleBackgroundColor.opacity(viewModel.settings.backgroundOpacity)
                            : Color.clear,
                        in: subtitleShape
                    )
                    .overlay(
                        subtitleShape.stroke(
                            subtitleBorderColor,
                            lineWidth: max(0, viewModel.settings.borderWidth)
                        )
                    )
                    .padding(18)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var statusSection: some View {
        Section("Status") {
            HStack {
                if viewModel.isExporting {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(viewModel.statusText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func successSection(_ url: URL) -> some View {
        Section("Done") {
            Text(url.path)
                .lineLimit(2)
                .truncationMode(.middle)

            Button("Reveal in Finder") {
                viewModel.revealInFinder()
            }
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section("Error") {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)

            if let debugOutput = viewModel.debugOutput {
                DisclosureGroup("Debug output") {
                    ScrollView {
                        Text(debugOutput)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .disabled(viewModel.isExporting)

            Spacer()

            Button("Export") {
                onStartExport(viewModel)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(
                viewModel.outputURL == nil
                    || viewModel.project.subtitles.isEmpty
                    || viewModel.isExporting
                    || viewModel.isPreparingSourceInfo
            )
        }
        .padding()
    }

    private var previewAlignment: Alignment {
        switch viewModel.settings.subtitlePosition {
        case .bottom:
            return .bottom
        case .center:
            return .center
        case .top:
            return .top
        }
    }

    private var subtitleTextColor: Color {
        Color(
            red: min(max(viewModel.settings.textColorRed, 0), 1),
            green: min(max(viewModel.settings.textColorGreen, 0), 1),
            blue: min(max(viewModel.settings.textColorBlue, 0), 1)
        )
    }

    private var subtitleBackgroundColor: Color {
        Color(
            red: min(max(viewModel.settings.backgroundColorRed, 0), 1),
            green: min(max(viewModel.settings.backgroundColorGreen, 0), 1),
            blue: min(max(viewModel.settings.backgroundColorBlue, 0), 1)
        )
    }

    private var subtitleBorderColor: Color {
        guard viewModel.settings.backgroundEnabled, viewModel.settings.borderEnabled else {
            return .clear
        }

        return Color(
            red: min(max(viewModel.settings.borderColorRed, 0), 1),
            green: min(max(viewModel.settings.borderColorGreen, 0), 1),
            blue: min(max(viewModel.settings.borderColorBlue, 0), 1)
        )
        .opacity(min(max(viewModel.settings.borderOpacity, 0), 1))
    }

    private var errorAlertText: String {
        [
            viewModel.errorMessage,
            viewModel.debugOutput
        ]
        .compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }
        .joined(separator: "\n\nDebug output:\n")
    }

    private func copyErrorToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(errorAlertText, forType: .string)
    }
}
