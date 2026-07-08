import SwiftUI

struct SubtitleImportPreviewSheet: View {
    let preview: SubtitleImportPreview
    let hasExistingSubtitles: Bool
    let onCancel: () -> Void
    let onImport: (SubtitleImportMode, SubtitleImportDestination) -> Void

    @State private var mode: SubtitleImportMode
    @State private var destination: SubtitleImportDestination = .original

    init(
        preview: SubtitleImportPreview,
        hasExistingSubtitles: Bool,
        onCancel: @escaping () -> Void,
        onImport: @escaping (SubtitleImportMode, SubtitleImportDestination) -> Void
    ) {
        self.preview = preview
        self.hasExistingSubtitles = hasExistingSubtitles
        self.onCancel = onCancel
        self.onImport = onImport
        _mode = State(initialValue: .replaceExisting)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            destinationSection

            if hasExistingSubtitles {
                importModeSection
            }

            if !preview.warnings.isEmpty {
                warningsSection
            }

            previewSection

            Spacer(minLength: 0)

            Divider()

            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Import") {
                    onImport(hasExistingSubtitles ? mode : .replaceExisting, destination)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 720, height: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import Subtitles")
                .font(.title2)
                .fontWeight(.semibold)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("File")
                        .foregroundStyle(.secondary)
                    Text(preview.fileURL.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                GridRow {
                    Text("Format")
                        .foregroundStyle(.secondary)
                    Text(preview.format.readableName)
                }

                GridRow {
                    Text("Encoding")
                        .foregroundStyle(.secondary)
                    Text(preview.detectedEncodingName ?? "Unknown")
                }

                GridRow {
                    Text("Segments")
                        .foregroundStyle(.secondary)
                    Text("\(preview.segments.count)")
                }
            }
            .font(.callout)
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Import To", selection: $destination) {
                ForEach(SubtitleImportDestination.allCases) { destination in
                    Text(destination.title).tag(destination)
                }
            }
            .pickerStyle(.radioGroup)

            Text(destination.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if destination == .translated, hasExistingSubtitles, mode == .replaceExisting {
                Label("Existing timings and original text will be kept where possible; imported text will fill translations by order.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var importModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Import Mode", selection: $mode) {
                ForEach(SubtitleImportMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)

            if mode == .replaceExisting {
                Label("This will replace current subtitles.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Warnings")
                .font(.headline)

            ForEach(preview.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(preview.segments.prefix(10)) { segment in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(segment.index)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(SubtitleTimeFormatter.format(milliseconds: segment.startMs)) - \(SubtitleTimeFormatter.format(milliseconds: segment.endMs))")
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)

                                Text(segment.originalText)
                                    .font(.callout)
                                    .lineLimit(3)
                            }

                            Spacer()
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
