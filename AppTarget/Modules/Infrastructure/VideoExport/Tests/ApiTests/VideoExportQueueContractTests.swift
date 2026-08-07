import Combine
import Foundation
import Media
import Project
import Subtitles
import VideoExport
import VideoRendering
import XCTest

@MainActor
final class VideoExportQueueContractTests: XCTestCase {
    func testConsumerCanEnqueueObserveAndRemoveWithoutImplementationModule() {
        let queue = RecordingVideoExportQueue()
        var snapshots: [[VideoExport.VideoExportJob]] = []
        let cancellable = queue.jobSnapshots.sink { snapshots.append($0) }
        let request = makeRequest()

        queue.enqueue(.fullProject(request))
        XCTAssertEqual(queue.jobs.map(\.id), [request.id])
        XCTAssertEqual(snapshots.last?.map(\.id), [request.id])

        queue.complete(id: request.id)
        queue.removeFinishedJob(id: request.id)
        XCTAssertTrue(queue.jobs.isEmpty)
        withExtendedLifetime(cancellable) {}
    }

    private func makeRequest() -> FullProjectVideoExportRequest {
        let mediaURL = URL(fileURLWithPath: "/tmp/contract.mov")
        return FullProjectVideoExportRequest(
            project: Project(
                id: UUID(),
                name: "Contract",
                createdAt: Date(),
                updatedAt: Date(),
                mediaFile: MediaFile(
                    id: UUID(),
                    originalURL: mediaURL,
                    fileName: "contract.mov",
                    fileExtension: "mov",
                    sizeBytes: 0,
                    durationMs: 1_000
                ),
                sourceLanguage: "en",
                targetLanguage: "ru",
                subtitles: [],
                status: .idle
            ),
            settings: VideoExportSettings(),
            sourceInfo: nil,
            outputURL: URL(fileURLWithPath: "/tmp/contract.mp4")
        )
    }
}

@MainActor
private final class RecordingVideoExportQueue: VideoExportQueue {
    private let subject = CurrentValueSubject<[VideoExport.VideoExportJob], Never>([])
    private(set) var jobs: [VideoExport.VideoExportJob] = [] {
        didSet { subject.send(jobs) }
    }
    var jobSnapshots: AnyPublisher<[VideoExport.VideoExportJob], Never> { subject.eraseToAnyPublisher() }

    func enqueue(_ request: VideoExportRequest) {
        jobs.append(VideoExport.VideoExportJob(
            id: request.id,
            projectName: request.projectName,
            outputURL: request.outputURL,
            status: .queued,
            statusText: "Queued",
            progress: nil
        ))
    }

    func enqueue(_ batch: ShortsVideoExportBatchRequest) {}

    func removeFinishedJob(id: UUID) {
        jobs.removeAll { $0.id == id && $0.isFinished }
    }

    func complete(id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        let old = jobs[index]
        jobs[index] = VideoExport.VideoExportJob(
            id: old.id,
            projectName: old.projectName,
            outputURL: old.outputURL,
            status: .succeeded,
            statusText: "Done",
            progress: 1
        )
    }
}
