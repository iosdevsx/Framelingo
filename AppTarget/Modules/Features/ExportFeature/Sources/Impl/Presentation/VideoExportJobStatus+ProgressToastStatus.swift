import DesignSystem
import VideoExport

extension VideoExportJobStatus {
    var progressToastStatus: ProgressToastStatus {
        switch self {
        case .queued:
            return .queued
        case .preparing, .exporting, .writingSidecar:
            return .running
        case .succeeded:
            return .succeeded
        case .failed:
            return .failed
        }
    }
}
