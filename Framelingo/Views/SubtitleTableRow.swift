import SwiftUI

struct SubtitleTableRow: View {
    let segment: SubtitleSegment
    let speakerLabels: [SpeakerLabel]
    let isActive: Bool
    let isSelected: Bool
    var focusedField: FocusState<SubtitleEditorFocus?>.Binding
    let onSelect: () -> Void
    let onUpdate: (SubtitleSegment) -> Void
    let onValidationError: (String) -> Void

    @State private var startText: String
    @State private var endText: String
    @State private var originalText: String
    @State private var translatedText: String

    init(
        segment: SubtitleSegment,
        speakerLabels: [SpeakerLabel] = [],
        isActive: Bool,
        isSelected: Bool,
        focusedField: FocusState<SubtitleEditorFocus?>.Binding,
        onSelect: @escaping () -> Void,
        onUpdate: @escaping (SubtitleSegment) -> Void,
        onValidationError: @escaping (String) -> Void
    ) {
        self.segment = segment
        self.speakerLabels = speakerLabels
        self.isActive = isActive
        self.isSelected = isSelected
        self.focusedField = focusedField
        self.onSelect = onSelect
        self.onUpdate = onUpdate
        self.onValidationError = onValidationError
        _startText = State(initialValue: SubtitleTimeFormatter.format(milliseconds: segment.startMs))
        _endText = State(initialValue: SubtitleTimeFormatter.format(milliseconds: segment.endMs))
        _originalText = State(initialValue: segment.originalText)
        _translatedText = State(initialValue: segment.translatedText)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(segment.index)")
                .frame(width: 32, alignment: .leading)
                .padding(.top, 5)

            timingView

            speakerView

            originalTextView

            translatedTextView
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onChange(of: segment) { _, newSegment in
            startText = SubtitleTimeFormatter.format(milliseconds: newSegment.startMs)
            endText = SubtitleTimeFormatter.format(milliseconds: newSegment.endMs)
            originalText = newSegment.originalText
            translatedText = newSegment.translatedText
        }
    }

    @ViewBuilder
    private var speakerView: some View {
        if !speakerLabels.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Menu {
                    Button("No speaker") {
                        var updatedSegment = segment
                        updatedSegment.speakerId = nil
                        onUpdate(updatedSegment)
                    }

                    Divider()

                    ForEach(speakerLabels) { label in
                        Button(label.displayName) {
                            var updatedSegment = segment
                            updatedSegment.speakerId = label.id
                            onUpdate(updatedSegment)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                        Text(speakerDisplayName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 22)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if !segment.warnings.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .help(segment.warnings.map(\.rawValue).joined(separator: ", "))
                }
            }
            .frame(width: 118, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var speakerDisplayName: String {
        guard let speakerId = segment.speakerId else {
            return "No speaker"
        }

        return speakerLabels.first(where: { $0.id == speakerId })?.displayName ?? "Speaker \(speakerId + 1)"
    }

    @ViewBuilder
    private var timingView: some View {
        if isSelected || focusedField.wrappedValue?.timingSegmentID == segment.id {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Start", text: $startText)
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .focused(focusedField, equals: .start(segment.id))
                    .onSubmit(commitTiming)

                TextField("End", text: $endText)
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .focused(focusedField, equals: .end(segment.id))
                    .onSubmit(commitTiming)
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(SubtitleTimeFormatter.format(milliseconds: segment.startMs))
                Text(SubtitleTimeFormatter.format(milliseconds: segment.endMs))
            }
            .monospacedDigit()
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(width: 96, alignment: .leading)
            .padding(.top, 5)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onSelect()
                startText = SubtitleTimeFormatter.format(milliseconds: segment.startMs)
                endText = SubtitleTimeFormatter.format(milliseconds: segment.endMs)
                focusedField.wrappedValue = .start(segment.id)
            }
        }
    }

    @ViewBuilder
    private var originalTextView: some View {
        if focusedField.wrappedValue == .original(segment.id) {
            TextField("Original text", text: $originalText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused(focusedField, equals: .original(segment.id))
                .onSubmit {
                    focusedField.wrappedValue = nil
                }
                .onChange(of: originalText) { _, newValue in
                    var updatedSegment = segment
                    updatedSegment.originalText = newValue
                    onUpdate(updatedSegment)
                }
        } else {
            Text(segment.originalText.isEmpty ? "Double-click to edit original" : segment.originalText)
                .foregroundStyle(segment.originalText.isEmpty ? .tertiary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 5)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    onSelect()
                    originalText = segment.originalText
                    focusedField.wrappedValue = .original(segment.id)
                }
        }
    }

    @ViewBuilder
    private var translatedTextView: some View {
        if isSelected || focusedField.wrappedValue == .translation(segment.id) {
            TextField("Translated text", text: $translatedText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused(focusedField, equals: .translation(segment.id))
                .onChange(of: translatedText) { _, newValue in
                    var updatedSegment = segment
                    updatedSegment.translatedText = newValue
                    onUpdate(updatedSegment)
                }
        } else {
            let displayText = segment.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(displayText.isEmpty ? "Select to edit translation" : segment.translatedText)
                .foregroundStyle(displayText.isEmpty ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 5)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    onSelect()
                    translatedText = segment.translatedText
                    focusedField.wrappedValue = .translation(segment.id)
                }
        }
    }

    private func commitTiming() {
        guard let startMs = SubtitleTimeFormatter.parse(startText) else {
            onValidationError("Start time must use 00:00:00,000 format.")
            startText = SubtitleTimeFormatter.format(milliseconds: segment.startMs)
            return
        }

        guard let endMs = SubtitleTimeFormatter.parse(endText) else {
            onValidationError("End time must use 00:00:00,000 format.")
            endText = SubtitleTimeFormatter.format(milliseconds: segment.endMs)
            return
        }

        guard endMs > startMs else {
            onValidationError("End time must be greater than start time.")
            startText = SubtitleTimeFormatter.format(milliseconds: segment.startMs)
            endText = SubtitleTimeFormatter.format(milliseconds: segment.endMs)
            return
        }

        guard startMs >= 0 else {
            onValidationError("Start time must be greater than or equal to 00:00:00,000.")
            startText = SubtitleTimeFormatter.format(milliseconds: segment.startMs)
            endText = SubtitleTimeFormatter.format(milliseconds: segment.endMs)
            return
        }

        var updatedSegment = segment
        updatedSegment.startMs = startMs
        updatedSegment.endMs = endMs
        onUpdate(updatedSegment)
    }
}
