import Foundation
import SpeechToText

actor WhisperProgressParser {
    private var bufferedOutput = ""
    private var lastProgress: Double = 0.15
    private let progressHandler: TranscriptionProgressHandler?

    init(progressHandler: TranscriptionProgressHandler?) {
        self.progressHandler = progressHandler
    }

    func append(_ data: Data) {
        guard !data.isEmpty,
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        bufferedOutput += text
        let progress = parseProgress(from: bufferedOutput)

        guard let progress,
              progress > lastProgress else {
            return
        }

        lastProgress = progress
        Task {
            await progressHandler?(progress, "Running Whisper... \(Int((progress * 100).rounded()))%")
        }
    }

    private func parseProgress(from text: String) -> Double? {
        let pattern = #"progress\s*=\s*([0-9]{1,3})%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).last,
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text),
              let percent = Double(text[range]) else {
            return nil
        }

        return min(max(0.15 + percent / 100 * 0.80, 0.15), 0.95)
    }
}
