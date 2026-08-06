public struct SubtitleImportMergePolicy {
    public init() {}

    public func merge(
        current: [SubtitleSegment],
        imported: [SubtitleSegment],
        mode: SubtitleImportMode,
        destination: SubtitleImportDestination
    ) -> [SubtitleSegment] {
        let merged: [SubtitleSegment]
        switch destination {
        case .original:
            merged = mode == .replaceExisting ? imported : current + imported

        case .translated:
            let translated = imported.map { importedSegment in
                var updated = importedSegment
                updated.originalText = ""
                updated.translatedText = importedSegment.originalText
                return updated
            }

            switch mode {
            case .appendToExisting:
                merged = current + translated
            case .replaceExisting:
                guard !current.isEmpty else {
                    return SubtitleTimingValidator.reindexed(translated)
                }
                var result = current
                for index in 0..<min(result.count, imported.count) {
                    result[index].translatedText = imported[index].originalText
                }
                if imported.count > result.count {
                    result.append(contentsOf: translated.dropFirst(result.count))
                }
                merged = result
            }
        }

        return SubtitleTimingValidator.reindexed(merged)
    }
}
