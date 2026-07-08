import Foundation

enum SubtitleTextMode: String, Codable, CaseIterable, Identifiable {
    case original
    case translated
    case translatedFallbackToOriginal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original:
            return "Original"
        case .translated:
            return "Translated"
        case .translatedFallbackToOriginal:
            return "Translated fallback to original"
        }
    }
}

enum SubtitleTimecodeError: LocalizedError, Equatable {
    case invalidTimestamp(String)
    case invalidSRTBlock(String)

    var errorDescription: String? {
        switch self {
        case .invalidTimestamp(let value):
            "Invalid SRT timestamp: \(value)"
        case .invalidSRTBlock(let value):
            "Invalid SRT block: \(value)"
        }
    }
}

func formatSRTTimestamp(_ milliseconds: Int) -> String {
    let clampedMilliseconds = max(0, milliseconds)
    let hours = clampedMilliseconds / 3_600_000
    let minutes = clampedMilliseconds % 3_600_000 / 60_000
    let seconds = clampedMilliseconds % 60_000 / 1_000
    let milliseconds = clampedMilliseconds % 1_000

    return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
}

func parseSRTTimestamp(_ value: String) throws -> Int {
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmedValue.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 3,
          parts[0].count == 2,
          parts[1].count == 2,
          let hours = Int(parts[0]),
          let minutes = Int(parts[1]) else {
        throw SubtitleTimecodeError.invalidTimestamp(value)
    }

    let secondParts = parts[2].split(separator: ",", omittingEmptySubsequences: false)
    guard secondParts.count == 2,
          secondParts[0].count == 2,
          secondParts[1].count == 3,
          let seconds = Int(secondParts[0]),
          let milliseconds = Int(secondParts[1]),
          hours >= 0,
          minutes >= 0,
          minutes < 60,
          seconds >= 0,
          seconds < 60,
          milliseconds >= 0,
          milliseconds < 1_000 else {
        throw SubtitleTimecodeError.invalidTimestamp(value)
    }

    return hours * 3_600_000 + minutes * 60_000 + seconds * 1_000 + milliseconds
}

func subtitlesToSRT(
    _ segments: [SubtitleSegment],
    mode: SubtitleTextMode,
    speakerLabels: [SpeakerLabel] = [],
    exportOptions: SubtitleExportOptions = SubtitleExportOptions()
) -> String {
    segments
        .sorted { $0.startMs == $1.startMs ? $0.index < $1.index : $0.startMs < $1.startMs }
        .enumerated()
        .map { offset, segment in
            let text = text(
                for: segment,
                mode: mode,
                speakerLabels: speakerLabels,
                exportOptions: exportOptions,
                preferredFormat: .squareBrackets
            )
            return """
            \(offset + 1)
            \(formatSRTTimestamp(segment.startMs)) --> \(formatSRTTimestamp(segment.endMs))
            \(text)
            """
        }
        .joined(separator: "\n\n")
}

func parseSRT(_ input: String) throws -> [SubtitleSegment] {
    try SRTSubtitleParser().parse(input).segments
}

private func parseSRTBlock(_ block: String, fallbackIndex: Int) throws -> SubtitleSegment {
    let lines = block
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)

    guard lines.count >= 2 else {
        throw SubtitleTimecodeError.invalidSRTBlock(block)
    }

    let firstLine = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
    let timingLineIndex: Int
    let index: Int

    if let parsedIndex = Int(firstLine) {
        index = parsedIndex
        timingLineIndex = 1
    } else {
        index = fallbackIndex
        timingLineIndex = 0
    }

    guard lines.indices.contains(timingLineIndex) else {
        throw SubtitleTimecodeError.invalidSRTBlock(block)
    }

    let timingParts = lines[timingLineIndex].components(separatedBy: " --> ")
    guard timingParts.count == 2 else {
        throw SubtitleTimecodeError.invalidSRTBlock(block)
    }

    let startMs = try parseSRTTimestamp(timingParts[0])
    let endMs = try parseSRTTimestamp(timingParts[1])
    guard endMs > startMs else {
        throw SubtitleTimecodeError.invalidSRTBlock(block)
    }

    let textStartIndex = timingLineIndex + 1
    let text = lines.indices.contains(textStartIndex)
        ? lines[textStartIndex...].joined(separator: "\n")
        : ""

    return SubtitleSegment(
        id: UUID(),
        index: index,
        startMs: startMs,
        endMs: endMs,
        originalText: text,
        translatedText: "",
        speaker: nil,
        confidence: nil
    )
}

func subtitleExportText(
    for segment: SubtitleSegment,
    mode: SubtitleTextMode,
    speakerLabels: [SpeakerLabel],
    exportOptions: SubtitleExportOptions,
    preferredFormat: SpeakerExportFormat
) -> String {
    text(
        for: segment,
        mode: mode,
        speakerLabels: speakerLabels,
        exportOptions: exportOptions,
        preferredFormat: preferredFormat
    )
}

private func text(
    for segment: SubtitleSegment,
    mode: SubtitleTextMode,
    speakerLabels: [SpeakerLabel] = [],
    exportOptions: SubtitleExportOptions = SubtitleExportOptions(),
    preferredFormat: SpeakerExportFormat = .none
) -> String {
    let selectedText: String
    switch mode {
    case .original:
        selectedText = segment.originalText
    case .translated:
        selectedText = segment.translatedText
    case .translatedFallbackToOriginal:
        selectedText = segment.hasTranslation ? segment.translatedText : segment.originalText
    }

    guard exportOptions.includeSpeakerLabels,
          exportOptions.speakerFormat == preferredFormat,
          let speakerId = segment.speakerId,
          let label = speakerLabels.first(where: { $0.id == speakerId }) else {
        return selectedText
    }

    switch exportOptions.speakerFormat {
    case .squareBrackets:
        return "[\(label.displayName)] \(selectedText)"
    case .webVTTVoiceTags:
        return "<v \(label.displayName)>\(selectedText)</v>"
    case .none:
        return selectedText
    }
}
