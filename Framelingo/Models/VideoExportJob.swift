import Foundation

struct VideoExportJob: Identifiable, Equatable {
    let id: UUID
    let projectName: String
    let outputURL: URL
    var status: VideoExportJobStatus
    var statusText: String
    var progress: Double?
    var errorMessage: String?
    var debugOutput: String?

    var isFinished: Bool {
        switch status {
        case .succeeded, .failed:
            return true
        case .queued, .exporting:
            return false
        }
    }
}

enum VideoExportJobStatus: Equatable {
    case queued
    case exporting
    case succeeded
    case failed
}
