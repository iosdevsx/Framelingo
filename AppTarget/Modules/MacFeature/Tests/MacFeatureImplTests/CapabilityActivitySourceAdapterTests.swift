import Combine
import ProjectSession
import ProjectSessionImpl
import VideoExport
import VideoRendering
import XCTest

@testable import MacFeatureImpl

@MainActor
final class CapabilityActivitySourceAdapterTests: XCTestCase {
    func testTypedSessionFailureFlowsToActivityAndDismissRoutesBack() async {
        let dependencies = MacCompositionRoot.makeDependencies()
        let session = DefaultProjectSession(dependencies: ProjectSessionDependencies(
            repository: dependencies.projectRepository
        ))
        session.open(dependencies.mockProject)
        let source = CapabilityActivitySourceAdapter(
            session: session,
            videoExportQueue: dependencies.videoExportQueue
        ).source
        var snapshots = [source.snapshot]
        let subscription = source.snapshots.sink { snapshots.append($0) }

        await session.transcribe()
        let item = snapshots.last?.items.first
        XCTAssertEqual(item?.title, dependencies.mockProject.displayName)
        XCTAssertEqual(item?.status, .failed)

        if let id = item?.id {
            source.dismiss(id: id)
        }
        XCTAssertTrue(source.snapshot.items.isEmpty)
        _ = subscription
    }

    func testComposedVideoExportQueueFeedsTheProductActivitySource() {
        let dependencies = MacCompositionRoot.makeDependencies()
        let session = DefaultProjectSession(dependencies: ProjectSessionDependencies(
            repository: dependencies.projectRepository
        ))
        session.open(dependencies.mockProject)
        let source = CapabilityActivitySourceAdapter(
            session: session,
            videoExportQueue: dependencies.videoExportQueue
        ).source
        let request = FullProjectVideoExportRequest(
            project: dependencies.mockProject,
            settings: VideoExportSettings(),
            sourceInfo: nil,
            outputURL: FileManager.default.temporaryDirectory.appendingPathComponent("activity-source-export.mp4")
        )
        dependencies.videoExportQueue.enqueue(.fullProject(request))
        let item = source.snapshot.items.first { $0.id == "video-export-\(request.id.uuidString)" }
        XCTAssertEqual(item?.title, dependencies.mockProject.displayName)
        XCTAssertEqual(item?.status, .running)
    }
}
