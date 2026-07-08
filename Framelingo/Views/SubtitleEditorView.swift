import SwiftUI

struct SubtitleEditorView: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel
    var focusedField: FocusState<SubtitleEditorFocus?>.Binding
    let onSeek: (Int) -> Void
    let onError: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            header

            Divider()

            List(project.subtitles) { segment in
                SubtitleTableRow(
                    segment: segment,
                    speakerLabels: project.speakerLabels,
                    isActive: viewModel.activeSegmentID == segment.id,
                    isSelected: viewModel.selectedSegmentID == segment.id,
                    focusedField: focusedField,
                    onSelect: {
                        viewModel.selectSegment(id: segment.id)
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

            if let autosaveErrorMessage = viewModel.autosaveErrorMessage {
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
            .disabled(viewModel.selectedSegmentID == nil)

            Button("Merge") {
                mergeSelectedSegment()
            }
            .disabled(!canMergeSelectedSegment)

            Button("Add") {
                addSegmentAfterSelected()
            }
            .disabled(viewModel.selectedSegmentID == nil)

            Button("Delete", role: .destructive) {
                deleteSelectedSegment()
            }
            .disabled(viewModel.selectedSegmentID == nil)
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
        guard let selectedSegmentID = viewModel.selectedSegmentID,
              let index = project.subtitles.firstIndex(where: { $0.id == selectedSegmentID }) else {
            return false
        }

        return index + 1 < project.subtitles.count
    }

    private func updateSegment(_ segment: SubtitleSegment) {
        viewModel.updateSubtitle(segment)
        if let autosaveErrorMessage = viewModel.autosaveErrorMessage {
            onError(autosaveErrorMessage)
        }
    }

    private func rowBackground(for segment: SubtitleSegment) -> Color {
        if viewModel.selectedSegmentID == segment.id {
            return Color.accentColor.opacity(0.24)
        }

        if viewModel.activeSegmentID == segment.id {
            return Color.accentColor.opacity(0.16)
        }

        return Color.clear
    }

    private func splitSelectedSegment() {
        guard let selectedSegmentID = viewModel.selectedSegmentID else {
            return
        }

        if let newID = viewModel.splitSegment(id: selectedSegmentID) {
            viewModel.selectSegment(id: newID)
        }

        if let autosaveErrorMessage = viewModel.autosaveErrorMessage {
            onError(autosaveErrorMessage)
        }
    }

    private func mergeSelectedSegment() {
        guard let selectedSegmentID = viewModel.selectedSegmentID else {
            return
        }

        viewModel.selectSegment(id: viewModel.mergeWithNextSegment(id: selectedSegmentID) ?? selectedSegmentID)

        if let autosaveErrorMessage = viewModel.autosaveErrorMessage {
            onError(autosaveErrorMessage)
        }
    }

    private func deleteSelectedSegment() {
        guard let selectedSegmentID = viewModel.selectedSegmentID else {
            return
        }

        viewModel.selectSegment(id: viewModel.deleteSegment(id: selectedSegmentID))
    }

    private func addSegmentAfterSelected() {
        guard let selectedSegmentID = viewModel.selectedSegmentID else {
            return
        }

        viewModel.selectSegment(id: viewModel.addSegmentAfter(id: selectedSegmentID) ?? selectedSegmentID)
    }
}
