import Foundation

public struct VideoExportJob: Identifiable, Equatable {
    public let id: UUID
    public let projectName: String
    public let outputURL: URL
    public var status: VideoExportJobStatus
    public var statusText: String
    public var progress: Double?
    public var errorMessage: String?
    public var debugOutput: String?

    public var isFinished: Bool {
        switch status {
        case .succeeded, .failed:
            return true
        case .queued, .exporting:
            return false
        }
    }

    public init(
        id: UUID,
        projectName: String,
        outputURL: URL,
        status: VideoExportJobStatus,
        statusText: String,
        progress: Double?,
        errorMessage: String?,
        debugOutput: String?
    ) {
        self.id = id
        self.projectName = projectName
        self.outputURL = outputURL
        self.status = status
        self.statusText = statusText
        self.progress = progress
        self.errorMessage = errorMessage
        self.debugOutput = debugOutput
    }
}
