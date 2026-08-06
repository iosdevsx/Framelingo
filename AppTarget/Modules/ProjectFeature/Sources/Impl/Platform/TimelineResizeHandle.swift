import AppKit
import SwiftUI

struct TimelineResizeHandle: NSViewRepresentable {
    @Binding var height: Double
    let totalHeight: Double
    let onCommit: (Double) -> Void

    func makeNSView(context: Context) -> TimelineResizeHandleNSView {
        let view = TimelineResizeHandleNSView()
        view.height = $height
        view.totalHeight = totalHeight
        view.onCommit = onCommit
        return view
    }

    func updateNSView(_ nsView: TimelineResizeHandleNSView, context: Context) {
        nsView.height = $height
        nsView.totalHeight = totalHeight
        nsView.onCommit = onCommit
        nsView.needsDisplay = true
    }
}

final class TimelineResizeHandleNSView: NSView {
    var height: Binding<Double>?
    var totalHeight = 0.0
    var onCommit: (Double) -> Void = { _ in }

    private var dragStartY: CGFloat?
    private var dragStartHeight = 180.0

    override var acceptsFirstResponder: Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        bounds.fill()

        let capsuleWidth: CGFloat = 42
        let capsuleHeight: CGFloat = 3
        let capsuleRect = NSRect(
            x: bounds.midX - capsuleWidth / 2,
            y: bounds.midY - capsuleHeight / 2,
            width: capsuleWidth,
            height: capsuleHeight
        )
        NSColor.secondaryLabelColor.withAlphaComponent(0.45).setFill()
        NSBezierPath(roundedRect: capsuleRect, xRadius: capsuleHeight / 2, yRadius: capsuleHeight / 2).fill()
    }

    override func mouseDown(with event: NSEvent) {
        dragStartY = event.locationInWindow.y
        dragStartHeight = height?.wrappedValue ?? 180.0
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartY else {
            return
        }

        let deltaY = Double(event.locationInWindow.y - dragStartY)
        height?.wrappedValue = clampedHeight(dragStartHeight + deltaY)
    }

    override func mouseUp(with event: NSEvent) {
        let committedHeight = clampedHeight(height?.wrappedValue ?? dragStartHeight)
        height?.wrappedValue = committedHeight
        onCommit(committedHeight)
        dragStartY = nil
    }

    private func clampedHeight(_ proposedHeight: Double) -> Double {
        let maxHeight = max(150, totalHeight - 280)
        return min(max(proposedHeight, 150), min(420, maxHeight))
    }
}
