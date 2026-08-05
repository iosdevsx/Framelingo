import Application
import DesignSystem

extension TranscriptionActivityStatus {
    var progressToastStatus: ProgressToastStatus {
        switch self {
        case .running:
            return .running
        case .succeeded:
            return .succeeded
        case .failed:
            return .failed
        }
    }
}
