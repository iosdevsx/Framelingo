import ExportFeature
import Subtitles
import SwiftUI

struct SubtitleExportOptionsSheet: View {
    let state: SubtitleExportOptionsState
    let actions: SubtitleExportOptionsActions
    let kind: SubtitleExportKind
    let onCancel: () -> Void
    let onExport: () -> Void

    private var options: SubtitleExportOptions {
        state.options
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
                        actions.update(updated)
                    }
                )
            )
            .disabled(!state.hasSpeakerLabels)

            Picker(
                "Speaker format",
                selection: Binding(
                    get: { options.speakerFormat },
                    set: { format in
                        var updated = options
                        updated.speakerFormat = format
                        actions.update(updated)
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
            .disabled(!options.includeSpeakerLabels || !state.hasSpeakerLabels)

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
            actions.update(updated)
        }
    }
}
