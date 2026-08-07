import SpeakerAnalysis
import Subtitles
import SubtitleEditorFeature
import SwiftUI

struct SubtitleEditorView: View {
    let state: SubtitleEditorState
    let actions: SubtitleEditorActions
    var focusedField: FocusState<SubtitleEditorFocus?>.Binding
    let onSeek: (Int) -> Void
    let onError: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            header

            Divider()

            List(state.subtitles) { segment in
                SubtitleTableRow(
                    segment: segment,
                    speakerLabels: state.speakerLabels,
                    isActive: state.activeSegmentID == segment.id,
                    isSelected: state.selectedSegmentID == segment.id,
                    focusedField: focusedField,
                    onSelect: {
                        actions.selectSegment(id: segment.id)
                        onSeek(segment.startMs)
                    },
                    onUpdate: { updatedSegment in
                        updateSegment(updatedSegment)
                    },
                    onValidationError: onError
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                .listRowBackground(rowBackground(for: segment))
            }
            .listStyle(.plain)

            if let autosaveErrorMessage = state.autosaveErrorMessage {
                Divider()
                Label(autosaveErrorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("Subtitle Editor")
                .font(.headline)

            Spacer()

            Button("Split") {
                splitSelectedSegment()
            }
            .disabled(state.selectedSegmentID == nil)

            Button("Merge") {
                mergeSelectedSegment()
            }
            .disabled(!canMergeSelectedSegment)

            Button("Add") {
                addSegmentAfterSelected()
            }
            .disabled(state.selectedSegmentID == nil)

            Button("Delete", role: .destructive) {
                deleteSelectedSegment()
            }
            .disabled(state.selectedSegmentID == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("#")
                .frame(width: 32, alignment: .leading)
            Text("Timing")
                .frame(width: 96, alignment: .leading)
            Text("Original")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Translation")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var canMergeSelectedSegment: Bool {
        guard let selectedSegmentID = state.selectedSegmentID,
              let index = state.subtitles.firstIndex(where: { $0.id == selectedSegmentID }) else {
            return false
        }

        return index + 1 < state.subtitles.count
    }

    private func updateSegment(_ segment: SubtitleSegment) {
        if let errorMessage = actions.updateSubtitle(segment).errorMessage {
            onError(errorMessage)
        }
    }

    private func rowBackground(for segment: SubtitleSegment) -> Color {
        if state.selectedSegmentID == segment.id {
            return Color.accentColor.opacity(0.24)
        }

        if state.activeSegmentID == segment.id {
            return Color.accentColor.opacity(0.16)
        }

        return Color.clear
    }

    private func splitSelectedSegment() {
        guard let selectedSegmentID = state.selectedSegmentID else {
            return
        }

        if let newID = actions.splitSegment(id: selectedSegmentID) {
            actions.selectSegment(id: newID)
        }

        if let autosaveErrorMessage = actions.currentErrorMessage {
            onError(autosaveErrorMessage)
        }
    }

    private func mergeSelectedSegment() {
        guard let selectedSegmentID = state.selectedSegmentID else {
            return
        }

        actions.selectSegment(id: actions.mergeWithNextSegment(id: selectedSegmentID) ?? selectedSegmentID)

        if let autosaveErrorMessage = actions.currentErrorMessage {
            onError(autosaveErrorMessage)
        }
    }

    private func deleteSelectedSegment() {
        guard let selectedSegmentID = state.selectedSegmentID else {
            return
        }

        actions.selectSegment(id: actions.deleteSegment(id: selectedSegmentID))
    }

    private func addSegmentAfterSelected() {
        guard let selectedSegmentID = state.selectedSegmentID else {
            return
        }

        actions.selectSegment(id: actions.addSegmentAfter(id: selectedSegmentID) ?? selectedSegmentID)
    }
}
