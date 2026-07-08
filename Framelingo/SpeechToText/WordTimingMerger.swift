import FluidAudio
import Foundation

struct WordTimingMerger {
    func merge(_ tokens: [TokenTiming]) -> [WordTiming] {
        var result: [WordTiming] = []
        var currentTokens: [TimedToken] = []

        for token in tokens {
            let text = normalizedTokenText(token.token)
            if text.hasPrefix(" "), !currentTokens.isEmpty {
                if let word = makeWordTiming(from: currentTokens) {
                    result.append(word)
                }
                currentTokens = []
            }

            currentTokens.append(TimedToken(
                text: text,
                start: token.startTime,
                end: token.endTime,
                confidence: Double(token.confidence)
            ))
        }

        if let word = makeWordTiming(from: currentTokens) {
            result.append(word)
        }

        return result
    }

    private func makeWordTiming(from tokens: [TimedToken]) -> WordTiming? {
        guard let first = tokens.first, let last = tokens.last else {
            return nil
        }

        let text = tokens
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty, last.end > first.start else {
            return nil
        }

        return WordTiming(
            text: text,
            start: first.start,
            end: last.end,
            confidence: meanConfidence(tokens)
        )
    }

    private func meanConfidence(_ tokens: [TimedToken]) -> Double? {
        guard !tokens.isEmpty else {
            return nil
        }

        let total = tokens.reduce(0) { $0 + $1.confidence }
        return total / Double(tokens.count)
    }

    private func normalizedTokenText(_ text: String) -> String {
        text.replacingOccurrences(of: "▁", with: " ")
    }
}

private struct TimedToken {
    var text: String
    var start: TimeInterval
    var end: TimeInterval
    var confidence: Double
}
