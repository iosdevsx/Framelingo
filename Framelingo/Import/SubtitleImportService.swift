import Foundation

struct SubtitleImportService {
    func importSubtitles(from fileURL: URL) async throws -> SubtitleImportPreview {
        // Detached: the only caller (ProjectViewModel, @MainActor) awaits this
        // synchronously-implemented parse; a plain `Task {}` would inherit that
        // isolation and run the file read + regex-based parsing on the main
        // thread, blocking the UI. Detaching moves the CPU/IO work off MainActor.
        try await Task.detached(priority: .userInitiated) {
            let format = try SubtitleFileFormat.format(for: fileURL)
            let decodedFile = try SubtitleFileReader.read(fileURL)
            let trimmedContent = decodedFile.content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedContent.isEmpty else {
                throw SubtitleImportError.emptyFile
            }

            let parsedResult: SubtitleParseResult
            do {
                switch format {
                case .srt:
                    parsedResult = try SRTSubtitleParser().parse(decodedFile.content)
                case .vtt:
                    parsedResult = try WebVTTSubtitleParser().parse(decodedFile.content)
                case .ass, .ssa:
                    parsedResult = try ASSSubtitleParser().parse(decodedFile.content)
                case .txt:
                    parsedResult = try PlainTextSubtitleParser().parse(decodedFile.content)
                case .sbv:
                    parsedResult = try SBVSubtitleParser().parse(decodedFile.content)
                }
            } catch let error as SubtitleImportError {
                throw error
            } catch {
                throw SubtitleImportError.parsingFailed(error.localizedDescription)
            }

            let normalizedResult = SubtitleImportNormalizer.normalize(parsedResult.segments)
            let warnings = parsedResult.warnings + normalizedResult.warnings

            guard !normalizedResult.segments.isEmpty else {
                throw SubtitleImportError.noSegmentsFound
            }

            return SubtitleImportPreview(
                fileURL: fileURL,
                format: format,
                detectedEncodingName: decodedFile.encodingName,
                segments: normalizedResult.segments,
                warnings: warnings
            )
        }.value
    }
}

struct SubtitleParseResult {
    var segments: [SubtitleSegment]
    var warnings: [String] = []
}

enum SubtitleFileReader {
    static func read(_ fileURL: URL) throws -> (content: String, encodingName: String?) {
        do {
            var usedEncoding = String.Encoding.utf8
            let content = try String(contentsOf: fileURL, usedEncoding: &usedEncoding)
            return (stripBOM(content), encodingName(for: usedEncoding))
        } catch {
            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch {
                throw SubtitleImportError.fileReadFailed(error.localizedDescription)
            }

            let encodings: [String.Encoding] = [
                .utf8,
                .utf16,
                .utf16LittleEndian,
                .utf16BigEndian,
                .windowsCP1251
            ]

            for encoding in encodings {
                if let content = String(data: data, encoding: encoding) {
                    return (stripBOM(content), encodingName(for: encoding))
                }
            }

            throw SubtitleImportError.encodingDetectionFailed
        }
    }

    private static func stripBOM(_ content: String) -> String {
        content.hasPrefix("\u{feff}") ? String(content.dropFirst()) : content
    }

    private static func encodingName(for encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8:
            "UTF-8"
        case .utf16:
            "UTF-16"
        case .utf16LittleEndian:
            "UTF-16 LE"
        case .utf16BigEndian:
            "UTF-16 BE"
        case .windowsCP1251:
            "Windows-1251"
        default:
            "Encoding \(encoding.rawValue)"
        }
    }
}

struct SRTSubtitleParser {
    func parse(_ input: String) throws -> SubtitleParseResult {
        let blocks = normalizedBlocks(input)
        var segments: [SubtitleSegment] = []

        for block in blocks {
            guard let segment = try parseBlock(block, fallbackIndex: segments.count + 1) else {
                continue
            }
            segments.append(segment)
        }

        return SubtitleParseResult(segments: segments)
    }

    private func parseBlock(_ block: String, fallbackIndex: Int) throws -> SubtitleSegment? {
        let lines = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        guard !lines.isEmpty else {
            return nil
        }

        let timingLineIndex = lines.firstIndex { $0.contains("-->") }
        guard let timingLineIndex else {
            throw SubtitleImportError.parsingFailed("Invalid SRT block: \(block)")
        }

        let timingParts = lines[timingLineIndex].components(separatedBy: "-->")
        guard timingParts.count == 2 else {
            throw SubtitleImportError.parsingFailed("Invalid SRT timing line: \(lines[timingLineIndex])")
        }

        let startMs = try parseSRTTimestamp(timingParts[0].trimmingCharacters(in: .whitespacesAndNewlines))
        let endToken = timingParts[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .first
            .map(String.init) ?? ""
        let endMs = try parseSRTTimestamp(endToken)

        let textStartIndex = timingLineIndex + 1
        let text = lines.indices.contains(textStartIndex)
            ? lines[textStartIndex...].joined(separator: "\n")
            : ""

        return SubtitleSegment(
            id: UUID(),
            index: fallbackIndex,
            startMs: startMs,
            endMs: endMs,
            originalText: text,
            translatedText: "",
            speaker: nil,
            confidence: nil
        )
    }
}

struct WebVTTSubtitleParser {
    func parse(_ input: String) throws -> SubtitleParseResult {
        let lines = normalizeNewlines(input).components(separatedBy: "\n")
        var index = 0
        var segments: [SubtitleSegment] = []

        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("WEBVTT") == true {
            index = 1
        }

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)

            if line.isEmpty {
                index += 1
                continue
            }

            if line.hasPrefix("NOTE") || line == "STYLE" || line == "REGION" {
                index += 1
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    index += 1
                }
                continue
            }

            var timingLine = line
            if !timingLine.contains("-->"), index + 1 < lines.count {
                index += 1
                timingLine = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard timingLine.contains("-->") else {
                index += 1
                continue
            }

            let timingParts = timingLine.components(separatedBy: "-->")
            guard timingParts.count == 2 else {
                throw SubtitleImportError.parsingFailed("Invalid WebVTT timing line: \(timingLine)")
            }

            let startMs = try parseVTTTimestamp(timingParts[0])
            let endToken = timingParts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: { $0 == " " || $0 == "\t" })
                .first
                .map(String.init) ?? ""
            let endMs = try parseVTTTimestamp(endToken)

            index += 1
            var textLines: [String] = []
            while index < lines.count && !lines[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                textLines.append(cleanWebVTTText(lines[index]))
                index += 1
            }

            segments.append(makeSegment(
                index: segments.count + 1,
                startMs: startMs,
                endMs: endMs,
                text: textLines.joined(separator: "\n")
            ))
        }

        return SubtitleParseResult(segments: segments)
    }
}

struct ASSSubtitleParser {
    private let defaultFormat = ["Layer", "Start", "End", "Style", "Name", "MarginL", "MarginR", "MarginV", "Effect", "Text"]

    func parse(_ input: String) throws -> SubtitleParseResult {
        let lines = normalizeNewlines(input).components(separatedBy: "\n")
        var isInEvents = false
        var format = defaultFormat
        var segments: [SubtitleSegment] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                isInEvents = line.caseInsensitiveCompare("[Events]") == .orderedSame
                continue
            }

            guard isInEvents else {
                continue
            }

            if line.lowercased().hasPrefix("format:") {
                format = line.dropPrefix("Format:")
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                continue
            }

            guard line.lowercased().hasPrefix("dialogue:") else {
                continue
            }

            let values = splitASSDialogue(line.dropPrefix("Dialogue:"), fieldCount: format.count)
            guard let startIndex = format.firstCaseInsensitiveIndex(of: "Start"),
                  let endIndex = format.firstCaseInsensitiveIndex(of: "End"),
                  let textIndex = format.firstCaseInsensitiveIndex(of: "Text"),
                  values.indices.contains(startIndex),
                  values.indices.contains(endIndex),
                  values.indices.contains(textIndex) else {
                throw SubtitleImportError.parsingFailed("Invalid ASS Dialogue format.")
            }

            let text = cleanASSText(values[textIndex])
            segments.append(makeSegment(
                index: segments.count + 1,
                startMs: try parseASSTimestamp(values[startIndex]),
                endMs: try parseASSTimestamp(values[endIndex]),
                text: text
            ))
        }

        return SubtitleParseResult(segments: segments)
    }

    private func splitASSDialogue(_ value: String, fieldCount: Int) -> [String] {
        let maxSplits = max(0, fieldCount - 1)
        return value
            .split(separator: ",", maxSplits: maxSplits, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

struct PlainTextSubtitleParser {
    func parse(_ input: String) throws -> SubtitleParseResult {
        let normalizedInput = normalizeNewlines(input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedInput.isEmpty else {
            throw SubtitleImportError.emptyFile
        }

        let blocks: [String]
        if normalizedInput.contains("\n\n") {
            blocks = normalizedInput
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } else {
            blocks = normalizedInput
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let durationMs = 3_000
        let gapMs = 100
        let segments = blocks.enumerated().map { offset, text in
            let startMs = offset * (durationMs + gapMs)
            return makeSegment(index: offset + 1, startMs: startMs, endMs: startMs + durationMs, text: text)
        }

        return SubtitleParseResult(
            segments: segments,
            warnings: ["TXT file has no timings. Approximate timings were generated."]
        )
    }
}

struct SBVSubtitleParser {
    func parse(_ input: String) throws -> SubtitleParseResult {
        let blocks = normalizedBlocks(input)
        var segments: [SubtitleSegment] = []

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            guard let timingLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines), timingLine.contains(",") else {
                continue
            }

            let timingParts = timingLine.components(separatedBy: ",")
            guard timingParts.count == 2 else {
                throw SubtitleImportError.parsingFailed("Invalid SBV timing line: \(timingLine)")
            }

            let text = lines.dropFirst().joined(separator: "\n")
            segments.append(makeSegment(
                index: segments.count + 1,
                startMs: try parseVTTTimestamp(timingParts[0]),
                endMs: try parseVTTTimestamp(timingParts[1]),
                text: text
            ))
        }

        return SubtitleParseResult(segments: segments)
    }
}

enum SubtitleImportNormalizer {
    static func normalize(_ segments: [SubtitleSegment], videoDurationMs: Int? = nil) -> SubtitleParseResult {
        var warnings: [String] = []
        var normalizedSegments = segments.compactMap { segment -> SubtitleSegment? in
            var updated = segment
            updated.originalText = cleanPlainText(updated.originalText)
            updated.translatedText = updated.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.startMs = max(0, updated.startMs)

            guard !updated.originalText.isEmpty || !updated.translatedText.isEmpty else {
                return nil
            }

            if updated.endMs <= updated.startMs {
                updated.endMs = updated.startMs + SubtitleTimingValidator.minimumDurationMs
                warnings.append("Some invalid subtitle durations were adjusted.")
            }

            return updated
        }
        .sorted { $0.startMs == $1.startMs ? $0.index < $1.index : $0.startMs < $1.startMs }
        .enumerated()
        .map { offset, segment in
            var updated = segment
            updated.index = offset + 1
            return updated
        }

        if hasOverlaps(normalizedSegments) {
            warnings.append("Some subtitle timings overlap.")
        }

        if let videoDurationMs,
           normalizedSegments.contains(where: { $0.endMs > videoDurationMs + 1_000 }) {
            warnings.append("Some subtitles end after the video duration.")
        }

        normalizedSegments = SubtitleTimingValidator.reindexed(normalizedSegments)
        return SubtitleParseResult(segments: normalizedSegments, warnings: Array(Set(warnings)).sorted())
    }

    private static func hasOverlaps(_ segments: [SubtitleSegment]) -> Bool {
        for index in segments.indices.dropFirst() {
            if segments[index].startMs < segments[index - 1].endMs {
                return true
            }
        }
        return false
    }
}

func normalizeNewlines(_ input: String) -> String {
    input
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .replacingOccurrences(of: "\u{feff}", with: "")
}

func normalizedBlocks(_ input: String) -> [String] {
    normalizeNewlines(input)
        .components(separatedBy: "\n\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

func parseVTTTimestamp(_ value: String) throws -> Int {
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let mainParts = trimmedValue.split(separator: ".", omittingEmptySubsequences: false)
    guard mainParts.count == 2,
          let milliseconds = Int(mainParts[1].padding(toLength: 3, withPad: "0", startingAt: 0).prefix(3)) else {
        throw SubtitleImportError.invalidTimecode(value)
    }

    let timeParts = mainParts[0].split(separator: ":", omittingEmptySubsequences: false)
    guard timeParts.count == 2 || timeParts.count == 3 else {
        throw SubtitleImportError.invalidTimecode(value)
    }

    let hours: Int
    let minutes: Int
    let seconds: Int
    if timeParts.count == 3 {
        guard let parsedHours = Int(timeParts[0]),
              let parsedMinutes = Int(timeParts[1]),
              let parsedSeconds = Int(timeParts[2]) else {
            throw SubtitleImportError.invalidTimecode(value)
        }
        hours = parsedHours
        minutes = parsedMinutes
        seconds = parsedSeconds
    } else {
        guard let parsedMinutes = Int(timeParts[0]),
              let parsedSeconds = Int(timeParts[1]) else {
            throw SubtitleImportError.invalidTimecode(value)
        }
        hours = 0
        minutes = parsedMinutes
        seconds = parsedSeconds
    }

    guard minutes >= 0, seconds >= 0, seconds < 60, milliseconds >= 0, milliseconds < 1_000 else {
        throw SubtitleImportError.invalidTimecode(value)
    }

    return hours * 3_600_000 + minutes * 60_000 + seconds * 1_000 + milliseconds
}

func parseASSTimestamp(_ value: String) throws -> Int {
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmedValue.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 3,
          let hours = Int(parts[0]),
          let minutes = Int(parts[1]) else {
        throw SubtitleImportError.invalidTimecode(value)
    }

    let secondParts = parts[2].split(separator: ".", omittingEmptySubsequences: false)
    guard secondParts.count == 2,
          let seconds = Int(secondParts[0]),
          let centiseconds = Int(secondParts[1].padding(toLength: 2, withPad: "0", startingAt: 0).prefix(2)),
          minutes >= 0,
          seconds >= 0,
          seconds < 60 else {
        throw SubtitleImportError.invalidTimecode(value)
    }

    return hours * 3_600_000 + minutes * 60_000 + seconds * 1_000 + centiseconds * 10
}

func cleanWebVTTText(_ text: String) -> String {
    text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
}

func cleanASSText(_ text: String) -> String {
    cleanPlainText(
        text
            .replacingOccurrences(of: #"\{[^}]*\}"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\h", with: " ")
    )
}

func cleanPlainText(_ text: String) -> String {
    normalizeNewlines(text)
        .components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func makeSegment(index: Int, startMs: Int, endMs: Int, text: String) -> SubtitleSegment {
    SubtitleSegment(
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

private extension String {
    func dropPrefix(_ prefix: String) -> String {
        guard lowercased().hasPrefix(prefix.lowercased()) else {
            return self
        }

        return String(dropFirst(prefix.count))
    }
}

private extension Array where Element == String {
    func firstCaseInsensitiveIndex(of value: String) -> Int? {
        firstIndex { $0.caseInsensitiveCompare(value) == .orderedSame }
    }
}

extension String.Encoding {
    static let windowsCP1251 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.windowsCyrillic.rawValue))
    )
}
