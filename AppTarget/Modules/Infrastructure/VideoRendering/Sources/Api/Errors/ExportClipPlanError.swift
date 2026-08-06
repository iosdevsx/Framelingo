import Foundation

public enum ExportClipPlanError: LocalizedError, Equatable {
    case emptyPlan

    public var errorDescription: String? {
        switch self {
        case .emptyPlan:
            return "The edit timeline has no clips to export. Review your cuts in Edit mode."
        }
    }
}
