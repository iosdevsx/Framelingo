import DesignSystem
import Shorts
import ShortsFeature
import Subtitles
import VideoRendering
import AppKit
import AVFoundation
import AVKit
import SwiftUI

/// Preview-first Shorts workspace. The shared source timeline remains owned by
/// `ProjectView`; this surface owns the stage and one contextual Clips/Edit
/// panel so feature controls never compete with a second bottom inspector.
struct ShortsWorkspaceView: View {
    let state: ShortsWorkspaceState
    let actions: ShortsWorkspaceActions
    let player: AVPlayer?
    let isPlaying: Bool
    let onSeek: (Int) -> Void
    let onTogglePlayback: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var exportRequest: ShortsExportRequest?

    var body: some View {
        let theme = ShortsTheme(dark: colorScheme == .dark)

        HStack(spacing: 0) {
            ShortsStageView(
                theme: theme,
                state: state,
                actions: actions,
                player: player,
                isPlaying: isPlaying,
                onSeek: onSeek,
                onTogglePlayback: onTogglePlayback
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            hairline(theme, vertical: true)

            ShortsContextPanel(
                theme: theme,
                state: state,
                actions: actions,
                player: player,
                onSeek: onSeek,
                onExport: { shortIDs in
                    exportRequest = ShortsExportRequest(shortIDs: shortIDs)
                }
            )
            .frame(minWidth: 280, idealWidth: 310, maxWidth: 340)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .popover(item: $exportRequest) { request in
            ShortsExportOptionsPopover(
                settings: state.exportSettings,
                shorts: state.shorts.filter { request.shortIDs.contains($0.id) },
                actions: actions
            )
        }
    }
}

enum ShortsContextPanelMode: String, CaseIterable, Identifiable {
    case clips
    case edit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clips: "Clips"
        case .edit: "Edit"
        }
    }
}

private struct ShortsContextPanel: View {
    let theme: ShortsTheme
    let state: ShortsWorkspaceState
    let actions: ShortsWorkspaceActions
    let player: AVPlayer?
    let onSeek: (Int) -> Void
    let onExport: ([UUID]) -> Void

    @State private var mode: ShortsContextPanelMode = .clips
    @State private var showsSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline(theme)

            switch mode {
            case .clips:
                ShortsLibraryRail(
                    theme: theme,
                    state: state,
                    actions: actions,
                    player: player,
                    onSeek: onSeek,
                    onEditSelected: { mode = .edit }
                )
            case .edit:
                if let short = state.selectedShort {
                    ShortsInspectorView(
                        theme: theme,
                        state: state,
                        actions: actions,
                        short: short,
                        onSeek: onSeek
                    )
                } else {
                    ContentUnavailableView(
                        "Select a short",
                        systemImage: "rectangle.portrait.on.rectangle.portrait",
                        description: Text("Choose a clip or create one at the playhead before editing.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            hairline(theme)
            footer
        }
        .background(.regularMaterial)
        .onChange(of: state.selectedShortID) { previousID, selectedID in
            if selectedID != nil, selectedID != previousID {
                mode = .edit
            }
        }
    }

    private var header: some View {
        VStack(spacing: DesignSpacing.small) {
            Picker("Shorts panel", selection: $mode) {
                ForEach(ShortsContextPanelMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: DesignSpacing.small) {
                Button {
                    actions.generateSuggestions()
                    mode = .clips
                } label: {
                    Label("Suggest", systemImage: "sparkles")
                }
                .help("Suggest clips from pauses and speaker changes")

                Button {
                    actions.addShortAtPlayhead()
                    mode = .edit
                } label: {
                    Label("New", systemImage: "plus")
                }
                .help("Create a short at the playhead")

                Spacer(minLength: 0)

                Button {
                    showsSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Shorts defaults")
                .popover(isPresented: $showsSettings) {
                    ShortsSettingsPopover(settings: state.exportSettings, actions: actions)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(DesignSpacing.medium)
    }

    @ViewBuilder
    private var footer: some View {
        let selectedIDs = state.selectedShort.map { [$0.id] } ?? []
        let exportsSelection = mode == .edit && !selectedIDs.isEmpty
        let exportIDs = exportsSelection ? selectedIDs : state.shorts.map(\.id)

        HStack(spacing: DesignSpacing.small) {
            Button {
                onExport(exportIDs)
            } label: {
                Label(exportsSelection ? "Export short" : "Export all", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(exportIDs.isEmpty)

            if exportsSelection, state.shorts.count > 1 {
                Menu {
                    Button("Export all \(state.shorts.count) shorts") {
                        onExport(state.shorts.map(\.id))
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .help("More export actions")
            }
        }
        .padding(DesignSpacing.medium)
    }
}

// MARK: - Theme

/// Visual tokens from the design mock, with backgrounds mapped onto the
/// system surfaces the rest of the app uses.
struct ShortsTheme {
    let dark: Bool

    var bg: Color { Color(nsColor: .windowBackgroundColor) }
    var panel: Color { dark ? Color(white: 0.09) : .white }
    var panel2: Color { dark ? Color(white: 0.11) : Color(white: 0.975) }
    var inset: Color { dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03) }
    var line: Color { dark ? Color.white.opacity(0.07) : Color.black.opacity(0.08) }
    var line2: Color { dark ? Color.white.opacity(0.12) : Color.black.opacity(0.14) }
    var fg: Color { dark ? Color.white.opacity(0.94) : Color.black.opacity(0.90) }
    var fg2: Color { dark ? Color.white.opacity(0.58) : Color.black.opacity(0.56) }
    var fg3: Color { dark ? Color.white.opacity(0.36) : Color.black.opacity(0.38) }
}

private func hairline(_ theme: ShortsTheme, vertical: Bool = false) -> some View {
    Rectangle()
        .fill(theme.line)
        .frame(
            width: vertical ? 1 : nil,
            height: vertical ? nil : 1
        )
}

private let shortsWarnColor = Color(red: 1.0, green: 0.624, blue: 0.039)
private let shortsPlayheadColor = Color(red: 1.0, green: 0.271, blue: 0.227)

// MARK: - Shared small pieces

private struct ShortsEyebrow: View {
    let theme: ShortsTheme
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .bold))
            .kerning(0.9)
            .foregroundStyle(theme.fg3)
    }
}

private struct ShortsTagView: View {
    let theme: ShortsTheme
    let text: String
    var icon: String?

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundStyle(theme.fg2)
        .padding(.horizontal, 6)
        .frame(height: 16)
        .background(
            theme.dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 5)
        )
    }
}

private extension View {
    func shortsGhostChrome(_ theme: ShortsTheme, height: CGFloat = 30) -> some View {
        font(.system(size: 12, weight: .medium))
            .foregroundStyle(theme.fg)
            .padding(.horizontal, 11)
            .frame(height: height)
            .background(theme.inset, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }

}

private extension ShortsPlatform {
    var badgeName: String {
        switch self {
        case .youtubeShorts:
            return "Shorts"
        case .tiktok:
            return "TikTok"
        case .instagramReels:
            return "Reels"
        }
    }
}

/// "MM:SS.cs" — the compact clip clock used across the shorts UI.
private func shortsClockText(_ milliseconds: Int) -> String {
    let clamped = max(0, milliseconds)
    let centiseconds = (clamped % 1_000) / 10
    let totalSeconds = clamped / 1_000
    return String(format: "%02d:%02d.%02d", totalSeconds / 60, totalSeconds % 60, centiseconds)
}

/// "MM:SS" for the In/Out meters.
private func shortsMinSecText(_ milliseconds: Int) -> String {
    let totalSeconds = max(0, milliseconds) / 1_000
    return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
}

// MARK: - Stage (9:16 player + transport)

private struct ShortsStageView: View {
    let theme: ShortsTheme
    let state: ShortsWorkspaceState
    let actions: ShortsWorkspaceActions
    let player: AVPlayer?
    let isPlaying: Bool
    let onSeek: (Int) -> Void
    let onTogglePlayback: () -> Void

    @State private var dragStartOffsetX: Double?
    @State private var cropDragTimelineTimeMs: Int?
    @State private var showsSubtitleAppearance = false

    private var canvasSize: CGSize {
        BurnedSubtitleLayoutHelper.verticalCanvasSize
    }

    var body: some View {
        let short = state.selectedShort

        VStack(spacing: 10) {
            GeometryReader { geometry in
                let canvasRect = VideoExportGeometry.aspectFitRect(
                    videoSize: canvasSize,
                    in: CGRect(origin: .zero, size: geometry.size).insetBy(dx: 20, dy: 8)
                )

                canvas(size: canvasRect.size)
                    .frame(width: canvasRect.width, height: canvasRect.height)
                    .compositingGroup()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(theme.line2, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(theme.dark ? 0.4 : 0.22), radius: 24, y: 10)
                    .overlay(alignment: .topTrailing) {
                        captionStylePill
                            .padding(12)
                    }
                    .position(x: canvasRect.midX, y: canvasRect.midY)
            }

            transport(short: short)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
    }

    private var captionStylePill: some View {
        Button {
            showsSubtitleAppearance.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "textformat")
                    .font(.system(size: 11, weight: .semibold))
                Text("Caption style")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.black.opacity(0.55), in: Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.5)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Edit Shorts subtitle appearance")
        .accessibilityHint("Opens appearance controls for burned Shorts subtitles")
        .popover(isPresented: $showsSubtitleAppearance) {
            ShortsSubtitleAppearancePopover(
                state: state,
                actions: actions
            )
        }
    }

    @ViewBuilder
    private func transport(short: ShortDefinition?) -> some View {
        if let short {
            let localMs = min(max(0, state.currentTimeMs - short.startMs), short.durationMs)

            HStack(spacing: 10) {
                Button(action: onTogglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor, in: Circle())
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 5, y: 2)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(isPlaying ? "Pause" : "Play")

                ShortsClipScrubber(
                    theme: theme,
                    valueMs: localMs,
                    durationMs: short.durationMs,
                    keyframes: short.cropKeyframes,
                    onSeek: { onSeek(short.startMs + $0) }
                )

                Text("\(shortsClockText(localMs)) / \(shortsClockText(short.durationMs))")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(theme.fg2)
                    .fixedSize()
            }
            .frame(maxWidth: 460)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
        } else {
            Text("Select a short to preview")
                .font(.system(size: 12.5))
                .foregroundStyle(theme.fg3)
                .frame(height: 30)
        }
    }

    @ViewBuilder
    private func canvas(size: CGSize) -> some View {
        let short = state.selectedShort
        let settings = state.exportSettings
        let subtitleStyle = settings.subtitleStyle
        let reframing = short?.effectiveReframing(default: settings.reframing) ?? settings.reframing
        let platform = short?.effectivePlatform(default: settings.platform) ?? settings.platform

        ZStack {
            Color.black

            if let player {
                videoLayers(player: player, reframing: reframing, short: short, size: size)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .zIndex(0)
            } else {
                ContentUnavailableView("No video", systemImage: "film")
                    .zIndex(0)
            }

            safeAreaGuides(platform: platform, size: size)
                .zIndex(5)

            subtitleOverlay(
                subtitles: state.subtitles,
                style: subtitleStyle,
                platform: platform,
                size: size
            )
            .zIndex(20)

            if let short,
               let hookLayout = BurnedSubtitleLayoutHelper.makeVerticalHookLayout(
                   text: short.hookText,
                   style: subtitleStyle,
                   hookFontSize: settings.hookFontSize,
                   platform: platform
            ) {
                hookOverlay(layout: hookLayout, size: size)
                    .zIndex(30)
            }

            speakerChip
                .zIndex(35)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(10)

            if !settings.burnSubtitlesIntoVideo {
                Text("Preview only · subtitle burn-in is off")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
                    .zIndex(40)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var speakerChip: some View {
        if let cue = currentCue(in: state.subtitles),
           let speakerID = cue.speaker,
           let speaker = state.speakers.first(where: { $0.id == speakerID }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: speaker.colorHex) ?? .gray)
                    .frame(width: 7, height: 7)
                Text(speaker.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 6)
            .padding(.trailing, 9)
            .frame(height: 22)
            .background(.black.opacity(0.5), in: Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.5)
            )
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func videoLayers(
        player: AVPlayer,
        reframing: ShortsReframing,
        short: ShortDefinition?,
        size: CGSize
    ) -> some View {
        let sourceAspect = sourceAspectRatio

        switch reframing {
        case .blurPad:
            PlayerLayerView(player: player, gravity: .resizeAspectFill)
                .blur(radius: 26)
                .opacity(0.85)
            PlayerLayerView(player: player, gravity: .resizeAspect)
        case .crop:
            let videoWidth = max(size.width, size.height * sourceAspect)
            let travel = max(0, videoWidth - size.width)
            let offsetX = CGFloat(
                short?.cropOffset(atTimelineTimeMs: state.currentTimeMs) ?? 0.5
            )

            PlayerLayerView(player: player, gravity: .resizeAspectFill)
                .frame(width: videoWidth, height: size.height)
                .offset(x: (videoWidth - size.width) / 2 - travel * offsetX)
                .gesture(cropDragGesture(travel: travel, short: short))
                .overlay(alignment: .bottom) {
                    if travel > 0, short != nil {
                        Text("Drag to adjust framing")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(.bottom, 8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private func cropDragGesture(travel: CGFloat, short: ShortDefinition?) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let short, travel > 0 else {
                    return
                }

                if dragStartOffsetX == nil {
                    let editTimeMs = min(max(state.currentTimeMs, short.startMs), short.endMs)
                    cropDragTimelineTimeMs = editTimeMs
                    dragStartOffsetX = short.cropOffset(atTimelineTimeMs: editTimeMs)
                    actions.beginInteractiveShortEdit()
                }

                let delta = Double(value.translation.width / travel)
                let newOffset = min(max((dragStartOffsetX ?? 0.5) - delta, 0), 1)
                actions.updateShortCropOffset(
                    id: short.id,
                    timelineTimeMs: cropDragTimelineTimeMs ?? state.currentTimeMs,
                    offsetX: newOffset
                )
            }
            .onEnded { _ in
                guard short != nil, dragStartOffsetX != nil else {
                    return
                }

                dragStartOffsetX = nil
                cropDragTimelineTimeMs = nil
                actions.endInteractiveShortEdit(undoActionName: "Adjust Crop Framing")
            }
    }

    private func safeAreaGuides(platform: ShortsPlatform, size: CGSize) -> some View {
        let topHeight = size.height * CGFloat(platform.topSafeAreaFraction)
        let bottomHeight = size.height * CGFloat(platform.bottomSafeAreaFraction)

        return ZStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.15))
                    .frame(height: topHeight)
                Spacer()
                Rectangle()
                    .fill(Color.black.opacity(0.15))
                    .frame(height: bottomHeight)
            }

            // dashed safe-area frame, as in the design mock
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    Color.white.opacity(0.14),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                .padding(.horizontal, size.width * 0.06)
                .padding(.top, topHeight)
                .padding(.bottom, bottomHeight)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func subtitleOverlay(
        subtitles: [SubtitleSegment],
        style: VideoExportSettings,
        platform: ShortsPlatform,
        size: CGSize
    ) -> some View {
        if let cue = currentCue(in: subtitles) {
            ShortsCaptionOverlay(
                cue: cue,
                style: style,
                platform: platform,
                previewSize: size,
                actions: actions
            )
        }
    }

    private func hookOverlay(layout: BurnedSubtitleLayout, size: CGSize) -> some View {
        let scale = size.width / canvasSize.width
        let fontSize = state.exportSettings.hookFontSize
        let fontName = state.exportSettings.subtitleStyle.fontName

        return Text(layout.wrappedText)
            .font(.custom(fontName, size: fontSize * scale).bold())
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.85), radius: 3)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(width: layout.backgroundRect.width * scale)
            .position(
                x: layout.textPosition.x * scale,
                y: layout.textPosition.y * scale
            )
            .allowsHitTesting(false)
    }

    private func currentCue(in subtitles: [SubtitleSegment]) -> SubtitleSegment? {
        subtitles.first {
            state.currentTimeMs >= $0.startMs && state.currentTimeMs <= $0.endMs
        }
    }

    private var sourceAspectRatio: CGFloat {
        guard let info = state.videoSourceInfo, info.width > 0, info.height > 0 else {
            return 16.0 / 9.0
        }

        return CGFloat(info.width) / CGFloat(info.height)
    }
}

private struct ShortsClipScrubber: View {
    let theme: ShortsTheme
    let valueMs: Int
    let durationMs: Int
    let keyframes: [ShortCropKeyframe]
    let onSeek: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let fraction = durationMs > 0 ? CGFloat(valueMs) / CGFloat(durationMs) : 0
            let midY = geometry.size.height / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.line2)
                    .frame(height: 4)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(4, fraction * width), height: 4)

                ForEach(keyframes) { keyframe in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .rotationEffect(.degrees(45))
                        .overlay(
                            Rectangle()
                                .stroke(Color.black.opacity(0.4), lineWidth: 0.5)
                                .rotationEffect(.degrees(45))
                        )
                        .position(
                            x: CGFloat(keyframe.timeMs) / CGFloat(max(1, durationMs)) * width,
                            y: midY - 6
                        )
                        .help("Crop point @ \(shortsClockText(keyframe.timeMs))")
                }

                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.5), radius: 2.5, y: 1)
                    .position(x: fraction * width, y: midY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dragFraction = min(max(0, value.location.x / width), 1)
                        onSeek(Int(dragFraction * CGFloat(durationMs)))
                    }
            )
        }
        .frame(height: 30)
        .accessibilityLabel("Clip position")
    }
}

// MARK: - Library rail

private struct ShortsLibraryRail: View {
    let theme: ShortsTheme
    let state: ShortsWorkspaceState
    let actions: ShortsWorkspaceActions
    let player: AVPlayer?
    let onSeek: (Int) -> Void
    let onEditSelected: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Your shorts")
                    .font(.headline)
                    .foregroundStyle(theme.fg)
                Spacer()
                Text("\(state.shorts.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.fg2)
            }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if state.shorts.isEmpty {
                        Text("No shorts yet. Drag on the shorts strip in the timeline, use “New”, or accept a suggestion.")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.fg2)
                            .padding(.top, 2)
                    }

                    ForEach(state.shorts) { short in
                        ShortsLibraryCard(
                            theme: theme,
                            state: state,
                            short: short,
                            player: player,
                            isSelected: state.selectedShortID == short.id,
                            onSelect: {
                                actions.selectShort(id: short.id)
                                onSeek(short.startMs)
                                onEditSelected()
                            },
                            onDuplicate: { actions.duplicateShort(id: short.id) },
                            onDelete: { actions.deleteShort(id: short.id) }
                        )
                    }

                    if !state.suggestions.isEmpty {
                        ShortsEyebrow(theme: theme, text: "Suggestions")
                            .padding(.top, 10)

                        ForEach(state.suggestions) { suggestion in
                            suggestionRow(suggestion)
                        }
                    }

                    if let message = state.suggestionMessage {
                        Text(message)
                            .font(.system(size: 10.5))
                            .foregroundStyle(theme.fg3)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.panel)
    }

    private func suggestionRow(_ suggestion: ShortSuggestion) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(SubtitleTimeFormatter.format(milliseconds: suggestion.startMs)) – \(SubtitleTimeFormatter.format(milliseconds: suggestion.endMs))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.fg)
                Text("\(suggestion.reason.displayName) · \(shortsClockText(suggestion.durationMs))")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.fg2)
            }

            Spacer(minLength: 4)

            Button("Add") {
                actions.acceptSuggestion(suggestion)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Color.accentColor)

            Button {
                actions.dismissSuggestion(suggestion)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.fg3)
            }
            .buttonStyle(.plain)
            .help("Dismiss suggestion")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(theme.inset, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.line, lineWidth: 0.5)
        )
    }
}

private struct ShortsLibraryCard: View {
    let theme: ShortsTheme
    let state: ShortsWorkspaceState
    let short: ShortDefinition
    let player: AVPlayer?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let platform = short.effectivePlatform(default: state.exportSettings.platform)
        let reframing = short.effectiveReframing(default: state.exportSettings.reframing)
        let overLimit = short.durationMs > platform.durationLimitMs

        HStack(alignment: .top, spacing: DesignSpacing.extraSmall) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: DesignSpacing.small) {
                    ShortsLibraryThumbnail(theme: theme, player: player, short: short)

                    VStack(alignment: .leading, spacing: DesignSpacing.extraSmall) {
                        Text(short.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.fg)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: DesignSpacing.extraSmall) {
                            ShortsTagView(theme: theme, text: platform.badgeName)
                            ShortsTagView(
                                theme: theme,
                                text: reframing == .blurPad ? "Blur" : "Crop",
                                icon: reframing == .blurPad ? "drop.halffull" : "crop"
                            )
                        }

                        HStack(spacing: DesignSpacing.extraSmall) {
                            Text(shortsClockText(short.durationMs))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(overLimit ? shortsWarnColor : theme.fg2)
                            if overLimit {
                                Label("Over limit", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(shortsWarnColor)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Menu {
                Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("Short actions")
            .accessibilityLabel("Actions for \(short.title)")
        }
        .padding(DesignSpacing.small)
        .background(
            isSelected
                ? Color.accentColor.opacity(theme.dark ? 0.11 : 0.07)
                : theme.inset,
            in: RoundedRectangle(cornerRadius: 11)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.53) : theme.line,
                    lineWidth: isSelected ? 1 : 0.5
                )
        )
        .shadow(
            color: isSelected ? .black.opacity(theme.dark ? 0.22 : 0.10) : .clear,
            radius: 9,
            y: 3
        )
    }

}

/// A real still frame from the source video at the short's start time.
private struct ShortsLibraryThumbnail: View {
    let theme: ShortsTheme
    let player: AVPlayer?
    let short: ShortDefinition

    @State private var image: CGImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(red: 0.078, green: 0.086, blue: 0.11),
                    Color(red: 0.031, green: 0.035, blue: 0.043),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }

            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(height: 2)
                .padding(.horizontal, 3)
                .padding(.bottom, 3)
        }
        .frame(width: 42, height: 42 * 16 / 9)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.line2, lineWidth: 0.5)
        )
        .task(id: "\(short.id)-\(short.startMs)") {
            await loadThumbnail()
        }
    }

    @MainActor
    private func loadThumbnail() async {
        guard let asset = player?.currentItem?.asset else {
            return
        }

        let cacheKey = "\(ObjectIdentifier(asset).hashValue)-\(short.startMs)"
        if let cached = ShortsThumbnailCache.shared.image(for: cacheKey) {
            image = cached
            return
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 320)
        let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        let time = CMTime(value: CMTimeValue(short.startMs), timescale: 1_000)
        guard let result = try? await generator.image(at: time) else {
            return
        }

        ShortsThumbnailCache.shared.store(result.image, for: cacheKey)
        image = result.image
    }
}

@MainActor
private final class ShortsThumbnailCache {
    static let shared = ShortsThumbnailCache()

    private var storage: [String: CGImage] = [:]

    func image(for key: String) -> CGImage? {
        storage[key]
    }

    func store(_ image: CGImage, for key: String) {
        if storage.count > 64 {
            storage.removeAll()
        }
        storage[key] = image
    }
}

// MARK: - Inspector

private struct ShortsInspectorView: View {
    let theme: ShortsTheme
    let state: ShortsWorkspaceState
    let actions: ShortsWorkspaceActions
    let short: ShortDefinition
    let onSeek: (Int) -> Void

    @State private var showsSubtitleAppearance = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: DesignSpacing.small) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Color.accentColor)
                    Text(short.title)
                        .font(.headline)
                        .foregroundStyle(theme.fg)
                        .lineLimit(1)
                    Spacer()
                    Text(shortsClockText(short.durationMs))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.fg2)
                }
                .padding(DesignSpacing.medium)

                hairline(theme)
                detailsSection
                hairline(theme)
                framingSection

                if short.effectiveReframing(default: state.exportSettings.reframing) == .crop {
                    hairline(theme)
                    focusSection
                }

                hairline(theme)
                captionsSection
            }
        }
        .background(theme.panel2)
    }

    // ── Framing / platform ──

    private var framingSection: some View {
        let effectiveReframing = short.effectiveReframing(default: state.exportSettings.reframing)
        let effectivePlatform = short.effectivePlatform(default: state.exportSettings.platform)

        return VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text("Frame")
                .font(.headline)

            Picker("Framing", selection: Binding(
                get: { effectiveReframing },
                set: { setReframing($0) }
            )) {
                Text("Crop").tag(ShortsReframing.crop)
                Text("Blur").tag(ShortsReframing.blurPad)
            }
            .pickerStyle(.segmented)

            Text("Platform")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.fg2)

            HStack(spacing: 4) {
                ForEach(ShortsPlatform.allCases) { platform in
                    platformButton(platform, isOn: effectivePlatform == platform)
                }
            }
        }
        .padding(DesignSpacing.medium)
    }

    private func setReframing(_ reframing: ShortsReframing) {
        actions.updateShort(id: short.id, undoActionName: "Change Framing") {
            $0.reframing = reframing
        }
    }

    private func platformButton(_ platform: ShortsPlatform, isOn: Bool) -> some View {
        Button {
            actions.updateShort(id: short.id, undoActionName: "Change Platform") {
                $0.platformOverride = platform
            }
        } label: {
            Text(platform.badgeName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isOn ? theme.fg : theme.fg2)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    isOn ? Color.accentColor.opacity(theme.dark ? 0.16 : 0.09) : theme.inset,
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            isOn ? Color.accentColor.opacity(0.47) : theme.line,
                            lineWidth: 0.5
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(platform.displayName)
    }

    // ── Focus track ──

    private var focusSection: some View {
        let playheadInside = state.currentTimeMs >= short.startMs
            && state.currentTimeMs <= short.endMs

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                ShortsEyebrow(theme: theme, text: "Focus track")
                Spacer()
                Button {
                    actions.addCropPointAtPlayhead(shortID: short.id)
                } label: {
                    Label("Add point at playhead", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(theme.fg)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(theme.inset, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(theme.line, lineWidth: 0.5)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(!playheadInside)
                .opacity(playheadInside ? 1 : 0.5)
                .help("Crop changes at the playhead without animation")
            }
            .padding(.bottom, 10)

            HStack {
                Text("Horizontal focus")
                    .font(.subheadline)
                    .foregroundStyle(theme.fg2)
                Spacer()
                Text("\(Int((currentCropOffset * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.fg2)
            }

            Slider(
                value: Binding(
                    get: { currentCropOffset },
                    set: { newValue in
                        actions.updateShortCropOffset(
                            id: short.id,
                            timelineTimeMs: cropTimelineTimeMs,
                            offsetX: newValue
                        )
                    }
                ),
                in: 0...1,
                onEditingChanged: { isEditing in
                    if isEditing {
                        actions.beginInteractiveShortEdit()
                    } else {
                        actions.endInteractiveShortEdit(undoActionName: "Adjust Crop Framing")
                    }
                }
            )
            .accessibilityLabel("Horizontal crop focus")
            .accessibilityValue("\(Int((currentCropOffset * 100).rounded())) percent")

            ShortsKeyframeLane(
                theme: theme,
                state: state,
                actions: actions,
                short: short,
                onSeek: { localMs in
                    onSeek(short.startMs + localMs)
                }
            )
        }
        .padding(DesignSpacing.medium)
    }

    private var cropTimelineTimeMs: Int {
        min(max(state.currentTimeMs, short.startMs), short.endMs)
    }

    private var currentCropOffset: Double {
        short.cropOffset(atTimelineTimeMs: cropTimelineTimeMs)
    }

    // ── Details ──

    private var detailsSection: some View {
        let platform = short.effectivePlatform(default: state.exportSettings.platform)
        let overLimit = short.durationMs > platform.durationLimitMs

        return VStack(alignment: .leading, spacing: 0) {
            Text("Clip")
                .font(.headline)
                .padding(.bottom, DesignSpacing.small)

            fieldLabel("Title")
            textField(
                "Short title",
                text: Binding(
                    get: { short.title },
                    set: { newValue in
                        actions.updateShort(id: short.id, undoActionName: "Rename Short") {
                            $0.title = newValue
                        }
                    }
                )
            )
            .help("Used in the list and {title} filename placeholder; not burned into video")
            .padding(.bottom, 9)

            fieldLabel("Hook — burned at top")
            textField(
                "Optional…",
                text: Binding(
                    get: { short.hookText },
                    set: { newValue in
                        actions.updateShort(id: short.id, undoActionName: "Edit Hook") {
                            $0.hookText = newValue
                        }
                    }
                )
            )
            .help("Optional title burned into the top of the short")
            .padding(.bottom, 11)

            HStack(spacing: 8) {
                meter(label: "In", value: shortsMinSecText(short.startMs))
                meter(label: "Out", value: shortsMinSecText(short.endMs))
                meter(
                    label: "Length",
                    value: shortsClockText(short.durationMs),
                    warn: overLimit
                )
            }
        }
        .padding(DesignSpacing.medium)
    }

    private var captionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text("Captions")
                .font(.headline)

            Text("Position captions directly on the preview. Open appearance for font, background, and burn-in settings.")
                .font(.caption)
                .foregroundStyle(theme.fg2)

            Button {
                showsSubtitleAppearance.toggle()
            } label: {
                Label("Caption appearance", systemImage: "textformat")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $showsSubtitleAppearance) {
                ShortsSubtitleAppearancePopover(state: state, actions: actions)
            }
        }
        .padding(DesignSpacing.medium)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .kerning(0.3)
            .foregroundStyle(theme.fg3)
            .padding(.bottom, 4)
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(theme.fg)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(theme.inset, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(theme.line, lineWidth: 0.5)
            )
    }

    private func meter(label: String, value: String, warn: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .kerning(0.4)
                .foregroundStyle(theme.fg3)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(warn ? shortsWarnColor : theme.fg)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.inset, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(theme.line, lineWidth: 0.5)
        )
    }
}

private struct ShortsFramingCard: View {
    let theme: ShortsTheme
    let kind: ShortsReframing
    let isOn: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 7) {
                diagram

                VStack(alignment: .leading, spacing: 1) {
                    Text(kind == .crop ? "Crop" : "Blurred bg")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(theme.fg)
                    Text(kind == .crop ? "Fills frame, pans to subject" : "Full frame, blurred fill")
                        .font(.system(size: 9.5))
                        .foregroundStyle(theme.fg3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isOn ? Color.accentColor.opacity(theme.dark ? 0.12 : 0.07) : theme.inset,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isOn ? Color.accentColor.opacity(0.53) : theme.line,
                        lineWidth: isOn ? 1 : 0.5
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var diagram: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.dark ? Color.black.opacity(0.42) : Color.black.opacity(0.07))

                if kind == .crop {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10))
                        .frame(width: w * 0.88, height: h * 0.64)
                        .offset(x: w * 0.06, y: h * 0.18)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: w * 0.24, height: h * 0.84)
                        .offset(x: w * 0.38, y: h * 0.08)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.33), Color.accentColor.opacity(0.13)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.dark ? Color.white.opacity(0.14) : Color.black.opacity(0.14))
                        .frame(width: w * 0.40, height: h * 0.84)
                        .offset(x: w * 0.30, y: h * 0.08)
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.9))
                        .frame(width: w * 0.40, height: h * 0.28)
                        .offset(x: w * 0.30, y: h * 0.36)
                }
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
    }
}

/// Wide source frame with a draggable 9:16 crop window — the hero control of
/// the Focus track column.
private struct ShortsCropCanvas: View {
    let theme: ShortsTheme
    let state: ShortsWorkspaceState
    let actions: ShortsWorkspaceActions
    let short: ShortDefinition
    let player: AVPlayer?
    let sourceAspect: CGFloat
    let disabled: Bool

    @State private var dragTimelineTimeMs: Int?
    @State private var isDragging = false

    var body: some View {
        let windowFraction = min(1, (9.0 / 16.0) / sourceAspect)
        let cropX = CGFloat(short.cropOffset(atTimelineTimeMs: state.currentTimeMs))

        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let windowWidth = width * windowFraction
            let travel = width - windowWidth
            let windowLeft = travel * cropX

            ZStack(alignment: .topLeading) {
                Color(red: 0.031, green: 0.035, blue: 0.043)

                if let player {
                    PlayerLayerView(player: player, gravity: .resizeAspect)
                }

                // dim everything outside the 9:16 window
                HStack(spacing: 0) {
                    Color.black.opacity(0.55)
                        .frame(width: windowLeft)
                    Color.clear
                        .frame(width: windowWidth)
                    Color.black.opacity(0.55)
                }
                .allowsHitTesting(false)

                // window chrome: border, thirds, grabber
                ZStack {
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 1.5)

                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 1)
                        Spacer()
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 1)
                        Spacer()
                    }

                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color.accentColor, lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: "dot.scope")
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                        )
                }
                .frame(width: windowWidth, height: geometry.size.height)
                .offset(x: windowLeft)
                .allowsHitTesting(false)

                Text(disabled
                    ? "Crop disabled — using blurred background"
                    : "focus \(Int((cropX * 100).rounded()))%")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 4))
                    .offset(x: 8, y: geometry.size.height - 22)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(width: width, windowFraction: windowFraction))
        }
        .aspectRatio(sourceAspect, contentMode: .fit)
        .frame(maxHeight: 132)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(theme.line2, lineWidth: 0.5)
        )
        .opacity(disabled ? 0.45 : 1)
        .accessibilityLabel("Crop focus")
        .accessibilityHint("Drag horizontally to move the 9 by 16 crop window")
    }

    private func dragGesture(width: CGFloat, windowFraction: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !disabled, windowFraction < 1 else {
                    return
                }

                if !isDragging {
                    isDragging = true
                    dragTimelineTimeMs = min(
                        max(state.currentTimeMs, short.startMs),
                        short.endMs
                    )
                    actions.beginInteractiveShortEdit()
                }

                let half = windowFraction / 2
                let fraction = value.location.x / width
                let newX = min(max(0, (fraction - half) / (1 - 2 * half)), 1)
                actions.updateShortCropOffset(
                    id: short.id,
                    timelineTimeMs: dragTimelineTimeMs ?? state.currentTimeMs,
                    offsetX: Double(newX)
                )
            }
            .onEnded { _ in
                guard isDragging else {
                    return
                }

                isDragging = false
                dragTimelineTimeMs = nil
                actions.endInteractiveShortEdit(undoActionName: "Adjust Crop Framing")
            }
    }
}

private struct ShortsKeyframeLane: View {
    let theme: ShortsTheme
    let state: ShortsWorkspaceState
    let actions: ShortsWorkspaceActions
    let short: ShortDefinition
    let onSeek: (Int) -> Void

    var body: some View {
        let keyframes = short.cropKeyframes.sorted { $0.timeMs < $1.timeMs }
        let durationMs = max(1, short.durationMs)
        let localMs = min(max(0, state.currentTimeMs - short.startMs), short.durationMs)

        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geometry in
                let width = max(1, geometry.size.width)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(theme.inset)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(theme.line, lineWidth: 0.5)
                        )

                    ForEach(keyframes) { keyframe in
                        let x = CGFloat(keyframe.timeMs) / CGFloat(durationMs) * width

                        Menu {
                            Button("Go to point", systemImage: "scope") {
                                onSeek(keyframe.timeMs)
                            }
                            Divider()
                            Button("Delete point", systemImage: "trash", role: .destructive) {
                                actions.deleteShortCropKeyframe(
                                    shortID: short.id,
                                    keyframeID: keyframe.id
                                )
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.accentColor)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Image(systemName: "diamond.fill")
                                        .font(.system(size: 7))
                                        .foregroundStyle(.white)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .position(x: min(max(9, x), width - 9), y: 13)
                        .help("\(shortsClockText(keyframe.timeMs)) · focus \(Int((keyframe.offsetX * 100).rounded()))% · click for actions")
                        .accessibilityLabel("Crop point at \(shortsClockText(keyframe.timeMs))")
                    }

                    Rectangle()
                        .fill(shortsPlayheadColor)
                        .frame(width: 1.5)
                        .offset(x: CGFloat(localMs) / CGFloat(durationMs) * width)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 26)

            Text("\(keyframes.count) crop point\(keyframes.count == 1 ? "" : "s") · click a point for actions")
                .font(.system(size: 9.5))
                .foregroundStyle(theme.fg3)
        }
        .padding(.top, 10)
    }
}

// MARK: - Caption overlay (drag-to-position burned subtitles)

private struct ShortsCaptionOverlay: View {
    let cue: SubtitleSegment
    let style: VideoExportSettings
    let platform: ShortsPlatform
    let previewSize: CGSize
    let actions: ShortsWorkspaceActions

    @State private var dragStartPosition: CGPoint?

    private var canvasSize: CGSize {
        BurnedSubtitleLayoutHelper.verticalCanvasSize
    }

    var body: some View {
        if let layout = BurnedSubtitleLayoutHelper.makeVerticalPreviewCaptionLayout(
            for: cue,
            settings: style,
            platform: platform
        ) {
            let scale = previewSize.width / canvasSize.width
            let width = layout.backgroundRect.width * scale
            let height = layout.backgroundRect.height * scale
            let shape = RoundedRectangle(
                cornerRadius: max(0, style.backgroundCornerRadius * scale)
            )

            ZStack {
                shape
                    .fill(
                        style.backgroundEnabled
                            ? backgroundColor.opacity(clamped(style.backgroundOpacity))
                            : Color.clear
                    )
                    .overlay {
                        shape.stroke(
                            borderColor,
                            lineWidth: max(0, style.borderWidth * scale)
                        )
                    }

                Text(layout.wrappedText)
                    .font(.custom(style.fontName, size: style.fontSize * scale))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(max(1, style.maxLines))
                    .frame(maxWidth: max(1, width - 28 * scale))
            }
            .frame(width: width, height: height)
            .contentShape(shape)
            .position(
                x: layout.textPosition.x * scale,
                y: layout.textPosition.y * scale
            )
            .gesture(positionDragGesture)
            .onHover { isHovering in
                if isHovering {
                    NSCursor.openHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .accessibilityLabel("Shorts subtitle position")
            .accessibilityHint("Drag to reposition burned subtitles")
        }
    }

    private var positionDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartPosition == nil {
                    dragStartPosition = CGPoint(
                        x: style.subtitlePositionX,
                        y: style.subtitlePositionY
                    )
                    actions.beginInteractiveSubtitleStyleEdit()
                }

                guard let dragStartPosition,
                      previewSize.width > 0,
                      previewSize.height > 0 else {
                    return
                }

                var updatedStyle = style
                updatedStyle.subtitlePositionX = Double(
                    dragStartPosition.x + value.translation.width / previewSize.width
                )
                updatedStyle.subtitlePositionY = Double(
                    dragStartPosition.y + value.translation.height / previewSize.height
                )

                guard let layout = BurnedSubtitleLayoutHelper.makeVerticalPreviewCaptionLayout(
                    for: cue,
                    settings: updatedStyle,
                    platform: platform
                ) else {
                    return
                }

                let normalized = BurnedSubtitleLayoutHelper.normalizedPosition(for: layout)
                updatedStyle.subtitlePositionX = Double(normalized.x)
                updatedStyle.subtitlePositionY = Double(normalized.y)
                updatedStyle.subtitlePosition = nearestPosition(for: Double(normalized.y))
                actions.updateSubtitleStyle(updatedStyle, registerUndo: false)
            }
            .onEnded { _ in
                guard dragStartPosition != nil else {
                    return
                }

                dragStartPosition = nil
                actions.endInteractiveSubtitleStyleEdit(
                    undoActionName: "Position Shorts Subtitles"
                )
            }
    }

    private var textColor: Color {
        Color(
            red: clamped(style.textColorRed),
            green: clamped(style.textColorGreen),
            blue: clamped(style.textColorBlue)
        )
    }

    private var backgroundColor: Color {
        Color(
            red: clamped(style.backgroundColorRed),
            green: clamped(style.backgroundColorGreen),
            blue: clamped(style.backgroundColorBlue)
        )
    }

    private var borderColor: Color {
        guard style.backgroundEnabled, style.borderEnabled else {
            return .clear
        }

        return Color(
            red: clamped(style.borderColorRed),
            green: clamped(style.borderColorGreen),
            blue: clamped(style.borderColorBlue)
        )
        .opacity(clamped(style.borderOpacity))
    }

    private func nearestPosition(for y: Double) -> SubtitlePosition {
        if y < 0.33 {
            return .top
        }
        if y > 0.66 {
            return .bottom
        }
        return .center
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// An `AVPlayerLayer` host. Multiple instances may share one `AVPlayer`
/// (used for the blur-pad background + foreground pair and the crop canvas).
private struct PlayerLayerView: NSViewRepresentable {
    let player: AVPlayer
    let gravity: AVLayerVideoGravity

    final class LayerHostView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer = CALayer()
            layer?.addSublayer(playerLayer)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }

    func makeNSView(context: Context) -> LayerHostView {
        let view = LayerHostView(frame: .zero)
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
        return view
    }

    func updateNSView(_ nsView: LayerHostView, context: Context) {
        if nsView.playerLayer.player !== player {
            nsView.playerLayer.player = player
        }
        nsView.playerLayer.videoGravity = gravity
    }

    static func dismantleNSView(_ nsView: LayerHostView, coordinator: ()) {
        nsView.playerLayer.player = nil
    }
}

// MARK: - Export request

private struct ShortsExportRequest: Identifiable {
    let id = UUID()
    var shortIDs: [UUID]
}
