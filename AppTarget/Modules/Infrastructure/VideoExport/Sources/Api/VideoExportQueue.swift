import Combine
import Foundation

@MainActor
public protocol VideoExportQueue: AnyObject {
    var jobs: [VideoExportJob] { get }
    var jobSnapshots: AnyPublisher<[VideoExportJob], Never> { get }

    func enqueue(_ request: VideoExportRequest)
    func enqueue(_ batch: ShortsVideoExportBatchRequest)
    func removeFinishedJob(id: UUID)
}
