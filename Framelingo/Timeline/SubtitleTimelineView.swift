import AppKit
import QuartzCore
import SwiftUI

struct SubtitleTimelineView: View {
    @Binding var subtitles: [SubtitleSegment]
    @Binding var selectedSegmentID: UUID?
    let currentTimeMs: Int
    let durationMs: Int
    let waveformPeaks: [Double]
    let speakers: [Speaker]
    @Binding var zoomFactor: Double
    @Binding var scrollToPlayheadRequest: Int
    @Binding var showsWaveform: Bool
    let onSeek: (Int) -> Void
    let onBeginTextEditing: (UUID) -> Void
    let onTranslatedTextChange: (UUID, String) -> Void
    let onEndTextEditing: () -> Void

    @State private var dragBaseSubtitles: [SubtitleSegment]?
    @State private var draftSubtitles: [SubtitleSegment]?
    @State private var suppressNextSelectionScroll = false
    @State private var scrollTarget: TimelineScrollTarget?
    @State private var timelineScrollOffsetX: CGFloat = 0
    @State private var editingSegmentID: UUID?
    @State private var editingText = ""
    @FocusState private var focusedTimelineEditorID: UUID?

    private let basePxPerMs: CGFloat = 0.08
    private let headerHeight: CGFloat = 34
    private let rulerHeight: CGFloat = 24
    private let waveformHeight: CGFloat = 74
    private let cueTrackHeight: CGFloat = 34
    private let handleWidth: CGFloat = 6
    private let waveformToggleAnimation = Animation.smooth(duration: 0.28)

    var body: some View {
        VStack(spacing: 0) {
            timelineHeader

            GeometryReader { geometry in
                let effectiveDurationMs = effectiveDurationMs

                let allSubtitles = displaySubtitles

                if allSubtitles.isEmpty {
                    emptyState("No subtitles yet. Generate or import subtitles first.")
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if effectiveDurationMs <= 0 {
                    emptyState("Timeline duration is unavailable.")
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    let timelineWidth = max(
                        geometry.size.width,
                        CGFloat(effectiveDurationMs) * basePxPerMs * zoomFactor
                    )
                    let pxPerMs = timelineWidth / CGFloat(effectiveDurationMs)
                    let visibleRange = TimelineVisibleRange.visible(
                        scrollOffsetX: timelineScrollOffsetX,
                        viewportWidth: geometry.size.width,
                        pxPerMs: pxPerMs,
                        durationMs: effectiveDurationMs
                    ) ?? .full(durationMs: effectiveDurationMs)
                    let visibleSubtitles = Array(TimelinePerformance.visibleSegments(
                        in: allSubtitles,
                        range: visibleRange
                    ))
                    let visibleWaveformHeight = showsWaveform ? waveformHeight : 0
                    let contentHeight = max(geometry.size.height, rulerHeight + visibleWaveformHeight + cueTrackHeight + 14)
                    let blockTopY = rulerHeight + visibleWaveformHeight + 4

                    timelineScroller(
                        width: timelineWidth,
                        pxPerMs: pxPerMs,
                        durationMs: effectiveDurationMs,
                        viewportWidth: geometry.size.width,
                        visibleRange: visibleRange,
                        visibleSubtitles: visibleSubtitles,
                        contentHeight: contentHeight,
                        visibleWaveformHeight: visibleWaveformHeight,
                        blockHeight: cueTrackHeight,
                        blockTopY: blockTopY
                    )
                }
            }
        }
        .background(timelineBackground)
        .foregroundStyle(.white)
    }

    private var timelineHeader: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(waveformToggleAnimation) {
                    showsWaveform.toggle()
                }
            } label: {
                Image(systemName: showsWaveform ? "waveform" : "waveform.slash")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(showsWaveform ? .white.opacity(0.82) : .white.opacity(0.45))
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(showsWaveform ? accentBlue.opacity(0.22) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(showsWaveform ? accentBlue.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 0.75)
            )
            .help(showsWaveform ? "Hide waveform" : "Show waveform")

            Text("Timeline")
                .font(.system(size: 12, weight: .semibold))

            Text("·")
                .foregroundStyle(.white.opacity(0.28))

            Text("\(displaySubtitles.count) cues")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))

            Text("·")
                .foregroundStyle(.white.opacity(0.28))

            Text(SubtitleTimeFormatter.format(milliseconds: currentTimeMs))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))

            Spacer()

            zoomButton(systemName: "minus") {
                zoomFactor = max(0.35, zoomFactor / 1.25)
            }

            Text("\(Int((zoomFactor * 100).rounded()))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
                .frame(width: 42)

            zoomButton(systemName: "plus") {
                zoomFactor = min(6, zoomFactor * 1.25)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: headerHeight)
        .background(Color.white.opacity(0.018))
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.white.opacity(0.06))
        }
    }

    private func zoomButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.48))
    }

    private func timelineScroller(
        width: CGFloat,
        pxPerMs: CGFloat,
        durationMs: Int,
        viewportWidth: CGFloat,
        visibleRange: TimelineVisibleRange,
        visibleSubtitles: [SubtitleSegment],
        contentHeight: CGFloat,
        visibleWaveformHeight: CGFloat,
        blockHeight: CGFloat,
        blockTopY: CGFloat
    ) -> some View {
        ScrollView(.horizontal) {
            ZStack(alignment: .topLeading) {
                    TimelineRulerView(durationMs: durationMs, pxPerMs: pxPerMs)
                        .frame(width: width, height: rulerHeight)

                    TimelineWaveformView(
                        durationMs: durationMs,
                        peaks: waveformPeaks,
                        pxPerMs: pxPerMs,
                        visibleRange: visibleRange,
                        targetBucketCount: max(1, Int((viewportWidth * 1.5).rounded()))
                    )
                    .frame(width: width, height: visibleWaveformHeight)
                    .offset(y: rulerHeight)
                    .opacity(showsWaveform ? 1 : 0)
                    .clipped()
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(accentBlue.opacity(0.10))
                            .frame(width: playheadX(pxPerMs: pxPerMs, durationMs: durationMs), height: visibleWaveformHeight)
                            .allowsHitTesting(false)
                    }

                    ForEach(visibleSubtitles) { segment in
                        let blockWidth = max(CGFloat(segment.endMs - segment.startMs) * pxPerMs, 12)
                        SubtitleTimelineBlockView(
                            segment: segment,
                            isSelected: selectedSegmentID == segment.id,
                            isEditing: editingSegmentID == segment.id,
                            editingText: editingTextBinding(for: segment),
                            focusedEditorID: $focusedTimelineEditorID,
                            isActive: currentTimeMs >= segment.startMs && currentTimeMs <= segment.endMs,
                            blockHeight: blockHeight,
                            speakerColor: speakerColor(for: segment),
                            onBeginEditing: {
                                beginEditing(segment)
                            },
                            onCommitEditing: commitTimelineTextEdit
                        )
                        .frame(width: blockWidth, height: blockHeight)
                        .position(
                            x: CGFloat(segment.startMs) * pxPerMs + blockWidth / 2,
                            y: blockTopY + blockHeight / 2
                        )
                        .id(segment.id)
                        .allowsHitTesting(editingSegmentID == segment.id)
                    }

                    Rectangle()
                        .fill(accentBlue)
                        .frame(width: 1.5, height: contentHeight)
                        .offset(x: playheadX(pxPerMs: pxPerMs, durationMs: durationMs))
                        .shadow(color: accentBlue.opacity(0.55), radius: 4)

                    PlayheadCap()
                        .fill(accentBlue)
                        .frame(width: 12, height: 8)
                        .offset(x: playheadX(pxPerMs: pxPerMs, durationMs: durationMs) - 6, y: 0)

                    Color.clear
                        .frame(width: 1, height: 1)
                        .offset(x: playheadX(pxPerMs: pxPerMs, durationMs: durationMs))
                        .id("timeline-playhead")

                    TimelineScrollController(target: scrollTarget)
                        .frame(width: 1, height: 1)
                        .allowsHitTesting(false)

                    SubtitleTimelineInteractionOverlay(
                        segments: visibleSubtitles,
                        pxPerMs: pxPerMs,
                        durationMs: durationMs,
                        editingSegmentID: editingSegmentID,
                        rulerHeight: rulerHeight,
                        blockTopY: blockTopY,
                        blockHeight: blockHeight,
                        handleWidth: handleWidth,
                        onRulerSeek: { milliseconds in
                            endTimelineTextEdit()
                            onSeek(milliseconds)
                        },
                        onSelect: { id in
                            suppressNextSelectionScroll = true
                            selectedSegmentID = id
                        },
                        onBlockClick: { segment in
                            suppressNextSelectionScroll = true
                            endTimelineTextEdit()
                            selectedSegmentID = segment.id
                            onSeek(segment.startMs)
                        },
                        onBlockDoubleClick: { segment in
                            beginEditing(segment)
                        },
                        onEndEditing: commitTimelineTextEdit,
                        onDragChanged: { id, edge, deltaX in
                            updateDraftSegment(
                                id: id,
                                deltaX: deltaX,
                                edge: edge,
                                pxPerMs: pxPerMs,
                                durationMs: durationMs
                            )
                        },
                        onDragEnded: commitDraftSubtitles
                    )
                    .frame(width: width, height: contentHeight)

                    TimelineEditingFocusBoundary(
                        editingSegmentID: editingSegmentID,
                        onEndEditing: endTimelineTextEdit
                    )
                    .frame(width: width, height: contentHeight)
                    .allowsHitTesting(false)
                }
                .frame(width: width, height: contentHeight, alignment: .topLeading)
                .padding(.horizontal, 10)
                .padding(.vertical, 0)
                .clipped()
                .animation(waveformToggleAnimation, value: showsWaveform)
        }
        .onChange(of: scrollToPlayheadRequest) { _, _ in
            scrollTarget = TimelineScrollTarget(x: playheadX(pxPerMs: pxPerMs, durationMs: durationMs))
        }
        .onChange(of: selectedSegmentID) { _, id in
            if suppressNextSelectionScroll {
                suppressNextSelectionScroll = false
                return
            }

            guard let id,
                  let segment = subtitles.first(where: { $0.id == id }) else {
                return
            }

            scrollTarget = TimelineScrollTarget(x: CGFloat(segment.startMs) * pxPerMs)
        }
        .onChange(of: focusedTimelineEditorID) { _, id in
            if id == nil, editingSegmentID != nil {
                commitTimelineTextEdit()
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x
        } action: { _, newValue in
            timelineScrollOffsetX = max(0, newValue)
        }
    }

    private func playheadX(pxPerMs: CGFloat, durationMs: Int) -> CGFloat {
        CGFloat(min(max(currentTimeMs, 0), durationMs)) * pxPerMs
    }

    private func speakerColor(for segment: SubtitleSegment) -> Color? {
        guard let speakerID = segment.speaker else {
            return nil
        }

        return speakers.first(where: { $0.id == speakerID })?.color
    }

    private var effectiveDurationMs: Int {
        if durationMs > 0 {
            return durationMs
        }

        return displaySubtitles.map(\.endMs).max() ?? 0
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var displaySubtitles: [SubtitleSegment] {
        draftSubtitles ?? subtitles
    }

    private var timelineBackground: Color {
        Color(red: 0.055, green: 0.058, blue: 0.066)
    }

    private var accentBlue: Color {
        Color(red: 0.1, green: 0.52, blue: 1.0)
    }

    private func updateDraftSegment(
        id: UUID,
        deltaX: CGFloat,
        edge: SubtitleTimelineEditEdge?,
        pxPerMs: CGFloat,
        durationMs: Int
    ) {
        if dragBaseSubtitles == nil {
            dragBaseSubtitles = subtitles
            suppressNextSelectionScroll = true
            selectedSegmentID = id
        }

        guard let dragBaseSubtitles else {
            return
        }

        let deltaMs = Int((deltaX / pxPerMs).rounded())
        if let edge {
            draftSubtitles = SubtitleTimingValidator.resizeSegment(
                segments: dragBaseSubtitles,
                id: id,
                edge: edge,
                deltaMs: deltaMs,
                durationMs: durationMs
            )
        } else {
            draftSubtitles = SubtitleTimingValidator.moveSegment(
                segments: dragBaseSubtitles,
                id: id,
                deltaMs: deltaMs,
                durationMs: durationMs
            )
        }
    }

    private func commitDraftSubtitles() {
        if let draftSubtitles {
            subtitles = draftSubtitles
        }

        dragBaseSubtitles = nil
        draftSubtitles = nil
    }

    private func beginEditing(_ segment: SubtitleSegment) {
        if editingSegmentID != nil, editingSegmentID != segment.id {
            commitTimelineTextEdit()
        }

        selectedSegmentID = segment.id
        editingSegmentID = segment.id
        editingText = segment.translatedText
        onBeginTextEditing(segment.id)

        Task { @MainActor in
            focusedTimelineEditorID = segment.id
        }
    }

    private func endTimelineTextEdit() {
        commitTimelineTextEdit()
    }

    private func commitTimelineTextEdit() {
        guard let editingSegmentID,
              let index = subtitles.firstIndex(where: { $0.id == editingSegmentID }) else {
            self.editingSegmentID = nil
            editingText = ""
            focusedTimelineEditorID = nil
            onEndTextEditing()
            return
        }

        if subtitles[index].translatedText != editingText {
            onTranslatedTextChange(editingSegmentID, editingText)
        }

        self.editingSegmentID = nil
        editingText = ""
        focusedTimelineEditorID = nil
        onEndTextEditing()
    }

    private func editingTextBinding(for segment: SubtitleSegment) -> Binding<String> {
        Binding(
            get: {
                editingSegmentID == segment.id ? editingText : segment.translatedText
            },
            set: { newValue in
                if editingSegmentID != segment.id {
                    editingSegmentID = segment.id
                    onBeginTextEditing(segment.id)
                }
                editingText = newValue
                updateEditedSubtitleText(segmentID: segment.id, text: newValue)
            }
        )
    }

    private func updateEditedSubtitleText(segmentID: UUID, text: String) {
        guard let index = subtitles.firstIndex(where: { $0.id == segmentID }),
              subtitles[index].translatedText != text else {
            return
        }

        onTranslatedTextChange(segmentID, text)
    }
}

struct TimelineRulerView: View {
    let durationMs: Int
    let pxPerMs: CGFloat

    var body: some View {
        Canvas { context, size in
            let majorStepMs = majorTickStepMs(for: durationMs)
            let minorStepMs = max(1_000, majorStepMs / 2)
            var tickMs = 0

            while tickMs <= durationMs {
                let x = CGFloat(tickMs) * pxPerMs
                let isMajor = tickMs % majorStepMs == 0
                let tickHeight: CGFloat = isMajor ? size.height : 8
                let opacity = isMajor ? 0.18 : 0.1

                var path = Path()
                path.move(to: CGPoint(x: x, y: isMajor ? 0 : size.height - tickHeight))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 1)

                if isMajor {
                    let text = Text(formatTime(tickMs))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.46))
                    context.draw(text, at: CGPoint(x: x + 4, y: 12), anchor: .leading)
                }

                tickMs += minorStepMs
            }

            var bottom = Path()
            bottom.move(to: CGPoint(x: 0, y: size.height - 0.5))
            bottom.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
            context.stroke(bottom, with: .color(.white.opacity(0.08)), lineWidth: 1)
        }
        .background(Color.white.opacity(0.012))
    }

    private func majorTickStepMs(for durationMs: Int) -> Int {
        if durationMs <= 60_000 {
            return 2_000
        }

        if durationMs <= 5 * 60_000 {
            return 5_000
        }

        return 10_000
    }

    private func formatTime(_ milliseconds: Int) -> String {
        let totalSeconds = max(0, milliseconds) / 1_000
        let hundredths = (max(0, milliseconds) % 1_000) / 10
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}

private struct TimelineWaveformView: View {
    let durationMs: Int
    let peaks: [Double]
    let pxPerMs: CGFloat
    let visibleRange: TimelineVisibleRange
    let targetBucketCount: Int

    var body: some View {
        Canvas { context, size in
            drawGrid(context: context, size: size)

            if !peaks.isEmpty {
                drawRealWaveform(context: context, size: size)
            }
        }
        .background(Color(red: 0.065, green: 0.068, blue: 0.078))
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        var center = Path()
        center.move(to: CGPoint(x: 0, y: size.height / 2))
        center.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(center, with: .color(.white.opacity(0.05)), lineWidth: 1)
    }

    private func drawRealWaveform(context: GraphicsContext, size: CGSize) {
        let buckets = TimelinePerformance.downsampleWaveform(
            peaks: peaks,
            durationMs: durationMs,
            visibleRange: visibleRange,
            targetBucketCount: targetBucketCount
        )

        for bucket in buckets {
            let startX = CGFloat(bucket.startMs) * pxPerMs
            let endX = CGFloat(bucket.endMs) * pxPerMs
            let barWidth = max(0.75, min(2.4, endX - startX - 0.25))
            let amp = min(1, max(0, bucket.amplitude))
            let h = CGFloat(amp) * (size.height - 14)
            guard h >= 0.75 else {
                continue
            }
            let y = (size.height - h) / 2

            let rect = CGRect(x: startX, y: y, width: barWidth, height: h)
            context.fill(Path(rect), with: .color(.white.opacity(0.34)))
        }
    }
}

private struct PlayheadCap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.62))
        path.closeSubpath()
        return path
    }
}

private struct SubtitleTimelineBlockView: View {
    let segment: SubtitleSegment
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingText: String
    var focusedEditorID: FocusState<UUID?>.Binding
    let isActive: Bool
    let blockHeight: CGFloat
    let speakerColor: Color?
    let onBeginEditing: () -> Void
    let onCommitEditing: () -> Void

    private let handleWidth: CGFloat = 8

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(blockFillColor)

            RoundedRectangle(cornerRadius: 5)
                .stroke(borderColor, lineWidth: isSelected ? 1.5 : 0.5)

            HStack(spacing: 0) {
                handle

                if isEditing {
                    TextField("Translated text", text: $editingText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: timelineFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .focused(focusedEditorID, equals: segment.id)
                        .onSubmit(onCommitEditing)
                } else {
                    Text(blockText)
                        .font(.system(size: timelineFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.horizontal, 7)
                        .shadow(color: .black.opacity(0.28), radius: 1, x: 0, y: 1)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2, perform: onBeginEditing)
                }

                handle
            }
        }
        .frame(height: blockHeight)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var handle: some View {
        Rectangle()
            .fill(Color.white.opacity(0.34))
            .frame(width: handleWidth)
    }

    private var blockText: String {
        let translatedText = segment.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !translatedText.isEmpty {
            return translatedText
        }

        let originalText = segment.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        return originalText.isEmpty ? "Untitled subtitle" : originalText
    }

    private var timelineFontSize: CGFloat {
        min(12, max(10, blockHeight * 0.31))
    }

    private var blockFillColor: Color {
        if isSelected {
            return cueColor
        }

        if isActive {
            return cueColor.opacity(0.92)
        }

        return cueColor.opacity(0.82)
    }

    private var borderColor: Color {
        isSelected ? .white.opacity(0.95) : .black.opacity(0.38)
    }

    private var cueColor: Color {
        speakerColor ?? Color(red: 0.34, green: 0.36, blue: 0.40)
    }
}

private struct TimelineScrollTarget: Equatable {
    let id = UUID()
    let x: CGFloat
}

private struct TimelineScrollController: NSViewRepresentable {
    let target: TimelineScrollTarget?

    func makeNSView(context: Context) -> TimelineScrollControllerView {
        TimelineScrollControllerView()
    }

    func updateNSView(_ nsView: TimelineScrollControllerView, context: Context) {
        nsView.scroll(to: target)
    }
}

private struct TimelineEditingFocusBoundary: NSViewRepresentable {
    let editingSegmentID: UUID?
    let onEndEditing: () -> Void

    func makeNSView(context: Context) -> TimelineEditingFocusBoundaryView {
        let view = TimelineEditingFocusBoundaryView()
        view.onEndEditing = onEndEditing
        view.editingSegmentID = editingSegmentID
        return view
    }

    func updateNSView(_ nsView: TimelineEditingFocusBoundaryView, context: Context) {
        nsView.onEndEditing = onEndEditing
        nsView.editingSegmentID = editingSegmentID
    }
}

private final class TimelineEditingFocusBoundaryView: NSView {
    var onEndEditing: (() -> Void)?
    var editingSegmentID: UUID? {
        didSet {
            updateMonitor()
        }
    }

    private var monitor: Any?

    deinit {
        removeMonitor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateMonitor()
    }

    private func updateMonitor() {
        if editingSegmentID == nil || window == nil {
            removeMonitor()
            return
        }

        guard monitor == nil else {
            return
        }

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self,
                  self.editingSegmentID != nil,
                  event.window === self.window else {
                return event
            }

            let point = self.convert(event.locationInWindow, from: nil)
            if !self.bounds.contains(point) {
                self.window?.makeFirstResponder(nil)
                self.onEndEditing?()
            }

            return event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}

private final class TimelineScrollControllerView: NSView {
    private var lastTargetID: UUID?

    func scroll(to target: TimelineScrollTarget?) {
        guard let target, target.id != lastTargetID else {
            return
        }

        lastTargetID = target.id

        // Kept as DispatchQueue.main.async (not Task { @MainActor in }): this
        // runs from `updateNSView`, already on the main thread — there is no
        // actor-isolation hop to make. The dispatch defers to the next run-loop
        // turn so AppKit finishes laying out `documentView`/`scrollView` from the
        // current SwiftUI update before we read their bounds; `Task { @MainActor
        // in }`'s executor scheduling doesn't guarantee that run-loop ordering.
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let scrollView = self.enclosingScrollView,
                  let documentView = scrollView.documentView else {
                return
            }

            let viewportWidth = scrollView.contentView.bounds.width
            let maxX = max(0, documentView.bounds.width - viewportWidth)
            let targetX = min(max(target.x - viewportWidth / 2, 0), maxX)
            let targetOrigin = CGPoint(x: targetX, y: scrollView.contentView.bounds.origin.y)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                scrollView.contentView.animator().setBoundsOrigin(targetOrigin)
            } completionHandler: {
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }
}

private struct SubtitleTimelineInteractionOverlay: NSViewRepresentable {
    let segments: [SubtitleSegment]
    let pxPerMs: CGFloat
    let durationMs: Int
    let editingSegmentID: UUID?
    let rulerHeight: CGFloat
    let blockTopY: CGFloat
    let blockHeight: CGFloat
    let handleWidth: CGFloat
    let onRulerSeek: (Int) -> Void
    let onSelect: (UUID) -> Void
    let onBlockClick: (SubtitleSegment) -> Void
    let onBlockDoubleClick: (SubtitleSegment) -> Void
    let onEndEditing: () -> Void
    let onDragChanged: (UUID, SubtitleTimelineEditEdge?, CGFloat) -> Void
    let onDragEnded: () -> Void

    func makeNSView(context: Context) -> MouseOverlayView {
        let view = MouseOverlayView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: MouseOverlayView, context: Context) {
        context.coordinator.parent = self
        nsView.delegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MouseOverlayViewDelegate {
        var parent: SubtitleTimelineInteractionOverlay
        private var activeDrag: ActiveDrag?
        private var didDrag = false

        init(parent: SubtitleTimelineInteractionOverlay) {
            self.parent = parent
        }

        func shouldReceiveMouse(at point: CGPoint) -> Bool {
            guard let editingSegmentID = parent.editingSegmentID,
                  let hit = parent.hitTestBlock(at: point),
                  hit.segment.id == editingSegmentID else {
                return true
            }

            return false
        }

        func mouseDown(at point: CGPoint, clickCount: Int) {
            didDrag = false

            if point.y <= parent.rulerHeight {
                parent.onEndEditing()
                parent.onRulerSeek(parent.milliseconds(forX: point.x))
                activeDrag = nil
                return
            }

            guard let hit = parent.hitTestBlock(at: point) else {
                parent.onEndEditing()
                activeDrag = nil
                return
            }

            if clickCount >= 2 {
                parent.onBlockDoubleClick(hit.segment)
                activeDrag = nil
                return
            }

            parent.onEndEditing()
            activeDrag = ActiveDrag(segment: hit.segment, edge: hit.edge, originX: point.x)
            parent.onSelect(hit.segment.id)
        }

        func mouseDragged(to point: CGPoint) {
            guard let activeDrag else {
                return
            }

            didDrag = true
            parent.onDragChanged(activeDrag.segment.id, activeDrag.edge, point.x - activeDrag.originX)
        }

        func mouseUp(at point: CGPoint) {
            guard let activeDrag else {
                return
            }

            if didDrag {
                parent.onDragEnded()
            } else {
                parent.onBlockClick(activeDrag.segment)
            }

            self.activeDrag = nil
            didDrag = false
        }

        func mouseMoved(to point: CGPoint) {
            guard let hit = parent.hitTestBlock(at: point),
                  hit.edge != nil else {
                NSCursor.arrow.set()
                return
            }

            NSCursor.resizeLeftRight.set()
        }

        private struct ActiveDrag {
            let segment: SubtitleSegment
            let edge: SubtitleTimelineEditEdge?
            let originX: CGFloat
        }
    }

    private func hitTestBlock(at point: CGPoint) -> (segment: SubtitleSegment, edge: SubtitleTimelineEditEdge?)? {
        guard point.y >= blockTopY,
              point.y <= blockTopY + blockHeight else {
            return nil
        }

        for segment in segments.reversed() {
            let startX = CGFloat(segment.startMs) * pxPerMs
            let width = max(CGFloat(segment.endMs - segment.startMs) * pxPerMs, 12)
            let endX = startX + width

            guard point.x >= startX, point.x <= endX else {
                continue
            }

            if point.x <= startX + handleWidth {
                return (segment, .left)
            }

            if point.x >= endX - handleWidth {
                return (segment, .right)
            }

            return (segment, nil)
        }

        return nil
    }

    private func milliseconds(forX x: CGFloat) -> Int {
        min(max(Int((x / pxPerMs).rounded()), 0), durationMs)
    }
}

private protocol MouseOverlayViewDelegate: AnyObject {
    func shouldReceiveMouse(at point: CGPoint) -> Bool
    func mouseDown(at point: CGPoint, clickCount: Int)
    func mouseDragged(to point: CGPoint)
    func mouseUp(at point: CGPoint)
    func mouseMoved(to point: CGPoint)
}

private final class MouseOverlayView: NSView {
    fileprivate weak var delegate: MouseOverlayViewDelegate?
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseMoved,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(nil)
        delegate?.mouseDown(at: convert(event.locationInWindow, from: nil), clickCount: event.clickCount)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard delegate?.shouldReceiveMouse(at: point) != false else {
            return nil
        }

        return super.hitTest(point)
    }

    override func mouseDragged(with event: NSEvent) {
        delegate?.mouseDragged(to: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        delegate?.mouseUp(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        delegate?.mouseMoved(to: convert(event.locationInWindow, from: nil))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
