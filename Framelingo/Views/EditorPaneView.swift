import SwiftUI

struct EditorPaneView: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel
    let onSeek: (Int) -> Void

    @State private var editingSegmentID: UUID?
    @State private var originalDraft: String = ""
    @State private var translatedDraft: String = ""
    @State private var textCommitTask: Task<Void, Never>?

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("Framelingo.accentColorName") private var accentColorName: String = AccentColorName.blue.rawValue
    @AppStorage("Framelingo.showTranslation") private var showTranslation: Bool = false
    @AppStorage("Framelingo.showWarnings") private var showWarnings: Bool = false

    private var accent: Color {
        AccentColorName(rawValue: accentColorName)?.color ?? AccentColorName.blue.color
    }

    private var selectedSegment: SubtitleSegment? {
        guard let id = viewModel.selectedSegmentID else { return nil }
        return project.subtitles.first(where: { $0.id == id })
    }

    private var selectedSegmentTextFingerprint: String {
        guard let selectedSegment else {
            return ""
        }

        return [
            selectedSegment.id.uuidString,
            selectedSegment.originalText,
            selectedSegment.translatedText
        ].joined(separator: "\u{1F}")
    }

    var body: some View {
        VStack(spacing: 0) {
            paneHeader
            if let segment = selectedSegment {
                editorContent(segment)
            } else {
                emptyState
            }
            if let autosaveErrorMessage = viewModel.autosaveErrorMessage {
                Divider()
                Label(autosaveErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        }
        .onAppear {
            syncDraftsIfNeeded(for: selectedSegment)
        }
        .onChange(of: selectedSegment?.id) { oldID, _ in
            commitDrafts(for: oldID)
            viewModel.endSubtitleTextEdit()
            syncDraftsIfNeeded(for: selectedSegment)
        }
        .onChange(of: selectedSegmentTextFingerprint) { _, _ in
            syncDraftsIfNeeded(for: selectedSegment)
        }
        .onDisappear {
            commitDrafts(for: editingSegmentID)
            viewModel.endSubtitleTextEdit()
            textCommitTask?.cancel()
        }
        .background(colorScheme == .dark ? Color(white: 0.09) : Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Header

    private var paneHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.cursor")
                .font(.system(size: 12))
            Text("Editor")
                .font(.system(size: 12, weight: .semibold))

            if let seg = selectedSegment {
                Text("· cue #\(seg.index)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let seg = selectedSegment {
                cpsGauge(for: seg)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.03 : 0.025))
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    private func cpsGauge(for segment: SubtitleSegment) -> some View {
        let cps = SubtitleWarningService.cps(for: segment)
        let color: Color = cps > SubtitleWarningService.cpsBad ? .red
            : cps > SubtitleWarningService.cpsWarn ? .orange : .green
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(String(format: "%.1f cps", cps))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Text("Select a cue to edit")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Editor content

    private func editorContent(_ segment: SubtitleSegment) -> some View {
        let draftSegment = segment.withText(
            original: editingSegmentID == segment.id ? originalDraft : segment.originalText,
            translated: editingSegmentID == segment.id ? translatedDraft : segment.translatedText
        )

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                timingRow(segment)
                textField(draftSegment)
                if showTranslation {
                    translationField(draftSegment)
                }
                statsBlock(draftSegment)
            }
            .padding(12)
        }
    }

    // MARK: - Timing row

    private func timingRow(_ segment: SubtitleSegment) -> some View {
        HStack(spacing: 8) {
            speakerPicker(segment)
            inOutFields(segment)
            durationField(segment)
        }
    }

    private func speakerPicker(_ segment: SubtitleSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel("Speaker")
            Picker("", selection: Binding(
                get: { segment.speaker ?? "" },
                set: { newID in
                    var updated = segment
                    updated.speaker = newID.isEmpty ? nil : newID
                    viewModel.updateSubtitle(updated)
                }
            )) {
                Text("None").tag("")
                ForEach(project.speakers) { s in
                    Text(s.name).tag(s.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func inOutFields(_ segment: SubtitleSegment) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("In")
                TimecodeField(
                    milliseconds: segment.startMs,
                    onCommit: { ms in
                        var updated = segment
                        updated.startMs = ms
                        viewModel.updateSubtitle(updated)
                        let resolvedStartMs = viewModel.project?.subtitles
                            .first(where: { $0.id == segment.id })?.startMs ?? ms
                        onSeek(resolvedStartMs)
                    }
                )
            }
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("Out")
                TimecodeField(
                    milliseconds: segment.endMs,
                    onCommit: { ms in
                        var updated = segment
                        updated.endMs = ms
                        viewModel.updateSubtitle(updated)
                    }
                )
            }
        }
    }

    private func durationField(_ segment: SubtitleSegment) -> some View {
        let dur = Double(segment.durationMs) / 1000
        let isOutOfRange = dur < SubtitleWarningService.minDurationSec
            || dur > SubtitleWarningService.maxDurationSec
        return VStack(alignment: .leading, spacing: 4) {
            fieldLabel("Duration")
            Text(String(format: "%.2fs", dur))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isOutOfRange ? Color.orange : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
    }

    // MARK: - Text fields

    private func textField(_ segment: SubtitleSegment) -> some View {
        let charCount = segment.originalText.replacingOccurrences(of: "\n", with: "").count
        let longest = SubtitleWarningService.longestLine(in: segment)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                fieldLabel(showTranslation ? "Source" : "Text")
                Spacer()
                Text("\(charCount) ch · \(longest) per line")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(longest > SubtitleWarningService.lineWarnChars ? Color.orange : .secondary)
            }
            TextEditor(text: Binding(
                get: { originalDraft },
                set: { newText in
                    originalDraft = newText
                    scheduleTextCommit(for: segment.id)
                }
            ))
            .font(.system(size: 13))
            .frame(minHeight: 70)
            .padding(8)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .scrollContentBackground(.hidden)
        }
    }

    private func translationField(_ segment: SubtitleSegment) -> some View {
        let charCount = segment.translatedText.replacingOccurrences(of: "\n", with: "").count
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                fieldLabel("Translation")
                Spacer()
                Text("\(charCount) ch")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: Binding(
                get: { translatedDraft },
                set: { newText in
                    translatedDraft = newText
                    scheduleTextCommit(for: segment.id)
                }
            ))
            .font(.system(size: 13))
            .frame(minHeight: 70)
            .padding(8)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Stats

    private func statsBlock(_ segment: SubtitleSegment) -> some View {
        let cps = SubtitleWarningService.cps(for: segment)
        let dur = Double(segment.durationMs) / 1000
        let longest = SubtitleWarningService.longestLine(in: segment)
        let lineCount = SubtitleWarningService.lineCount(in: segment)
        let words = segment.originalText.split(separator: " ").count
        let cpsColor: Color = cps > SubtitleWarningService.cpsBad ? .red
            : cps > SubtitleWarningService.cpsWarn ? .orange : .green
        let warnings = showWarnings ? SubtitleWarningService.warnings(for: segment) : []

        return VStack(alignment: .leading, spacing: 8) {
            // Stats row
            HStack(spacing: 16) {
                statPill(label: "CPS", value: String(format: "%.1f", cps), color: cpsColor)
                statPill(label: "Dur", value: String(format: "%.2fs", dur),
                         color: (dur < SubtitleWarningService.minDurationSec || dur > SubtitleWarningService.maxDurationSec) ? .orange : nil)
                statPill(label: "Lines", value: "\(lineCount)", color: nil)
                statPill(label: "Longest", value: "\(longest) ch",
                         color: longest > SubtitleWarningService.lineWarnChars ? .orange : nil)
                statPill(label: "Words", value: "\(words)", color: nil)
            }
            .font(.system(size: 11))

            // Warnings
            if !warnings.isEmpty {
                Divider().opacity(0.5)
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text(warning.message)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(warning.kind == .bad ? Color.red : Color.orange)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func statPill(label: String, value: String, color: Color?) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(color ?? .primary)
        }
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .kerning(0.3)
            .textCase(.uppercase)
    }

    private func syncDraftsIfNeeded(for segment: SubtitleSegment?) {
        guard textCommitTask == nil else {
            return
        }

        let nextOriginalDraft = segment?.originalText ?? ""
        let nextTranslatedDraft = segment?.translatedText ?? ""
        guard editingSegmentID != segment?.id
                || originalDraft != nextOriginalDraft
                || translatedDraft != nextTranslatedDraft else {
            return
        }

        editingSegmentID = segment?.id
        originalDraft = nextOriginalDraft
        translatedDraft = nextTranslatedDraft
    }

    private func scheduleTextCommit(for segmentID: UUID) {
        if editingSegmentID != segmentID {
            syncDraftsIfNeeded(for: project.subtitles.first(where: { $0.id == segmentID }))
        }

        viewModel.beginSubtitleTextEdit(id: segmentID)
        textCommitTask?.cancel()
        textCommitTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(250))
                commitDrafts(for: segmentID)
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func commitDrafts(for segmentID: UUID?) {
        textCommitTask?.cancel()
        textCommitTask = nil

        guard let segmentID,
              var updated = project.subtitles.first(where: { $0.id == segmentID }) else {
            return
        }

        guard updated.originalText != originalDraft || updated.translatedText != translatedDraft else {
            return
        }

        updated.originalText = originalDraft
        updated.translatedText = translatedDraft
        viewModel.updateSubtitle(updated)
    }
}

private extension SubtitleSegment {
    func withText(original: String, translated: String) -> SubtitleSegment {
        var copy = self
        copy.originalText = original
        copy.translatedText = translated
        return copy
    }
}

// MARK: - Timecode field

private struct TimecodeField: View {
    let milliseconds: Int
    let onCommit: (Int) -> Void

    @State private var text: String

    init(milliseconds: Int, onCommit: @escaping (Int) -> Void) {
        self.milliseconds = milliseconds
        self.onCommit = onCommit
        _text = State(initialValue: SubtitleTimeFormatter.format(milliseconds: milliseconds))
    }

    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 11, design: .monospaced))
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .onSubmit { commit() }
            .onChange(of: milliseconds) { _, ms in
                text = SubtitleTimeFormatter.format(milliseconds: ms)
            }
    }

    private func commit() {
        guard let ms = SubtitleTimeFormatter.parse(text) else {
            text = SubtitleTimeFormatter.format(milliseconds: milliseconds)
            return
        }
        onCommit(ms)
    }
}
