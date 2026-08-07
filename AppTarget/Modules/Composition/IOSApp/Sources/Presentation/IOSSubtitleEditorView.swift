import SubtitleEditorFeature
import Subtitles
import SwiftUI

struct IOSSubtitleEditorView: View {
    let state: SubtitleEditorState
    let actions: SubtitleEditorActions

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(state.subtitles) { segment in
                    IOSSubtitleRow(
                        segment: segment,
                        isSelected: state.selectedSegmentID == segment.id,
                        isActive: state.activeSegmentID == segment.id,
                        actions: actions
                    )
                }
            }
            .padding()
        }
        .overlay {
            if state.subtitles.isEmpty {
                ContentUnavailableView(
                    "No Subtitles",
                    systemImage: "captions.bubble",
                    description: Text("Use Transcribe to create controlled mock subtitles.")
                )
            }
        }
        .accessibilityLabel("Subtitle editor")
    }
}

private struct IOSSubtitleRow: View {
    let segment: SubtitleSegment
    let isSelected: Bool
    let isActive: Bool
    let actions: SubtitleEditorActions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                actions.selectSegment(id: segment.id)
            } label: {
                HStack {
                    Text("#\(segment.index)")
                        .font(.headline.monospacedDigit())
                    Text("\(timeLabel(segment.startMs)) – \(timeLabel(segment.endMs))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isActive {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel("Currently playing subtitle")
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if isSelected {
                TextField("Original text", text: originalTextBinding, axis: .vertical)
                    .lineLimit(2...5)
                    .onSubmit(actions.endTextEdit)
                TextField("Translation", text: translatedTextBinding, axis: .vertical)
                    .lineLimit(2...5)
                    .onSubmit(actions.endTextEdit)

                HStack {
                    TextField("Start (ms)", value: startBinding, format: .number)
                        .keyboardType(.numberPad)
                    TextField("End (ms)", value: endBinding, format: .number)
                        .keyboardType(.numberPad)
                }
                .textFieldStyle(.roundedBorder)
            } else {
                Text(segment.hasTranslation ? segment.translatedText : segment.originalText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(
            isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
            in: .rect(cornerRadius: 12)
        )
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }

    private var originalTextBinding: Binding<String> {
        Binding(
            get: { segment.originalText },
            set: { value in
                var updated = segment
                updated.originalText = value
                _ = actions.updateSubtitle(updated)
            }
        )
    }

    private var translatedTextBinding: Binding<String> {
        Binding(
            get: { segment.translatedText },
            set: { value in
                var updated = segment
                updated.translatedText = value
                _ = actions.updateSubtitle(updated)
            }
        )
    }

    private var startBinding: Binding<Int> {
        Binding(
            get: { segment.startMs },
            set: { value in
                var updated = segment
                updated.startMs = value
                _ = actions.updateSubtitle(updated)
            }
        )
    }

    private var endBinding: Binding<Int> {
        Binding(
            get: { segment.endMs },
            set: { value in
                var updated = segment
                updated.endMs = value
                _ = actions.updateSubtitle(updated)
            }
        )
    }

    private func timeLabel(_ milliseconds: Int) -> String {
        let totalSeconds = max(milliseconds, 0) / 1_000
        let fraction = max(milliseconds, 0) % 1_000
        return String(
            format: "%02d:%02d.%03d",
            totalSeconds / 60,
            totalSeconds % 60,
            fraction
        )
    }
}
