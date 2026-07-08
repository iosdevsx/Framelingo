import SwiftUI

struct ProjectToolbarView: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel
    let onExportVideo: () -> Void
    let onExportProjectFile: () -> Void
    let onExportSubtitles: (SubtitleExportKind) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showsSpeakerLabelsPopover = false
    @AppStorage("Framelingo.subtitleLayout") private var subtitleLayout: SubtitleLayoutMode = .split
    @AppStorage("Framelingo.density") private var density: EditorDensity = .comfy
    @AppStorage("Framelingo.showWarnings") private var showWarnings: Bool = false
    @AppStorage("Framelingo.accentColorName") private var accentColorName: String = AccentColorName.blue.rawValue

    private var accent: Color {
        AccentColorName(rawValue: accentColorName)?.color ?? AccentColorName.blue.color
    }

    var body: some View {
        HStack(spacing: 6) {
            titleBlock
            Spacer()
            LayoutSwitcherView(selected: $subtitleLayout, accent: accent)
            toolbarDivider
            DensityToggleView(density: $density)
            toolbarDivider
            warningsButton
            toolbarDivider
            undoRedoButtons
            toolbarDivider
            transcribeButton
            speakerLabelsButton
            exportMenu
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    // MARK: - Subviews

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(project.displayName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text(project.mediaFile.fileName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 140, alignment: .leading)
    }

    private var warningsButton: some View {
        Button { showWarnings.toggle() } label: {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11))
                Text("Warnings")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                showWarnings ? Color.orange.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        showWarnings ? Color.orange.opacity(0.4) : Color.primary.opacity(0.12),
                        lineWidth: 0.5
                    )
            )
            .foregroundStyle(showWarnings ? Color.orange : .primary)
        }
        .buttonStyle(.plain)
    }

    private var undoRedoButtons: some View {
        HStack(spacing: 8) {
            Button { viewModel.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Undo")
            .disabled(!viewModel.canUndo)
            .foregroundStyle(viewModel.canUndo ? .primary : Color.primary.opacity(0.3))

            Button { viewModel.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Redo")
            .disabled(!viewModel.canRedo)
            .foregroundStyle(viewModel.canRedo ? .primary : Color.primary.opacity(0.3))
        }
    }

    private var transcribeButton: some View {
        Button {
            Task { await viewModel.transcribe() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                Text(viewModel.isTranscribing ? "Transcribing…" : "Transcribe")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                viewModel.isTranscribing ? Color.primary.opacity(0.08) : accent,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .foregroundStyle(viewModel.isTranscribing ? Color.primary : .white)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isTranscribing)
    }

    @ViewBuilder
    private var speakerLabelsButton: some View {
        if !project.speakerLabels.isEmpty {
            Button {
                showsSpeakerLabelsPopover.toggle()
            } label: {
                Image(systemName: "person.2.badge.gearshape")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 22)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Rename speakers")
            .popover(isPresented: $showsSpeakerLabelsPopover, arrowEdge: .bottom) {
                speakerLabelsPopover
            }
        }
    }

    private var speakerLabelsPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Speakers")
                .font(.headline)

            ForEach(project.speakerLabels) { label in
                HStack(spacing: 8) {
                    speakerBadge(label.displayName)
                    TextField(
                        "Speaker name",
                        text: Binding(
                            get: {
                                viewModel.project?.speakerLabels.first(where: { $0.id == label.id })?.displayName
                                    ?? label.displayName
                            },
                            set: { newValue in
                                viewModel.updateSpeakerLabel(id: label.id, displayName: newValue)
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private func speakerBadge(_ text: String) -> some View {
        Text(text.prefix(2).uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 20)
            .background(accent, in: RoundedRectangle(cornerRadius: 5))
    }

    private var exportMenu: some View {
        Menu {
            Button("Save Project File…", action: onExportProjectFile)

            Divider()

            Button("Export Video…", action: onExportVideo)
                .disabled(project.subtitles.isEmpty)

            Divider()

            ForEach(SubtitleExportKind.allCases) { kind in
                Button(kind.title) { onExportSubtitles(kind) }
                    .disabled(project.subtitles.isEmpty)
            }

            Divider()

            Button("Translate") {
                Task { await viewModel.translate() }
            }
            .disabled(project.subtitles.isEmpty || viewModel.isTranslating)

            Button("Import Subtitles…") {
                viewModel.importSubtitlesFromFile()
            }
            .disabled(viewModel.isImportingSubtitles)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 11))
                Text("Export")
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1, height: 18)
    }
}

// MARK: - Layout switcher

struct LayoutSwitcherView: View {
    @Binding var selected: SubtitleLayoutMode
    let accent: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SubtitleLayoutMode.allCases) { mode in
                Button {
                    selected = mode
                } label: {
                    layoutIcon(for: mode)
                        .frame(width: 30, height: 22)
                        .background(
                            selected == mode
                                ? (colorScheme == .dark ? Color.white.opacity(0.14) : Color.white)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .shadow(
                            color: selected == mode ? Color.black.opacity(0.12) : Color.clear,
                            radius: 1, y: 1
                        )
                        .foregroundStyle(selected == mode ? accent : Color.primary.opacity(0.55))
                }
                .buttonStyle(.plain)
                .help(layoutLabel(for: mode))
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func layoutLabel(for mode: SubtitleLayoutMode) -> String {
        switch mode {
        case .split:      return "Split (3-pane)"
        case .videoFocus: return "Video focus"
        case .transcript: return "Transcript-first"
        }
    }

    @ViewBuilder
    private func layoutIcon(for mode: SubtitleLayoutMode) -> some View {
        switch mode {
        case .split:      SplitLayoutIcon()
        case .videoFocus: VideoFocusLayoutIcon()
        case .transcript: TranscriptLayoutIcon()
        }
    }
}

// 16×12 schematic icons matching the React prototype SVGs

private struct SplitLayoutIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 16.0
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: s)
            }
            func filled(_ path: Path, alpha: CGFloat) {
                var c = ctx; c.opacity = alpha; c.fill(path, with: .foreground)
            }
            ctx.stroke(rect(0.5, 0.5, 5.2, 7.5), with: .foreground, lineWidth: s)
            ctx.stroke(rect(5.9, 0.5, 4.2, 7.5), with: .foreground, lineWidth: s)
            ctx.stroke(rect(10.3, 0.5, 5.2, 7.5), with: .foreground, lineWidth: s)
            let timeline = rect(0.5, 8.5, 15, 3)
            filled(timeline, alpha: 0.25)
            ctx.stroke(timeline, with: .foreground, lineWidth: s)
        }
    }
}

private struct VideoFocusLayoutIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 16.0
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: s)
            }
            func filled(_ path: Path, alpha: CGFloat) {
                var c = ctx; c.opacity = alpha; c.fill(path, with: .foreground)
            }
            let video = rect(0.5, 0.5, 9, 7.5)
            filled(video, alpha: 0.18)
            ctx.stroke(video, with: .foreground, lineWidth: s)
            ctx.stroke(rect(9.7, 0.5, 5.8, 3.5), with: .foreground, lineWidth: s)
            ctx.stroke(rect(9.7, 4.5, 5.8, 3.5), with: .foreground, lineWidth: s)
            ctx.stroke(rect(0.5, 8.5, 15, 3), with: .foreground, lineWidth: s)
        }
    }
}

private struct TranscriptLayoutIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 16.0
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: s)
            }
            func filled(_ path: Path, alpha: CGFloat) {
                var c = ctx; c.opacity = alpha; c.fill(path, with: .foreground)
            }
            func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
                var p = Path()
                p.move(to: CGPoint(x: x1 * s, y: y1 * s))
                p.addLine(to: CGPoint(x: x2 * s, y: y2 * s))
                ctx.stroke(p, with: .foreground, lineWidth: 0.8 * s)
            }
            let video = rect(0.5, 0.5, 7, 3.5)
            filled(video, alpha: 0.18)
            ctx.stroke(video, with: .foreground, lineWidth: s)
            ctx.stroke(rect(0.5, 4.5, 7, 3.5), with: .foreground, lineWidth: s)
            ctx.stroke(rect(7.7, 0.5, 7.8, 7.5), with: .foreground, lineWidth: s)
            line(9, 2.5, 14, 2.5)
            line(9, 4.5, 14, 4.5)
            line(9, 6.5, 13, 6.5)
            ctx.stroke(rect(0.5, 8.5, 15, 3), with: .foreground, lineWidth: s)
        }
    }
}

// MARK: - Density toggle

struct DensityToggleView: View {
    @Binding var density: EditorDensity

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EditorDensity.allCases) { option in
                Button { density = option } label: {
                    Text(option.rawValue.capitalized)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            density == option
                                ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.white)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .shadow(
                            color: density == option ? Color.black.opacity(0.1) : Color.clear,
                            radius: 1, y: 1
                        )
                        .foregroundStyle(density == option ? .primary : Color.primary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}
