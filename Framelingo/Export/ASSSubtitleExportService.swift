import Foundation

final class ASSSubtitleExportService {
    init() {}

    func generateASS(
        segments: [SubtitleSegment],
        settings: VideoExportSettings
    ) throws -> String {
        let events = segments
            .sorted { $0.startMs < $1.startMs }
            .compactMap { segment -> String? in
                let text = selectedText(for: segment, mode: settings.subtitleTextMode)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    return nil
                }

                let wrappedText = wrapText(text, maxLines: settings.maxLines)
                return "Dialogue: 0,\(assTimestamp(segment.startMs)),\(assTimestamp(segment.endMs)),Default,,0,0,0,,\(positionOverride(settings))\(escapeText(wrappedText))"
            }

        return """
        [Script Info]
        ScriptType: v4.00+
        Collisions: Normal
        PlayResX: 1280
        PlayResY: 720
        WrapStyle: 2
        ScaledBorderAndShadow: yes

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,\(sanitizeFontName(settings.fontName)),\(Int(settings.fontSize)),\(primaryColor(settings)),&H000000FF,\(outlineColor(settings)),\(backgroundColor(settings)),0,0,0,0,100,100,0,0,\(borderStyle(settings)),\(outlineWidth(settings)),\(shadowWidth(settings)),\(alignment(settings.subtitlePosition)),40,40,36,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        \(events.joined(separator: "\n"))
        """
    }

    private func selectedText(for segment: SubtitleSegment, mode: SubtitleTextMode) -> String {
        switch mode {
        case .original:
            return segment.originalText
        case .translated:
            return segment.translatedText
        case .translatedFallbackToOriginal:
            let translated = segment.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            return translated.isEmpty ? segment.originalText : segment.translatedText
        }
    }

    private func assTimestamp(_ milliseconds: Int) -> String {
        let centiseconds = max(0, milliseconds) / 10
        let hours = centiseconds / 360_000
        let minutes = (centiseconds % 360_000) / 6_000
        let seconds = (centiseconds % 6_000) / 100
        let remainder = centiseconds % 100
        return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, remainder)
    }

    private func alignment(_ position: SubtitlePosition) -> Int {
        switch position {
        case .bottom:
            return 2
        case .center:
            return 5
        case .top:
            return 8
        }
    }

    private func primaryColor(_ settings: VideoExportSettings) -> String {
        assColor(red: settings.textColorRed, green: settings.textColorGreen, blue: settings.textColorBlue, alpha: 0)
    }

    private func outlineColor(_ settings: VideoExportSettings) -> String {
        settings.backgroundEnabled ? "&H00000000" : "&H80000000"
    }

    private func backgroundColor(_ settings: VideoExportSettings) -> String {
        let alpha = Int((1 - min(max(settings.backgroundOpacity, 0), 1)) * 255)
        return assColor(
            red: settings.backgroundColorRed,
            green: settings.backgroundColorGreen,
            blue: settings.backgroundColorBlue,
            alpha: alpha
        )
    }

    private func borderStyle(_ settings: VideoExportSettings) -> Int {
        settings.backgroundEnabled ? 3 : 1
    }

    private func outlineWidth(_ settings: VideoExportSettings) -> Int {
        settings.backgroundEnabled ? 8 : 2
    }

    private func shadowWidth(_ settings: VideoExportSettings) -> Int {
        settings.backgroundEnabled ? 0 : 1
    }

    private func positionOverride(_ settings: VideoExportSettings) -> String {
        let x = Int((min(max(settings.subtitlePositionX, 0), 1) * 1280).rounded())
        let y = Int((min(max(settings.subtitlePositionY, 0), 1) * 720).rounded())
        return "{\\pos(\(x),\(y))}"
    }

    private func wrapText(_ text: String, maxLines: Int) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        guard maxLines > 1, !normalized.contains("\n") else {
            return normalized
        }

        let words = normalized.split(separator: " ").map(String.init)
        guard words.count > 2 else {
            return normalized
        }

        let targetLineCount = min(maxLines, words.count)
        let wordsPerLine = Int(ceil(Double(words.count) / Double(targetLineCount)))
        return stride(from: 0, to: words.count, by: wordsPerLine)
            .map { words[$0..<min($0 + wordsPerLine, words.count)].joined(separator: " ") }
            .joined(separator: "\n")
    }

    private func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "\n", with: "\\N")
    }

    private func assColor(red: Double, green: Double, blue: Double, alpha: Int) -> String {
        let r = Int((min(max(red, 0), 1) * 255).rounded())
        let g = Int((min(max(green, 0), 1) * 255).rounded())
        let b = Int((min(max(blue, 0), 1) * 255).rounded())
        let a = min(max(alpha, 0), 255)
        return String(format: "&H%02X%02X%02X%02X", a, b, g, r)
    }

    private func sanitizeFontName(_ fontName: String) -> String {
        let trimmed = fontName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Arial"
        }

        return trimmed
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
