import CoreText
import Foundation
import Subtitles

public enum BurnedSubtitleLayoutHelper {
    public static let defaultScriptSize = CGSize(width: 1_280, height: 720)
    public static let verticalSafeAreaMargin: CGFloat = 24
    public static let verticalCanvasSize = CGSize(width: 1_080, height: 1_920)

    /// Resolves wrapping, horizontal canvas bounds, and platform-safe vertical
    /// placement once for both the Shorts preview and vertical ASS export.
    public static func makeVerticalCaptionLayout(
        for segment: SubtitleSegment,
        settings: VideoExportSettings,
        configuration: VerticalCaptionConfiguration
    ) -> BurnedSubtitleLayout? {
        guard let layout = makeLayout(
            for: segment,
            settings: settings,
            scriptSize: configuration.canvasSize
        ) else {
            return nil
        }

        let minY = CGFloat(configuration.topSafeAreaFraction)
            * configuration.canvasSize.height + configuration.safeAreaMargin
        let maxY = (1 - CGFloat(configuration.bottomSafeAreaFraction))
            * configuration.canvasSize.height - configuration.safeAreaMargin
        return clampedVertically(layout, minY: minY, maxY: maxY)
    }

    /// Preview-only safety net: an unfinished translation must not make the
    /// draggable caption disappear. Export keeps honoring the selected text
    /// mode exactly; the editor falls back to shared original cue text.
    public static func makeVerticalPreviewCaptionLayout(
        for segment: SubtitleSegment,
        settings: VideoExportSettings,
        configuration: VerticalCaptionConfiguration
    ) -> BurnedSubtitleLayout? {
        if let layout = makeVerticalCaptionLayout(
            for: segment,
            settings: settings,
            configuration: configuration
        ) {
            return layout
        }

        guard settings.subtitleTextMode == .translated else {
            return nil
        }

        var fallbackSettings = settings
        fallbackSettings.subtitleTextMode = .original
        return makeVerticalCaptionLayout(
            for: segment,
            settings: fallbackSettings,
            configuration: configuration
        )
    }

    public static func normalizedPosition(
        for layout: BurnedSubtitleLayout,
        canvasSize: CGSize = verticalCanvasSize
    ) -> CGPoint {
        CGPoint(
            x: layout.textPosition.x / max(1, canvasSize.width),
            y: layout.textPosition.y / max(1, canvasSize.height)
        )
    }

    /// Shifts a layout vertically so its background block stays inside
    /// [minY, maxY] — shared by vertical export ASS generation and the shorts
    /// preview so both clamp identically.
    public static func clampedVertically(
        _ layout: BurnedSubtitleLayout,
        minY: CGFloat,
        maxY: CGFloat
    ) -> BurnedSubtitleLayout {
        let rect = layout.backgroundRect
        let upperOrigin = max(minY, maxY - rect.height)
        let clampedOriginY = clamped(
            rect.minY,
            lowerBound: minY,
            upperBound: upperOrigin
        )
        let offsetY = clampedOriginY - rect.minY

        guard offsetY != 0 else {
            return layout
        }

        var clamped = layout
        clamped.backgroundRect = rect.offsetBy(dx: 0, dy: offsetY)
        clamped.textPosition = CGPoint(
            x: layout.textPosition.x,
            y: layout.textPosition.y + offsetY
        )
        return clamped
    }

    /// Shared hook wrapping and placement for the vertical preview and ASS
    /// export. The block begins immediately below the platform's top safe
    /// area, using the same 1080×1920 coordinate space in both paths.
    public static func makeVerticalHookLayout(
        text: String,
        style: VideoExportSettings,
        hookFontSize: Double,
        configuration: VerticalCaptionConfiguration
    ) -> BurnedSubtitleLayout? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        let canvas = configuration.canvasSize
        var hookStyle = style
        hookStyle.fontSize = hookFontSize
        hookStyle.maxLines = 2
        hookStyle.subtitleTextMode = .original
        let hookSegment = SubtitleSegment(
            id: UUID(),
            index: 0,
            startMs: 0,
            endMs: 1,
            originalText: trimmedText,
            translatedText: ""
        )
        guard var layout = makeLayout(
            for: hookSegment,
            settings: hookStyle,
            scriptSize: canvas
        ) else {
            return nil
        }

        let topLimit = CGFloat(configuration.topSafeAreaFraction) * canvas.height
            + configuration.safeAreaMargin
        let desiredCenter = CGPoint(
            x: canvas.width / 2,
            y: topLimit + layout.backgroundRect.height / 2
        )
        let offsetX = desiredCenter.x - layout.textPosition.x
        let offsetY = desiredCenter.y - layout.textPosition.y
        layout.backgroundRect = layout.backgroundRect.offsetBy(dx: offsetX, dy: offsetY)
        layout.textPosition = desiredCenter
        return layout
    }

    private static let horizontalPadding: CGFloat = 14
    private static let verticalPadding: CGFloat = 8
    private static let maximumWidthFraction: CGFloat = 0.8

    public static func makeLayout(
        for segment: SubtitleSegment,
        settings: VideoExportSettings,
        scriptSize: CGSize = defaultScriptSize
    ) -> BurnedSubtitleLayout? {
        let selectedText = selectedText(for: segment, mode: settings.subtitleTextMode)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedText.isEmpty else {
            return nil
        }

        let canvasSize = CGSize(
            width: max(1, scriptSize.width),
            height: max(1, scriptSize.height)
        )
        let fontSize = max(1, settings.fontSize)
        let font = CTFontCreateWithName(settings.fontName as CFString, fontSize, nil)
        let maximumBackgroundWidth = max(1, canvasSize.width * maximumWidthFraction)
        let maximumTextWidth = max(1, maximumBackgroundWidth - horizontalPadding * 2)
        let wrappedLines = wrappedLines(
            selectedText,
            font: font,
            maximumWidth: maximumTextWidth,
            maxLines: settings.maxLines
        )

        let measuredLineWidth = wrappedLines
            .map { measuredWidth(of: $0, font: font) }
            .max() ?? 0
        let lineHeight = max(
            1,
            ceil(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font))
        )
        let textSize = CGSize(
            width: min(maximumTextWidth, ceil(measuredLineWidth)),
            height: ceil(lineHeight * CGFloat(wrappedLines.count))
        )
        let backgroundSize = CGSize(
            width: min(canvasSize.width, textSize.width + horizontalPadding * 2),
            height: min(canvasSize.height, textSize.height + verticalPadding * 2)
        )

        let desiredCenter = CGPoint(
            x: clamped(settings.subtitlePositionX) * canvasSize.width,
            y: clamped(settings.subtitlePositionY) * canvasSize.height
        )
        let origin = CGPoint(
            x: clamped(
                desiredCenter.x - backgroundSize.width / 2,
                lowerBound: 0,
                upperBound: canvasSize.width - backgroundSize.width
            ),
            y: clamped(
                desiredCenter.y - backgroundSize.height / 2,
                lowerBound: 0,
                upperBound: canvasSize.height - backgroundSize.height
            )
        )
        let backgroundRect = CGRect(origin: origin, size: backgroundSize)

        return BurnedSubtitleLayout(
            selectedText: selectedText,
            wrappedLines: wrappedLines,
            textSize: textSize,
            backgroundRect: backgroundRect,
            textPosition: CGPoint(x: backgroundRect.midX, y: backgroundRect.midY)
        )
    }

    private static func selectedText(
        for segment: SubtitleSegment,
        mode: SubtitleTextMode
    ) -> String {
        switch mode {
        case .original:
            segment.originalText
        case .translated:
            segment.translatedText
        case .translatedFallbackToOriginal:
            segment.hasTranslation ? segment.translatedText : segment.originalText
        }
    }

    private static func wrappedLines(
        _ text: String,
        font: CTFont,
        maximumWidth: CGFloat,
        maxLines: Int
    ) -> [String] {
        let lineLimit = max(1, maxLines)
        let paragraphs = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { paragraph in
                paragraph
                    .split(whereSeparator: \Character.isWhitespace)
                    .map(String.init)
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }

        var lines: [String] = []
        var remainingWords = paragraphs.flatMap { paragraph in
            paragraph.split(separator: " ").map(String.init) + ["\n"]
        }
        if remainingWords.last == "\n" {
            remainingWords.removeLast()
        }

        var currentLine = ""
        while let word = remainingWords.first {
            remainingWords.removeFirst()

            if word == "\n" {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                    currentLine = ""
                }
            } else {
                let candidate = currentLine.isEmpty ? word : "\(currentLine) \(word)"
                if currentLine.isEmpty || measuredWidth(of: candidate, font: font) <= maximumWidth {
                    currentLine = candidate
                } else {
                    lines.append(currentLine)
                    currentLine = word
                }
            }

            guard lines.count < lineLimit else {
                let overflow = ([currentLine] + remainingWords)
                    .filter { !$0.isEmpty && $0 != "\n" }
                    .joined(separator: " ")
                if !overflow.isEmpty {
                    lines[lineLimit - 1] = [lines[lineLimit - 1], overflow]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                }
                return Array(lines.prefix(lineLimit))
            }
        }

        if !currentLine.isEmpty, lines.count < lineLimit {
            lines.append(currentLine)
        }

        return lines.isEmpty ? [text] : Array(lines.prefix(lineLimit))
    }

    private static func measuredWidth(of text: String, font: CTFont) -> CGFloat {
        let attributes = [
            kCTFontAttributeName as NSAttributedString.Key: font,
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedText)
        return ceil(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private static func clamped(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, 0), 1))
    }

    private static func clamped(
        _ value: CGFloat,
        lowerBound: CGFloat,
        upperBound: CGFloat
    ) -> CGFloat {
        min(max(value, lowerBound), max(lowerBound, upperBound))
    }
}
