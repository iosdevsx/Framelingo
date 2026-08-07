import Foundation
@testable import IOSApp
import Project
import ProjectImpl
import XCTest

@MainActor
final class IOSProjectCompatibilityTests: XCTestCase {
    func testMacFixtureIOSSubtitleEditAndMacReopenRoundtrip() async throws {
        let fileManager = FileManager.default
        let testRoot = fileManager.temporaryDirectory.appendingPathComponent(
            "IOSProjectCompatibilityTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: testRoot, withIntermediateDirectories: true)

        let fileService = ProjectAssembly.makeFileService()
        var macCreated = try fileService.importProject(from: legacyFixtureURL())
        let sourceMedia = testRoot.appendingPathComponent("Интервью final.mov")
        try Data("video".utf8).write(to: sourceMedia)
        macCreated.mediaFile.originalURL = sourceMedia
        macCreated.mediaFile.sizeBytes = 5

        let selectedProjectURL = testRoot.appendingPathComponent("Mac Project.json")
        try fileService.exportProject(macCreated, to: selectedProjectURL)
        let importer = IOSDocumentImportAdapter(
            mediaRootURL: testRoot.appendingPathComponent("Managed Media", isDirectory: true),
            projectFileService: fileService,
            securityAccess: .init(start: { _ in true }, stop: { _ in }),
            durationReader: .init(durationMilliseconds: { _ in 120_000 })
        )

        let iosImported = try await importer.importProject(from: selectedProjectURL)

        XCTAssertEqual(iosImported.editTimeline, macCreated.editTimeline)
        XCTAssertEqual(iosImported.shorts, macCreated.shorts)
        XCTAssertEqual(iosImported.shortsExportSettings, macCreated.shortsExportSettings)
        XCTAssertEqual(iosImported.videoExportSettings, macCreated.videoExportSettings)
        XCTAssertEqual(iosImported.speakerExportOptions, macCreated.speakerExportOptions)

        let repository = ProjectAssembly.makeRepository(
            projectsDirectory: testRoot.appendingPathComponent("Projects", isDirectory: true)
        )
        try await repository.saveProject(iosImported)
        let model = IOSAppComposition.makeModel(
            repository: repository,
            documentImporter: importer
        )
        model.open(iosImported)
        var edited = try XCTUnwrap(model.snapshot.project?.subtitles.first)
        edited.translatedText = "Изменено на iOS"

        let result = model.subtitleEditorActions.updateSubtitle(edited)
        XCTAssertNil(result.errorMessage)
        await model.saveProject()

        let macReopened = try await repository.loadProject(id: iosImported.id)
        XCTAssertEqual(macReopened.subtitles.first?.translatedText, "Изменено на iOS")
        XCTAssertEqual(macReopened.mediaFile.originalURL, iosImported.mediaFile.originalURL)
        XCTAssertEqual(macReopened.editTimeline, macCreated.editTimeline)
        XCTAssertEqual(macReopened.shorts, macCreated.shorts)
        XCTAssertEqual(macReopened.shortsExportSettings, macCreated.shortsExportSettings)
        XCTAssertEqual(macReopened.videoExportSettings, macCreated.videoExportSettings)

        let reverseURL = testRoot.appendingPathComponent("IOS Edited Project.json")
        try fileService.exportProject(macReopened, to: reverseURL)
        let decodedByMacCodec = try fileService.importProject(from: reverseURL)
        XCTAssertEqual(decodedByMacCodec, macReopened)

        await model.closeWorkspace()
    }

    private func legacyFixtureURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(
                "../../../../Core/Project/Tests/ProjectImplTests/Fixtures/LegacyProject.json"
            )
            .standardizedFileURL
    }
}
