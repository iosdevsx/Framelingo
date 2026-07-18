import SwiftUI

enum TimelineFrameStepper {
    static func steppedTime(
        from currentTimeMs: Int,
        direction: Int,
        frameRate: Double,
        durationMs: Int
    ) -> Int {
        let resolvedFrameRate = frameRate.isFinite && frameRate > 0 ? frameRate : 30
        let clampedCurrentTimeMs = max(0, currentTimeMs)
        let framePosition = Double(clampedCurrentTimeMs) * resolvedFrameRate / 1_000
        let nearestFrame = framePosition.rounded()
        let nearestFrameTimeMs = Int((nearestFrame * 1_000 / resolvedFrameRate).rounded())

        let targetFrame: Double
        if nearestFrameTimeMs == clampedCurrentTimeMs {
            targetFrame = nearestFrame + (direction < 0 ? -1 : 1)
        } else if direction < 0 {
            targetFrame = framePosition.rounded(.down)
        } else {
            targetFrame = framePosition.rounded(.up)
        }

        let targetTimeMs = Int((targetFrame * 1_000 / resolvedFrameRate).rounded())
        return min(max(0, targetTimeMs), max(0, durationMs))
    }
}

private struct TimelineKeyboardCommandsModifier: ViewModifier {
    let onStep: (Int) -> Void
    let onDelete: (() -> Void)?

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onKeyPress(.leftArrow) {
                guard isFocused else {
                    return .ignored
                }
                onStep(-1)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                guard isFocused else {
                    return .ignored
                }
                onStep(1)
                return .handled
            }
            .onDeleteCommand {
                guard isFocused else {
                    return
                }
                onDelete?()
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(
                        isFocused ? Color.accentColor.opacity(0.55) : .clear,
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func timelineKeyboardCommands(
        onStep: @escaping (Int) -> Void,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        modifier(TimelineKeyboardCommandsModifier(onStep: onStep, onDelete: onDelete))
    }
}
