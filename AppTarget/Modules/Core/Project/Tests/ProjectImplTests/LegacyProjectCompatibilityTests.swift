import Foundation
import Project
import ProjectImpl
import Testing

struct LegacyProjectCompatibilityTests {
    @Test
    func legacyFixtureDecodesAndRoundtrips() throws {
        let fixtureURL = Bundle.module.url(
            forResource: "LegacyProject",
            withExtension: "json",
            subdirectory: "Fixtures"
        )
        let sourceURL = try #require(fixtureURL)
        let service = ProjectAssembly.makeFileService()
        let project = try service.importProject(from: sourceURL)

        #expect(project.id == UUID(uuidString: "8A39B73E-6C7F-4B0A-BC12-CFEBC10E5964"))
        #expect(project.name == "Legacy Cyrillic Project")
        #expect(project.mediaFile.fileName == "Интервью final.mov")
        #expect(project.subtitles.count == 2)
        #expect(project.subtitles[1].translatedText == "Пути могут содержать пробелы и кириллицу.")
        #expect(project.speakerLabels.map(\.displayName) == ["Interviewer", "Guest"])
        #expect(project.editTimeline?.totalDurationMs == 6_000)
        #expect(project.shorts.first?.title == "Legacy Short")
        #expect(project.videoExportSettings.resolution.rawValue == "p1080")
        #expect(project.status == .ready)

        let roundtripURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyProjectRoundtrip-\(UUID().uuidString).json")
        try service.exportProject(project, to: roundtripURL)
        let decoded = try service.importProject(from: roundtripURL)
        #expect(decoded == project)
        try FileManager.default.removeItem(at: roundtripURL)
    }
}
