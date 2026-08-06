import Foundation
import SpeakerAnalysis

struct ParakeetAudioWindow: Equatable {
    var start: TimeInterval
    var end: TimeInterval
    var commitStart: TimeInterval
    var commitEnd: TimeInterval

    static func plan(
        duration: TimeInterval,
        windowDuration: TimeInterval,
        overlap: TimeInterval
    ) -> [ParakeetAudioWindow] {
        guard duration > 0, windowDuration > 0 else {
            return []
        }

        let minimumStride = min(1, windowDuration)
        let boundedOverlap = min(max(overlap, 0), max(0, windowDuration - minimumStride))
        guard duration > windowDuration else {
            return [
                ParakeetAudioWindow(
                    start: 0,
                    end: duration,
                    commitStart: 0,
                    commitEnd: duration
                )
            ]
        }

        let stride = windowDuration - boundedOverlap
        let minimumWindowDuration = min(1, windowDuration)
        var rawWindows: [(start: TimeInterval, end: TimeInterval)] = []
        var start: TimeInterval = 0

        while start < duration {
            let end = min(duration, start + windowDuration)
            if end - start >= minimumWindowDuration {
                rawWindows.append((start: start, end: end))
            }
            start += stride
        }

        guard !rawWindows.isEmpty else {
            return [
                ParakeetAudioWindow(
                    start: 0,
                    end: duration,
                    commitStart: 0,
                    commitEnd: duration
                )
            ]
        }

        return rawWindows.enumerated().map { offset, rawWindow in
            let commitStart: TimeInterval
            if offset == 0 {
                commitStart = 0
            } else {
                let previous = rawWindows[offset - 1]
                commitStart = (previous.end + rawWindow.start) / 2
            }

            let commitEnd: TimeInterval
            if offset == rawWindows.count - 1 {
                commitEnd = duration
            } else {
                let next = rawWindows[offset + 1]
                commitEnd = (rawWindow.end + next.start) / 2
            }

            return ParakeetAudioWindow(
                start: rawWindow.start,
                end: rawWindow.end,
                commitStart: commitStart,
                commitEnd: commitEnd
            )
        }
    }

    func containsCommitted(_ word: WordTiming) -> Bool {
        let midpoint = (word.start + word.end) / 2
        return midpoint >= commitStart && midpoint < commitEnd
    }
}
