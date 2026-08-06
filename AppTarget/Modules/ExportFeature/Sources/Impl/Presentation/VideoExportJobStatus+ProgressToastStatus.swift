import DesignSystem
import VideoRendering

extension VideoExportJobStatus {
    var progressToastStatus: ProgressToastStatus {
        switch self {
        case .queued:
            return .queued
        case .exporting:
            return .running
        case .succeeded:
            return .succeeded
        case .failed:
            return .failed
        }
    }
}
