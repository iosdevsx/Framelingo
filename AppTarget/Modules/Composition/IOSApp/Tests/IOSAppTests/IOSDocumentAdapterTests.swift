import Foundation
@testable import IOSApp
import Project
import XCTest

final class IOSDocumentAdapterTests: XCTestCase {
    func testPickerCancellationIsNotReportedAsFailure() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)

        guard case .cancelled = IOSDocumentPickerAdapter.outcome(from: .failure(error)) else {
            return XCTFail("Expected cancellation")
        }
    }

    func testExpiredSecurityScopedAccessIsReportedExplicitly() async throws {
        let directory = try temporaryDirectory()
        let root = directory.appendingPathComponent("Media", isDirectory: true)
        let source = directory.appendingPathComponent("video.mov")
        try Data("video".utf8).write(to: source)
        let adapter = makeAdapter(root: root, accessGranted: false)

        do {
            _ = try await adapter.importMedia(from: source)
            XCTFail("Expected access denial")
        } catch let error as IOSDocumentImportFailure {
            XCTAssertEqual(error, .accessDenied(source.path))
        }
    }

    func testMissingFileIsReportedAndAccessIsReleased() async throws {
        let directory = try temporaryDirectory()
        let source = directory.appendingPathComponent("missing.mov")
        let releaseMarker = directory.appendingPathComponent("released")
        let adapter = makeAdapter(
            root: directory.appendingPathComponent("Media", isDirectory: true),
            releaseMarker: releaseMarker
        )

        do {
            _ = try await adapter.importMedia(from: source)
            XCTFail("Expected missing source")
        } catch let error as IOSDocumentImportFailure {
            XCTAssertEqual(error, .sourceMissing(source.path))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: releaseMarker.path))
    }

    func testMediaWithSpacesAndCyrillicIsCopiedAndAccessIsReleased() async throws {
        let directory = try temporaryDirectory()
        let source = directory.appendingPathComponent("Интервью final.mov")
        let releaseMarker = directory.appendingPathComponent("released")
        let bytes = Data("video payload".utf8)
        try bytes.write(to: source)
        let adapter = makeAdapter(
            root: directory.appendingPathComponent("Managed Media", isDirectory: true),
            releaseMarker: releaseMarker
        )

        let media = try await adapter.importMedia(from: source)

        XCTAssertEqual(media.fileName, "Интервью final.mov")
        XCTAssertEqual(try Data(contentsOf: media.originalURL), bytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: releaseMarker.path))
    }

    func testSharePreparationPropagatesSaveFailure() async throws {
        let adapter = IOSProjectShareAdapter(
            exportRootURL: try temporaryDirectory(),
            projectFileService: FailingProjectFileService()
        )

        do {
            _ = try await adapter.prepare(makeProject())
            XCTFail("Expected export failure")
        } catch {
            XCTAssertEqual(error as? AdapterTestError, .failed)
        }
    }

    private func makeAdapter(
        root: URL,
        accessGranted: Bool = true,
        releaseMarker: URL? = nil
    ) -> IOSDocumentImportAdapter {
        IOSDocumentImportAdapter(
            mediaRootURL: root,
            projectFileService: FailingProjectFileService(),
            securityAccess: IOSSecurityScopedAccess(
                start: { _ in accessGranted },
                stop: { _ in
                    if let releaseMarker {
                        FileManager.default.createFile(
                            atPath: releaseMarker.path,
                            contents: Data()
                        )
                    }
                }
            ),
            durationReader: IOSMediaDurationReader { _ in 2_000 }
        )
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "IOSDocumentAdapterTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}

@MainActor
final class IOSAppSaveFailureTests: XCTestCase {
    func testExplicitSaveFailureBecomesUnderstandablePresentationError() async {
        let repository = SaveFailingRepository()
        let model = IOSAppComposition.makeModel(repository: repository)
        model.open(makeProject())

        await model.saveProject()

        XCTAssertEqual(model.errorMessage, "The project could not be saved.")
    }
}

private enum AdapterTestError: Error, Equatable {
    case failed
}

private struct FailingProjectFileService: ProjectFileServicing {
    func exportProject(_ project: Project, to fileURL: URL) throws {
        throw AdapterTestError.failed
    }

    func importProject(from fileURL: URL) throws -> Project {
        throw AdapterTestError.failed
    }
}

private final class SaveFailingRepository: ProjectRepository {
    func createProject(for mediaFile: MediaFile) async throws -> Project { makeProject() }
    func saveProject(_ project: Project) async throws { throw AdapterTestError.failed }
    func loadProject(id: UUID) async throws -> Project { throw AdapterTestError.failed }
    func listProjects() async throws -> [Project] { [] }
    func deleteProject(id: UUID) async throws {}
}

private func makeProject() -> Project {
    Project(
        id: UUID(),
        name: "Adapter Project",
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        mediaFile: MediaFile(
            id: UUID(),
            originalURL: URL(fileURLWithPath: "/tmp/video.mov"),
            fileName: "video.mov",
            fileExtension: "mov",
            sizeBytes: 1,
            durationMs: 2_000
        ),
        sourceLanguage: "English",
        targetLanguage: "Russian",
        subtitles: [],
        status: .idle
    )
}
