import SwiftUI

struct CueListView: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel
    var focusedField: FocusState<SubtitleEditorFocus?>.Binding
    let onSeek: (Int) -> Void
    let onError: (String) -> Void

    @State private var searchText: String = ""
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var viewportHeight: CGFloat = 0

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("Framelingo.accentColorName") private var accentColorName: String = AccentColorName.blue.rawValue
    @AppStorage("Framelingo.density") private var density: EditorDensity = .comfy
    @AppStorage("Framelingo.showWarnings") private var showWarnings: Bool = false

    private var accent: Color {
        AccentColorName(rawValue: accentColorName)?.color ?? AccentColorName.blue.color
    }

    private var filtered: [SubtitleSegment] {
        guard !searchText.isEmpty else { return project.subtitles }
        let q = searchText.lowercased()
        return project.subtitles.filter {
            $0.originalText.lowercased().contains(q) || $0.translatedText.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            listHeader
            columnHeaders
            cueList
            listFooter
        }
        .background(colorScheme == .dark ? Color(white: 0.09) : Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Header

    private var listHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.bullet")
                .font(.system(size: 12))
            Text("Cues")
                .font(.system(size: 12, weight: .semibold))
            Text("\(filtered.count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            searchField
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.03 : 0.025))
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Filter…", text: $searchText)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(width: 130, height: 22)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Column headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 42, alignment: .leading)
            Text("In")
                .frame(width: 78, alignment: .leading)
            Text("Out")
                .frame(width: 78, alignment: .leading)
            Text("Text")
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 26)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .kerning(0.3)
        .textCase(.uppercase)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    // MARK: - Cue list

    private var cueList: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                cueListContent
                    .onAppear {
                        viewportHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size.height) { _, height in
                        viewportHeight = height
                    }
                    .onPreferenceChange(CueRowFramePreferenceKey.self) { frames in
                        rowFrames = frames
                    }
                    .onChange(of: viewModel.selectedSegmentID) { _, id in
                        guard let id, id != viewModel.activeSegmentID else { return }
                        scrollCueIfNeeded(id: id, proxy: proxy)
                    }
                    .onChange(of: viewModel.activeSegmentID) { _, id in
                        guard let id, filtered.contains(where: { $0.id == id }) else { return }
                        scrollCueIfNeeded(id: id, proxy: proxy)
                    }
            }
        }
    }

    private var cueListContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered) { segment in
                    cueRow(for: segment)
                        .id(segment.id)
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: CueRowFramePreferenceKey.self,
                                    value: [segment.id: geometry.frame(in: .named("CueListScroll"))]
                                )
                            }
                        )
                }
            }
        }
        .coordinateSpace(name: "CueListScroll")
    }

    private func scrollCueIfNeeded(id: UUID, proxy: ScrollViewProxy) {
        let edgePadding: CGFloat = 40
        let animation = Animation.easeInOut(duration: 0.22)

        if let frame = rowFrames[id] {
            if frame.minY < edgePadding {
                withAnimation(animation) { proxy.scrollTo(id, anchor: .top) }
            } else if frame.maxY > viewportHeight - edgePadding {
                withAnimation(animation) { proxy.scrollTo(id, anchor: .bottom) }
            }
            return
        }

        guard let targetIndex = filtered.firstIndex(where: { $0.id == id }) else { return }
        let visibleIndices = rowFrames.compactMap { rowID, frame -> Int? in
            guard frame.maxY >= 0,
                  frame.minY <= viewportHeight,
                  let index = filtered.firstIndex(where: { $0.id == rowID }) else {
                return nil
            }
            return index
        }

        guard let firstVisibleIndex = visibleIndices.min(),
              let lastVisibleIndex = visibleIndices.max() else {
            withAnimation(animation) { proxy.scrollTo(id, anchor: .bottom) }
            return
        }

        if targetIndex < firstVisibleIndex {
            withAnimation(animation) { proxy.scrollTo(id, anchor: .top) }
        } else if targetIndex > lastVisibleIndex {
            withAnimation(animation) { proxy.scrollTo(id, anchor: .bottom) }
        }
    }

    private func cueRow(for segment: SubtitleSegment) -> some View {
        let idx = (project.subtitles.firstIndex(where: { $0.id == segment.id }) ?? 0) + 1
        return CueRow(
            segment: segment,
            index: idx,
            speaker: project.speaker(for: segment),
            speakerLabels: project.speakerLabels,
            isSelected: viewModel.selectedSegmentID == segment.id,
            isActive: viewModel.activeSegmentID == segment.id,
            showWarnings: showWarnings,
            density: density,
            accent: accent,
            focusedField: focusedField,
            onSelect: {
                viewModel.selectSegment(id: segment.id)
                onSeek(segment.startMs)
            },
            onUpdate: { updated in
                viewModel.updateSubtitle(updated)
                if let err = viewModel.autosaveErrorMessage { onError(err) }
            },
            onValidationError: onError
        )
    }

    // MARK: - Footer

    private var listFooter: some View {
        HStack(spacing: 4) {
            footerButton(label: "Add", icon: "plus") {
                guard let id = viewModel.selectedSegmentID else { return }
                viewModel.selectSegment(id: viewModel.addSegmentAfter(id: id) ?? id)
            }
            .disabled(viewModel.selectedSegmentID == nil)

            footerButton(label: "Split", icon: "scissors") {
                guard let id = viewModel.selectedSegmentID,
                      let newID = viewModel.splitSegment(id: id) else { return }
                viewModel.selectSegment(id: newID)
            }
            .disabled(viewModel.selectedSegmentID == nil)

            footerButton(label: "Merge", icon: "arrow.triangle.merge") {
                guard let id = viewModel.selectedSegmentID else { return }
                viewModel.selectSegment(id: viewModel.mergeWithNextSegment(id: id) ?? id)
            }
            .disabled(!canMerge)

            Spacer()

            footerButton(label: "Delete", icon: "trash", role: .destructive) {
                guard let id = viewModel.selectedSegmentID else { return }
                viewModel.selectSegment(id: viewModel.deleteSegment(id: id))
            }
            .disabled(viewModel.selectedSegmentID == nil)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.03 : 0.025))
        .overlay(alignment: .top) { Divider().opacity(0.5) }
    }

    private func footerButton(
        label: String,
        icon: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 11))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .primary)
    }

    private var canMerge: Bool {
        guard let id = viewModel.selectedSegmentID,
              let idx = project.subtitles.firstIndex(where: { $0.id == id }) else { return false }
        return idx + 1 < project.subtitles.count
    }
}

// MARK: - Cue row

private struct CueRow: View {
    let segment: SubtitleSegment
    let index: Int
    let speaker: Speaker?
    let speakerLabels: [SpeakerLabel]
    let isSelected: Bool
    let isActive: Bool
    let showWarnings: Bool
    let density: EditorDensity
    let accent: Color
    var focusedField: FocusState<SubtitleEditorFocus?>.Binding
    let onSelect: () -> Void
    let onUpdate: (SubtitleSegment) -> Void
    let onValidationError: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var warnings: [SubtitleWarning] {
        showWarnings ? SubtitleWarningService.warnings(for: segment) : []
    }

    private var hasBadWarning: Bool {
        warnings.contains(where: { $0.kind == .bad })
    }

    var body: some View {
        HStack(spacing: 0) {
            // Selection accent bar
            Rectangle()
                .fill(isSelected ? accent : Color.clear)
                .frame(width: 2)

            HStack(spacing: 0) {
                // Inline row using existing SubtitleTableRow for editing logic
                SubtitleTableRow(
                    segment: segment,
                    speakerLabels: speakerLabels,
                    isActive: isActive,
                    isSelected: isSelected,
                    focusedField: focusedField,
                    onSelect: onSelect,
                    onUpdate: onUpdate,
                    onValidationError: onValidationError
                )

                // Warning indicator
                if !warnings.isEmpty || !segment.warnings.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(hasBadWarning ? .red : .orange)
                        .frame(width: 26)
                        .help((warnings.map(\.message) + segment.warnings.map(\.rawValue)).joined(separator: " · "))
                } else {
                    Spacer().frame(width: 26)
                }
            }
            .padding(.horizontal, 8)
            .frame(minHeight: density == .compact ? 36 : 48)
            .background(
                isSelected ? accent.opacity(colorScheme == .dark ? 0.13 : 0.08) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }
}

private struct CueRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
