import Subtitles
import CoreGraphics
import Foundation
import VideoRendering

final class ASSSubtitleExportService: SubtitleScriptGenerating {
    func generateASS(
        segments: [SubtitleSegment],
        settings: VideoExportSettings
    ) throws -> String {
        let events = segments
            .sorted { first, second in
                first.startMs == second.startMs
                    ? first.index < second.index
                    : first.startMs < second.startMs
            }
            .flatMap { segment -> [String] in
                guard let layout = BurnedSubtitleLayoutHelper.makeLayout(
                    for: segment,
                    settings: settings
                ) else {
                    return []
                }

                var cueEvents: [String] = []
                if settings.backgroundEnabled {
                    cueEvents.append(
                        backgroundEvent(for: segment, layout: layout, settings: settings)
                    )
                }
                cueEvents.append(textEvent(for: segment, layout: layout))
                return cueEvents
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
        Style: SubtitleText,\(sanitizeFontName(settings.fontName)),\(max(1, Int(settings.fontSize.rounded()))),\(primaryColor(settings)),&H000000FF,&HFF000000,&HFF000000,0,0,0,0,100,100,0,0,1,0,0,5,0,0,0,1
        Style: SubtitleBackground,Arial,1,\(backgroundColor(settings)),&H000000FF,\(borderColor(settings)),\(backgroundColor(settings)),0,0,0,0,100,100,0,0,1,\(backgroundOutlineWidth(settings)),0,7,0,0,0,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        \(events.joined(separator: "\n"))
        """
    }

    /// ASS for vertical shorts export: 1080×1920 PlayRes, subtitle blocks
    /// clamped into the platform's safe area, and an optional hook title
    /// rendered on a higher layer just below the top platform UI zone for the
    /// short's full duration. Segment times must already be in short-local
    /// time.
    func generateVerticalASS(_ request: VerticalSubtitleScriptRequest) -> String {
        let events = request.segments
            .sorted { first, second in
                first.startMs == second.startMs
                    ? first.index < second.index
                    : first.startMs < second.startMs
            }
            .flatMap { segment -> [String] in
                guard let layout = BurnedSubtitleLayoutHelper.makeVerticalCaptionLayout(
                    for: segment,
                    settings: request.style,
                    configuration: request.configuration
                ) else {
                    return []
                }

                var cueEvents: [String] = []
                if request.style.backgroundEnabled {
                    cueEvents.append(
                        backgroundEvent(
                            for: segment,
                            layout: layout,
                            settings: request.style
                        )
                    )
                }
                cueEvents.append(textEvent(for: segment, layout: layout))
                return cueEvents
            }

        let hookLayout = BurnedSubtitleLayoutHelper.makeVerticalHookLayout(
            text: request.hookText,
            style: request.style,
            hookFontSize: request.hookFontSize,
            configuration: request.configuration
        )
        let hookEvents = hookLayout.map {
            [hookEvent(layout: $0, durationMs: request.durationMs)]
        } ?? []

        return """
        [Script Info]
        ScriptType: v4.00+
        Collisions: Normal
        PlayResX: \(max(1, Int(request.configuration.canvasSize.width.rounded())))
        PlayResY: \(max(1, Int(request.configuration.canvasSize.height.rounded())))
        WrapStyle: 2
        ScaledBorderAndShadow: yes

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: SubtitleText,\(sanitizeFontName(request.style.fontName)),\(max(1, Int(request.style.fontSize.rounded()))),\(primaryColor(request.style)),&H000000FF,&HFF000000,&HFF000000,0,0,0,0,100,100,0,0,1,0,0,5,0,0,0,1
        Style: SubtitleBackground,Arial,1,\(backgroundColor(request.style)),&H000000FF,\(borderColor(request.style)),\(backgroundColor(request.style)),0,0,0,0,100,100,0,0,1,\(backgroundOutlineWidth(request.style)),0,7,0,0,0,1
        Style: HookText,\(sanitizeFontName(request.style.fontName)),\(max(1, Int(request.hookFontSize.rounded()))),&H00FFFFFF,&H000000FF,&H00000000,&HFF000000,-1,0,0,0,100,100,0,0,1,3,0,5,0,0,0,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        \((events + hookEvents).joined(separator: "\n"))
        """
    }

    private func hookEvent(
        layout: BurnedSubtitleLayout,
        durationMs: Int
    ) -> String {
        let centerX = Int(layout.textPosition.x.rounded())
        let centerY = Int(layout.textPosition.y.rounded())

        return "Dialogue: 2,\(assTimestamp(0)),\(assTimestamp(max(0, durationMs))),HookText,,0,0,0,,{\\an5\\pos(\(centerX),\(centerY))}\(escapeText(layout.wrappedText))"
    }

    private func backgroundEvent(
        for segment: SubtitleSegment,
        layout: BurnedSubtitleLayout,
        settings: VideoExportSettings
    ) -> String {
        let centerX = Int(layout.backgroundRect.midX.rounded())
        let centerY = Int(layout.backgroundRect.midY.rounded())
        let drawing = backgroundDrawing(
            size: layout.backgroundRect.size,
            cornerRadius: settings.backgroundCornerRadius
        )

        return "Dialogue: 0,\(assTimestamp(segment.startMs)),\(assTimestamp(segment.endMs)),SubtitleBackground,,0,0,0,,{\\an5\\pos(\(centerX),\(centerY))\\p1}\(drawing){\\p0}"
    }

    private func textEvent(
        for segment: SubtitleSegment,
        layout: BurnedSubtitleLayout
    ) -> String {
        let x = Int(layout.textPosition.x.rounded())
        let y = Int(layout.textPosition.y.rounded())
        return "Dialogue: 1,\(assTimestamp(segment.startMs)),\(assTimestamp(segment.endMs)),SubtitleText,,0,0,0,,{\\an5\\pos(\(x),\(y))}\(escapeText(layout.wrappedText))"
    }

    private func backgroundDrawing(size: CGSize, cornerRadius: Double) -> String {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard cornerRadius > 0 else {
            return "m 0 0 l \(width) 0 l \(width) \(height) l 0 \(height) l 0 0"
        }

        let radius = max(
            1,
            min(
                Int(cornerRadius.rounded()),
                min(width, height) / 2
            )
        )
        let controlOffset = max(1, Int((Double(radius) * 0.552_284_75).rounded()))
        let right = width
        let bottom = height

        return [
            "m \(radius) 0",
            "l \(right - radius) 0",
            "b \(right - radius + controlOffset) 0 \(right) \(radius - controlOffset) \(right) \(radius)",
            "l \(right) \(bottom - radius)",
            "b \(right) \(bottom - radius + controlOffset) \(right - radius + controlOffset) \(bottom) \(right - radius) \(bottom)",
            "l \(radius) \(bottom)",
            "b \(radius - controlOffset) \(bottom) 0 \(bottom - radius + controlOffset) 0 \(bottom - radius)",
            "l 0 \(radius)",
            "b 0 \(radius - controlOffset) \(radius - controlOffset) 0 \(radius) 0"
        ]
        .joined(separator: " ")
    }

    private func assTimestamp(_ milliseconds: Int) -> String {
        let centiseconds = max(0, milliseconds) / 10
        let hours = centiseconds / 360_000
        let minutes = (centiseconds % 360_000) / 6_000
        let seconds = (centiseconds % 6_000) / 100
        let remainder = centiseconds % 100
        return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, remainder)
    }

    private func primaryColor(_ settings: VideoExportSettings) -> String {
        assColor(
            red: settings.textColorRed,
            green: settings.textColorGreen,
            blue: settings.textColorBlue,
            alpha: 0
        )
    }

    private func backgroundColor(_ settings: VideoExportSettings) -> String {
        assColor(
            red: settings.backgroundColorRed,
            green: settings.backgroundColorGreen,
            blue: settings.backgroundColorBlue,
            alpha: alpha(forOpacity: settings.backgroundOpacity)
        )
    }

    private func borderColor(_ settings: VideoExportSettings) -> String {
        assColor(
            red: settings.borderColorRed,
            green: settings.borderColorGreen,
            blue: settings.borderColorBlue,
            alpha: alpha(forOpacity: settings.borderOpacity)
        )
    }

    private func backgroundOutlineWidth(_ settings: VideoExportSettings) -> String {
        guard settings.borderEnabled else {
            return "0"
        }

        let width = min(max(settings.borderWidth, 0), 100)
        let formatted = String(format: "%.2f", width)
        return formatted
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }

    private func alpha(forOpacity opacity: Double) -> Int {
        Int((1 - min(max(opacity, 0), 1)) * 255)
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
