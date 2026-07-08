import SwiftUI

struct SubtitleExportOptionsSheet: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel
    let kind: SubtitleExportKind
    let onCancel: () -> Void
    let onExport: () -> Void

    private var options: SubtitleExportOptions {
        viewModel.project?.speakerExportOptions ?? project.speakerExportOptions
    }

    private var usesWebVTT: Bool {
        kind == .translatedVTT || kind == .originalVTT
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(kind.title)
                .font(.headline)

            Toggle(
                "Include speaker labels",
                isOn: Binding(
                    get: { options.includeSpeakerLabels },
                    set: { isOn in
                        var updated = options
                        updated.includeSpeakerLabels = isOn
                        viewModel.updateSpeakerExportOptions(updated)
                    }
                )
            )
            .disabled(project.speakerLabels.isEmpty)

            Picker(
                "Speaker format",
                selection: Binding(
                    get: { options.speakerFormat },
                    set: { format in
                        var updated = options
                        updated.speakerFormat = format
                        viewModel.updateSpeakerExportOptions(updated)
                    }
                )
            ) {
                if usesWebVTT {
                    Text(SpeakerExportFormat.webVTTVoiceTags.displayName)
                        .tag(SpeakerExportFormat.webVTTVoiceTags)
                } else {
                    Text(SpeakerExportFormat.squareBrackets.displayName)
                        .tag(SpeakerExportFormat.squareBrackets)
                }
                Text(SpeakerExportFormat.none.displayName)
                    .tag(SpeakerExportFormat.none)
            }
            .disabled(!options.includeSpeakerLabels || project.speakerLabels.isEmpty)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Export", action: onExport)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            guard usesWebVTT, options.speakerFormat == .squareBrackets else {
                return
            }

            var updated = options
            updated.speakerFormat = .webVTTVoiceTags
            viewModel.updateSpeakerExportOptions(updated)
        }
    }
}
