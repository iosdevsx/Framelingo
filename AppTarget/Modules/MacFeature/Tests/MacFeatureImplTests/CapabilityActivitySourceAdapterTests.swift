import Combine
import VideoExport
import VideoRendering
import XCTest

@testable import MacFeatureImpl

@MainActor
final class CapabilityActivitySourceAdapterTests: XCTestCase {
    func testProgressFlowsFromCanonicalOwnerAndDismissRoutesBack() {
        let dependencies = MacCompositionRoot.makeDependencies()
        let activity = dependencies.transcriptionActivity
        let source = CapabilityActivitySourceAdapter(
            transcriptionActivity: activity,
            videoExportQueue: dependencies.videoExportQueue
        ).source
        var snapshots = [source.snapshot]
        let subscription = source.snapshots.sink { snapshots.append($0) }

        activity.start(projectName: "Demo")
        activity.update(statusText: "Transcribing", progress: 0.5)
        let item = snapshots.last?.items.first
        XCTAssertEqual(item?.title, "Demo")
        XCTAssertEqual(item?.progress, 0.5)

        if let id = item?.id {
            activity.finish(success: true, message: nil)
            source.dismiss(id: id)
        }
        XCTAssertNil(activity.activity)
        _ = subscription
    }

    func testComposedVideoExportQueueFeedsTheProductActivitySource() {
        let dependencies = MacCompositionRoot.makeDependencies()
        let source = CapabilityActivitySourceAdapter(
            transcriptionActivity: dependencies.transcriptionActivity,
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
