import SwiftUI

public struct LayoutSwitcherView: View {
    @Binding var selected: SubtitleLayoutMode
    let accent: Color

    public init(selected: Binding<SubtitleLayoutMode>, accent: Color) {
        _selected = selected
        self.accent = accent
    }

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
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
