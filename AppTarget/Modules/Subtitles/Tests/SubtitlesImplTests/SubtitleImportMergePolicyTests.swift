import Foundation
import Subtitles
import Testing

struct SubtitleImportMergePolicyTests {
    private let policy = SubtitleImportMergePolicy()

    @Test
    func originalReplaceAndAppendPreserveImportedValuesAndReindex() {
        let current = [segment(index: 8, startMs: 0, text: "current")]
        let imported = [
            segment(index: 4, startMs: 2_000, text: "first"),
            segment(index: 2, startMs: 4_000, text: "second"),
        ]

        let replaced = policy.merge(
            current: current, imported: imported,
            mode: .replaceExisting, destination: .original
        )
        let appended = policy.merge(
            current: current, imported: imported,
            mode: .appendToExisting, destination: .original
        )

        #expect(replaced.map(\.originalText) == ["first", "second"])
        #expect(replaced.map(\.index) == [1, 2])
        #expect(appended.map(\.originalText) == ["current", "first", "second"])
        #expect(appended.map(\.index) == [1, 2, 3])
    }

    @Test
    func translatedReplaceUpdatesSharedRowsAndAppendsOverflow() {
        let current = [
            segment(index: 1, text: "A", translated: "old A"),
            segment(index: 2, text: "B", translated: "old B"),
        ]
        let imported = [
            segment(index: 1, text: "I1"),
            segment(index: 2, text: "I2"),
            segment(index: 3, text: "I3"),
        ]

        let result = policy.merge(
            current: current, imported: imported,
            mode: .replaceExisting, destination: .translated
        )

        #expect(result.map(\.originalText) == ["A", "B", ""])
        #expect(result.map(\.translatedText) == ["I1", "I2", "I3"])
        #expect(result[0].id == current[0].id)
        #expect(result[2].id == imported[2].id)
    }

    @Test
    func translatedReplaceWithFewerImportsLeavesRemainingRowsUnchanged() {
        let current = [
            segment(index: 1, text: "A", translated: "old A"),
            segment(index: 2, text: "B", translated: "old B"),
        ]
        let imported = [segment(index: 1, text: "I1")]

        let result = policy.merge(
            current: current, imported: imported,
            mode: .replaceExisting, destination: .translated
        )

        #expect(result.map(\.translatedText) == ["I1", "old B"])
    }

    @Test
    func translatedAppendClearsOriginalTextOnlyForImportedRows() {
        let current = [segment(index: 1, text: "A", translated: "TA")]
        let imported = [segment(index: 2, text: "I")]

        let result = policy.merge(
            current: current, imported: imported,
            mode: .appendToExisting, destination: .translated
        )

        #expect(result.map(\.originalText) == ["A", ""])
        #expect(result.map(\.translatedText) == ["TA", "I"])
    }

    @Test
    func emptyInputsRemainWellDefinedAcrossModes() {
        let imported = [segment(index: 4, text: "I")]

        #expect(policy.merge(
            current: [], imported: [], mode: .replaceExisting, destination: .original
        ).isEmpty)
        let translated = policy.merge(
            current: [], imported: imported, mode: .replaceExisting, destination: .translated
        )
        #expect(translated.map(\.originalText) == [""])
        #expect(translated.map(\.translatedText) == ["I"])
    }

    private func segment(
        index: Int,
        startMs: Int? = nil,
        text: String,
        translated: String = ""
    ) -> SubtitleSegment {
        let startMs = startMs ?? index * 2_000
        return SubtitleSegment(
            id: UUID(), index: index, startMs: startMs,
            endMs: startMs + 1_000,
            originalText: text, translatedText: translated
        )
    }
}
