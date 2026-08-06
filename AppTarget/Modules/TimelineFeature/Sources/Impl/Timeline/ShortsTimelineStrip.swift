import Shorts
import Subtitles
import SwiftUI

enum ShortsTimelineSnapper {
    static func snapped(
        _ milliseconds: Int,
        to cues: [SubtitleSegment],
        enabled: Bool,
        thresholdPx: CGFloat,
        pxPerMs: CGFloat
    ) -> Int {
        guard enabled else {
            return milliseconds
        }

        let thresholdMs = Int((thresholdPx / max(pxPerMs, 0.0001)).rounded())
        var best = milliseconds
        var bestDistance = thresholdMs + 1

        for cue in cues {
            for boundary in [cue.startMs, cue.endMs] {
                let distance = abs(boundary - milliseconds)
                if distance < bestDistance {
                    bestDistance = distance
                    best = boundary
                }
            }
        }

        return best
    }
}

enum ShortsRangeDragTarget: Equatable {
    case leading
    case trailing
    case body
}

enum ShortsRangeHitTest {
    /// Edge zones stay usable for narrow chips, but are capped so the center
    /// always remains available for moving the whole short.
    static func target(at locationX: CGFloat, width: CGFloat) -> ShortsRangeDragTarget {
        let safeWidth = max(1, width)
        let proportionalWidth = safeWidth * 0.06
        let edgeWidth = min(safeWidth / 3, min(max(proportionalWidth, 8), 18))

        if locationX <= edgeWidth {
            return .leading
        }
        if locationX >= safeWidth - edgeWidth {
            return .trailing
        }
        return .body
    }
}

/// Configuration the `.shorts` workspace passes into the shared subtitle
/// timeline to render and edit shorts ranges.
struct ShortsTimelineOverlayConfig {
    var shorts: [ShortDefinition]
    var selectedShortID: UUID?
    var snapToCues: Bool
    var onSelect: (UUID) -> Void
    var onCommitRange: (UUID, Int, Int) -> Void
    var onCreate: (Int, Int) -> Void
}

/// The shorts-ranges layer over the subtitle timeline: labeled chips on a
/// dedicated strip under the ruler (draggable edges, drag-to-create on empty
/// strip space). Edge drags snap to subtitle cue boundaries when enabled.
struct ShortsTimelineStrip: View {
    let config: ShortsTimelineOverlayConfig
    let cues: [SubtitleSegment]
    let pxPerMs: CGFloat
    let durationMs: Int

    static let stripHeight: CGFloat = 22

    @State private var draftRange: DraftRange?
    @State private var createDraft: (startMs: Int, endMs: Int)?

    private struct DraftRange: Equatable {
        var shortID: UUID
        var baseStartMs: Int
        var baseEndMs: Int
        var startMs: Int
        var endMs: Int
        var target: ShortsRangeDragTarget
    }

    private let minimumShortDurationMs = 1_000
    private let snapThresholdPx: CGFloat = 10
    private let stripColor = Color(red: 0.98, green: 0.55, blue: 0.2)

    var body: some View {
        ZStack(alignment: .topLeading) {
            createArea

            ForEach(config.shorts) { short in
                let range = displayedRange(for: short)
                chip(for: short, startMs: range.0, endMs: range.1)
            }

            if let createDraft {
                chipShape(
                    startMs: createDraft.startMs,
                    endMs: createDraft.endMs,
                    label: "New short",
                    isSelected: true
                )
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Pieces

    private var createArea: some View {
        Color.black.opacity(0.001)
            .frame(width: CGFloat(durationMs) * pxPerMs, height: Self.stripHeight)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        let anchorMs = milliseconds(atX: value.startLocation.x)
                        let currentMs = milliseconds(atX: value.location.x)
                        let first = snapped(min(anchorMs, currentMs))
                        let second = snapped(max(anchorMs, currentMs))
                        createDraft = (startMs: min(first, second), endMs: max(first, second))
                    }
                    .onEnded { _ in
                        defer { createDraft = nil }
                        guard let createDraft,
                              createDraft.endMs - createDraft.startMs >= minimumShortDurationMs else {
                            return
                        }

                        config.onCreate(createDraft.startMs, createDraft.endMs)
                    }
            )
            .help("Drag to mark a new short")
    }

    private func chip(for short: ShortDefinition, startMs: Int, endMs: Int) -> some View {
        let isSelected = config.selectedShortID == short.id
        let width = chipWidth(startMs: startMs, endMs: endMs)

        return chipShape(
            startMs: startMs,
            endMs: endMs,
            label: short.title,
            isSelected: isSelected
        )
        .onTapGesture {
            config.onSelect(short.id)
        }
        .gesture(dragGesture(for: short, chipWidth: width))
    }

    private func chipShape(
        startMs: Int,
        endMs: Int,
        label: String,
        isSelected: Bool
    ) -> some View {
        let width = chipWidth(startMs: startMs, endMs: endMs)

        return RoundedRectangle(cornerRadius: 5)
            .fill(stripColor.opacity(isSelected ? 0.55 : 0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(stripColor.opacity(isSelected ? 0.95 : 0.55), lineWidth: 1)
            )
            .overlay(
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6),
                alignment: .leading
            )
            .frame(width: width, height: Self.stripHeight - 4)
            .offset(x: CGFloat(startMs) * pxPerMs, y: 2)
    }

    private func dragGesture(for short: ShortDefinition, chipWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if draftRange?.shortID != short.id {
                    draftRange = DraftRange(
                        shortID: short.id,
                        baseStartMs: short.startMs,
                        baseEndMs: short.endMs,
                        startMs: short.startMs,
                        endMs: short.endMs,
                        target: ShortsRangeHitTest.target(
                            at: value.startLocation.x,
                            width: chipWidth
                        )
                    )
                    config.onSelect(short.id)
                }

                guard var draft = draftRange else {
                    return
                }

                let deltaMs = Int((value.translation.width / max(pxPerMs, 0.0001)).rounded())
                switch draft.target {
                case .leading:
                    let unsnappedStart = min(
                        max(0, draft.baseStartMs + deltaMs),
                        draft.baseEndMs - minimumShortDurationMs
                    )
                    draft.startMs = min(
                        max(0, snapped(unsnappedStart)),
                        draft.baseEndMs - minimumShortDurationMs
                    )
                case .trailing:
                    let unsnappedEnd = max(
                        min(durationMs, draft.baseEndMs + deltaMs),
                        draft.baseStartMs + minimumShortDurationMs
                    )
                    draft.endMs = max(
                        min(durationMs, snapped(unsnappedEnd)),
                        draft.baseStartMs + minimumShortDurationMs
                    )
                case .body:
                    let length = draft.baseEndMs - draft.baseStartMs
                    let newStart = min(max(0, draft.baseStartMs + deltaMs), durationMs - length)
                    draft.startMs = newStart
                    draft.endMs = newStart + length
                }

                draftRange = draft
            }
            .onEnded { _ in
                defer { draftRange = nil }
                guard let draft = draftRange,
                      draft.startMs != draft.baseStartMs || draft.endMs != draft.baseEndMs else {
                    return
                }

                config.onCommitRange(draft.shortID, draft.startMs, draft.endMs)
            }
    }

    // MARK: - Math

    private func displayedRange(for short: ShortDefinition) -> (Int, Int) {
        guard let draftRange, draftRange.shortID == short.id else {
            return (short.startMs, short.endMs)
        }

        return (draftRange.startMs, draftRange.endMs)
    }

    private func milliseconds(atX x: CGFloat) -> Int {
        min(max(0, Int((x / max(pxPerMs, 0.0001)).rounded())), durationMs)
    }

    private func chipWidth(startMs: Int, endMs: Int) -> CGFloat {
        max(14, CGFloat(endMs - startMs) * pxPerMs)
    }

    /// Snaps to the nearest cue boundary within a zoom-dependent pixel
    /// threshold when snapping is enabled.
    private func snapped(_ milliseconds: Int) -> Int {
        ShortsTimelineSnapper.snapped(
            milliseconds,
            to: cues,
            enabled: config.snapToCues,
            thresholdPx: snapThresholdPx,
            pxPerMs: pxPerMs
        )
    }
}

