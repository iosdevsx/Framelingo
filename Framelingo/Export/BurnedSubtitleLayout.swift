import AppKit
import Foundation

struct BurnedSubtitleLayout: Equatable {
    var selectedText: String
    var wrappedLines: [String]
    var textSize: CGSize
    var backgroundRect: CGRect
    var textPosition: CGPoint

    var wrappedText: String {
        wrappedLines.joined(separator: "\n")
    }
}

enum BurnedSubtitleLayoutHelper {
    static let defaultScriptSize = CGSize(width: 1_280, height: 720)

    private static let horizontalPadding: CGFloat = 14
    private static let verticalPadding: CGFloat = 8
    private static let maximumWidthFraction: CGFloat = 0.8

    static func makeLayout(
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
        let font = NSFont(name: settings.fontName, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
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
        let lineHeight = max(1, ceil(font.ascender - font.descender + font.leading))
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
        font: NSFont,
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

    private static func measuredWidth(of text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
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
