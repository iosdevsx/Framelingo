import Application
import Project
import Shorts
import Subtitles
import VideoRendering
import AppKit
import AVFoundation
import AVKit
import SwiftUI

/// Top area of the `.shorts` workspace mode: vertical 9:16 preview on the
/// left, shorts list + inspector on the right. The shared bottom timeline is
/// owned by `ProjectView`, as in the other modes.
struct ShortsWorkspaceView: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel
    let player: AVPlayer?
    let onSeek: (Int) -> Void

    var body: some View {
        HSplitView {
            ShortsVerticalPreview(
                project: project,
                viewModel: viewModel,
                player: player
            )
            .frame(minWidth: 280, idealWidth: 420, maxWidth: .infinity, minHeight: 260)

            ShortsPanelView(
                project: project,
                viewModel: viewModel,
                onSeek: onSeek
            )
            .frame(minWidth: 340, idealWidth: 420, minHeight: 260)
        }
    }
}

// MARK: - Vertical preview

private struct ShortsVerticalPreview: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel
    let player: AVPlayer?

    @State private var dragStartOffsetX: Double?
    @State private var cropDragTimelineTimeMs: Int?
    @State private var showsSubtitleAppearance = false

    private var canvasSize: CGSize {
        BurnedSubtitleLayoutHelper.verticalCanvasSize
    }

    var body: some View {
        GeometryReader { geometry in
            let canvasRect = VideoExportGeometry.aspectFitRect(
                videoSize: canvasSize,
                in: CGRect(origin: .zero, size: geometry.size).insetBy(dx: 12, dy: 12)
            )

            ZStack {
                Color.black.opacity(0.92)

                canvas(size: canvasRect.size)
                    .frame(width: canvasRect.width, height: canvasRect.height)
                    .compositingGroup()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .position(x: canvasRect.midX, y: canvasRect.midY)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    showsSubtitleAppearance.toggle()
                } label: {
                    Label("Caption Style", systemImage: "paintbrush")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Edit Shorts subtitle appearance")
                .accessibilityHint("Opens appearance controls for burned Shorts subtitles")
                .popover(isPresented: $showsSubtitleAppearance) {
                    ShortsSubtitleAppearancePopover(
                        project: project,
                        viewModel: viewModel
                    )
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func canvas(size: CGSize) -> some View {
        let currentProject = viewModel.project ?? project
        let short = viewModel.selectedShort
        let settings = currentProject.shortsExportSettings
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
                project: currentProject,
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
                short?.cropOffset(atTimelineTimeMs: viewModel.currentTimeMs) ?? 0.5
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
                    let editTimeMs = min(max(viewModel.currentTimeMs, short.startMs), short.endMs)
                    cropDragTimelineTimeMs = editTimeMs
                    dragStartOffsetX = short.cropOffset(atTimelineTimeMs: editTimeMs)
                    viewModel.beginInteractiveShortEdit()
                }

                let delta = Double(value.translation.width / travel)
                let newOffset = min(max((dragStartOffsetX ?? 0.5) - delta, 0), 1)
                viewModel.updateShortCropOffset(
                    id: short.id,
                    timelineTimeMs: cropDragTimelineTimeMs ?? viewModel.currentTimeMs,
                    offsetX: newOffset
                )
            }
            .onEnded { _ in
                guard short != nil, dragStartOffsetX != nil else {
                    return
                }

                dragStartOffsetX = nil
                cropDragTimelineTimeMs = nil
                viewModel.endInteractiveShortEdit(undoActionName: "Adjust Crop Framing")
            }
    }

    private func safeAreaGuides(platform: ShortsPlatform, size: CGSize) -> some View {
        let topHeight = size.height * CGFloat(platform.topSafeAreaFraction)
        let bottomHeight = size.height * CGFloat(platform.bottomSafeAreaFraction)

        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.28))
                .frame(height: topHeight)
            Spacer()
            Rectangle()
                .fill(Color.black.opacity(0.28))
                .frame(height: bottomHeight)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func subtitleOverlay(
        project: Project,
        style: VideoExportSettings,
        platform: ShortsPlatform,
        size: CGSize
    ) -> some View {
        if let cue = currentCue(in: project) {
            ShortsCaptionOverlay(
                cue: cue,
                style: style,
                platform: platform,
                previewSize: size,
                viewModel: viewModel
            )
        }
    }

    private func hookOverlay(layout: BurnedSubtitleLayout, size: CGSize) -> some View {
        let scale = size.width / canvasSize.width
        let fontSize = project.shortsExportSettings.hookFontSize
        let fontName = project.shortsExportSettings.subtitleStyle.fontName

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

    private func currentCue(in project: Project) -> SubtitleSegment? {
        project.subtitles.first {
            viewModel.currentTimeMs >= $0.startMs && viewModel.currentTimeMs <= $0.endMs
        }
    }

    private var sourceAspectRatio: CGFloat {
        guard let info = viewModel.videoSourceInfo, info.width > 0, info.height > 0 else {
            return 16.0 / 9.0
        }

        return CGFloat(info.width) / CGFloat(info.height)
    }
}

private struct ShortsCaptionOverlay: View {
    let cue: SubtitleSegment
    let style: VideoExportSettings
    let platform: ShortsPlatform
    let previewSize: CGSize
    @ObservedObject var viewModel: ProjectViewModel

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
                    viewModel.beginInteractiveShortsSubtitleStyleEdit()
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
                viewModel.updateShortsSubtitleStyle(updatedStyle, registerUndo: false)
            }
            .onEnded { _ in
                guard dragStartPosition != nil else {
                    return
                }

                dragStartPosition = nil
                viewModel.endInteractiveShortsSubtitleStyleEdit(
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
/// (used for the blur-pad background + foreground pair).
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

// MARK: - Shorts panel

private struct ShortsExportRequest: Identifiable {
    let id = UUID()
    var shortIDs: [UUID]
}

private struct ShortsPanelView: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel
    let onSeek: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var cropSliderTimelineTimeMs: Int?
    @State private var showsSettings = false
    @State private var showsCropPoints = false
    @State private var exportRequest: ShortsExportRequest?

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    shortsListSection
                    if !viewModel.shortsSuggestions.isEmpty {
                        suggestionsSection
                    }
                    if let message = viewModel.shortsSuggestionMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if viewModel.selectedShort != nil {
                        inspectorSection
                    }
                }
                .padding(12)
            }
        }
        .background(colorScheme == .dark ? Color(white: 0.09) : Color.white)
        .popover(item: $exportRequest) { request in
            ShortsExportOptionsPopover(
                project: project,
                shorts: project.shorts.filter { request.shortIDs.contains($0.id) },
                viewModel: viewModel
            )
        }
    }

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.portrait.badge.plus")
                .font(.system(size: 12))
            Text("Shorts")
                .font(.system(size: 12, weight: .semibold))
            Text("\(project.shorts.count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                showsSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Shorts defaults")
            .popover(isPresented: $showsSettings) {
                ShortsSettingsPopover(project: project, viewModel: viewModel)
            }

            Button {
                viewModel.generateShortsSuggestions()
            } label: {
                Label("Suggest", systemImage: "sparkles")
            }
            .help("Suggest shorts from pauses and speaker changes")

            Button {
                viewModel.addShortAtPlayhead()
            } label: {
                Label("New", systemImage: "plus")
            }
            .help("New short at the playhead")

            Button {
                exportRequest = ShortsExportRequest(shortIDs: project.shorts.map(\.id))
            } label: {
                Label("Export All", systemImage: "square.and.arrow.up")
            }
            .disabled(project.shorts.isEmpty)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var shortsListSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Marked shorts")

            if project.shorts.isEmpty {
                Text("No shorts yet. Drag on the shorts strip in the timeline, use “New”, or accept a suggestion.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(project.shorts) { short in
                    shortRow(short)
                }
            }
        }
    }

    private func shortRow(_ short: ShortDefinition) -> some View {
        let isSelected = viewModel.shortsSelectedShortID == short.id
        let platform = short.effectivePlatform(default: project.shortsExportSettings.platform)
        let overLimit = short.durationMs > platform.durationLimitMs

        return HStack(spacing: 8) {
            Button {
                viewModel.shortsSelectedShortID = short.id
                onSeek(short.startMs)
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(short.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text("\(SubtitleTimeFormatter.format(milliseconds: short.startMs)) – \(SubtitleTimeFormatter.format(milliseconds: short.endMs))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                            if !short.trimmedHookText.isEmpty {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .help("Has hook title")
                            }
                        }
                    }

                    Spacer()

                    Text(durationText(short.durationMs))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(overLimit ? Color.orange : Color.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (overLimit ? Color.orange.opacity(0.16) : Color.primary.opacity(0.06)),
                            in: Capsule()
                        )
                        .help(overLimit
                            ? "Exceeds the \(platform.displayName) limit of \(durationText(platform.durationLimitMs))"
                            : "Within the \(platform.displayName) limit")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button {
                viewModel.deleteShort(id: short.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Delete short")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 7)
        )
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Suggestions")

            ForEach(viewModel.shortsSuggestions) { suggestion in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(SubtitleTimeFormatter.format(milliseconds: suggestion.startMs)) – \(SubtitleTimeFormatter.format(milliseconds: suggestion.endMs))")
                            .font(.system(size: 10, design: .monospaced))
                        Text("\(suggestion.reason.displayName) · \(durationText(suggestion.durationMs))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Add") {
                        viewModel.acceptShortSuggestion(suggestion)
                    }
                    .controlSize(.mini)

                    Button {
                        viewModel.dismissShortSuggestion(suggestion)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 7))
            }
        }
    }

    private var inspectorSection: some View {
        let settings = project.shortsExportSettings

        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Selected short")

            if let short = viewModel.selectedShort {
                TextField("Short title", text: Binding(
                    get: { short.title },
                    set: { newValue in
                        viewModel.updateShort(id: short.id, undoActionName: "Rename Short") {
                            $0.title = newValue
                        }
                    }
                ))
                .help("Used in the list and {title} filename placeholder; not burned into video")

                TextField("Hook title (burned at the top)", text: Binding(
                    get: { short.hookText },
                    set: { newValue in
                        viewModel.updateShort(id: short.id, undoActionName: "Edit Hook") {
                            $0.hookText = newValue
                        }
                    }
                ))
                .help("Optional title burned into the top of the short")

                Picker("Framing", selection: Binding(
                    get: { short.reframing },
                    set: { newValue in
                        viewModel.updateShort(id: short.id, undoActionName: "Change Framing") {
                            $0.reframing = newValue
                        }
                    }
                )) {
                    Text("Default (\(settings.reframing.displayName))")
                        .tag(ShortsReframing?.none)
                    ForEach(ShortsReframing.allCases) { reframing in
                        Text(reframing.displayName).tag(ShortsReframing?.some(reframing))
                    }
                }

                Picker("Platform", selection: Binding(
                    get: { short.platformOverride },
                    set: { newValue in
                        viewModel.updateShort(id: short.id, undoActionName: "Change Platform") {
                            $0.platformOverride = newValue
                        }
                    }
                )) {
                    Text("Default (\(settings.platform.displayName))")
                        .tag(ShortsPlatform?.none)
                    ForEach(ShortsPlatform.allCases) { platform in
                        Text(platform.displayName).tag(ShortsPlatform?.some(platform))
                    }
                }

                if short.effectiveReframing(default: settings.reframing) == .crop {
                    LabeledContent("Crop position") {
                        Slider(value: Binding(
                            get: {
                                short.cropOffset(atTimelineTimeMs: viewModel.currentTimeMs)
                            },
                            set: { newValue in
                                let editTimeMs = cropSliderTimelineTimeMs
                                    ?? min(max(viewModel.currentTimeMs, short.startMs), short.endMs)
                                viewModel.updateShortCropOffset(
                                    id: short.id,
                                    timelineTimeMs: editTimeMs,
                                    offsetX: newValue
                                )
                            }
                        ), in: 0...1) { isEditing in
                            if isEditing {
                                cropSliderTimelineTimeMs = min(
                                    max(viewModel.currentTimeMs, short.startMs),
                                    short.endMs
                                )
                                viewModel.beginInteractiveShortEdit()
                            } else {
                                cropSliderTimelineTimeMs = nil
                                viewModel.endInteractiveShortEdit(
                                    undoActionName: "Adjust Crop Framing"
                                )
                            }
                        }
                    }

                    Button {
                        viewModel.addCropPointAtPlayhead(shortID: short.id)
                    } label: {
                        Label("Add Crop Point at Playhead", systemImage: "plus.circle")
                    }
                    .disabled(
                        viewModel.currentTimeMs < short.startMs
                            || viewModel.currentTimeMs > short.endMs
                    )
                    .help("Crop changes at the playhead without animation")

                    if !short.cropKeyframes.isEmpty {
                        DisclosureGroup(
                            "Crop points (\(short.cropKeyframes.count))",
                            isExpanded: $showsCropPoints
                        ) {
                            ForEach(short.cropKeyframes.sorted(by: { $0.timeMs < $1.timeMs })) { keyframe in
                                HStack(spacing: 6) {
                                    Button {
                                        onSeek(short.startMs + keyframe.timeMs)
                                    } label: {
                                        Text(SubtitleTimeFormatter.format(milliseconds: keyframe.timeMs))
                                            .font(.system(size: 10, design: .monospaced))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Go to crop point")

                                    Spacer()

                                    Text("\(Int((keyframe.offsetX * 100).rounded()))%")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)

                                    Button {
                                        viewModel.deleteShortCropKeyframe(
                                            shortID: short.id,
                                            keyframeID: keyframe.id
                                        )
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .help("Delete crop point")
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                }

                Button {
                    exportRequest = ShortsExportRequest(shortIDs: [short.id])
                } label: {
                    Label("Export This Short", systemImage: "square.and.arrow.up")
                }
            }
        }
        .controlSize(.small)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .kerning(0.4)
    }

    private func durationText(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1_000
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

}
