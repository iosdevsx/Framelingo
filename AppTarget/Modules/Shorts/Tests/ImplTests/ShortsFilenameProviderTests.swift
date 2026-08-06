import Foundation
import Shorts
import Testing

struct ShortsFilenameProviderTests {
    @Test
    func templateExpansionSupportsCyrillicAndPaddedIndex() {
        let name = ShortsFilenameTemplate.baseName(
            template: "{project} — {index} {title}",
            projectName: "F1 GP",
            index: 2,
            totalCount: 8,
            shortTitle: "Питстоп"
        )
        #expect(name == "F1 GP — 02 Питстоп")
    }

    @Test
    func illegalCharactersAreReplaced() {
        let name = ShortsFilenameTemplate.baseName(
            template: "{title}",
            projectName: "P",
            index: 1,
            totalCount: 1,
            shortTitle: "AB/CD:EF?"
        )
        #expect(name == "AB CD EF")
    }

    @Test
    func emptyExpansionFallsBackToNumberedDefault() {
        let name = ShortsFilenameTemplate.baseName(
            template: "{title}",
            projectName: "P",
            index: 3,
            totalCount: 12,
            shortTitle: "   "
        )
        #expect(name == "Short 03")
    }

    @Test
    func collisionsUseNumericSuffixes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShortsNames-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                if FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.removeItem(at: directory)
                }
            } catch {
                Issue.record("Temporary directory cleanup failed: \(error)")
            }
        }
        try Data().write(to: directory.appendingPathComponent("Clip.mp4"))

        let second = ShortsFilenameTemplate.availableURL(
            in: directory,
            baseName: "Clip",
            fileExtension: "mp4"
        )
        #expect(second.lastPathComponent == "Clip 2.mp4")

        let third = ShortsFilenameTemplate.availableURL(
            in: directory,
            baseName: "Clip",
            fileExtension: "mp4",
            reservedPaths: [second.path]
        )
        #expect(third.lastPathComponent == "Clip 3.mp4")
    }
}
