import Foundation

public enum VideoExportFailureCode: String, Equatable, Sendable {
    case missingSubtitles
    case missingMedia
    case emptyTimeline
    case assGeneration
    case ffmpegUnavailable
    case missingASSFilter
    case missingH264Encoder
    case rendering
    case sidecar
    case lostRequest
}

public struct VideoExportFailure: Error, Equatable, Sendable {
    public let code: VideoExportFailureCode
    public let message: String
    public let debugOutput: String?

    public init(code: VideoExportFailureCode, message: String, debugOutput: String? = nil) {
        self.code = code
        self.message = message
        self.debugOutput = debugOutput
    }
}
