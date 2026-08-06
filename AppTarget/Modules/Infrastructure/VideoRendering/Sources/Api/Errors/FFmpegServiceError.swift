import Foundation

public enum FFmpegServiceError: LocalizedError, CustomDebugStringConvertible {
    case notFound
    case launchFailed(executablePath: String, underlyingDescription: String)
    case processFailed(exitCode: Int32, standardOutput: String, standardError: String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "FFmpeg was not found. Install FFmpeg or set the correct path."
        case .launchFailed(_, let underlyingDescription):
            return "FFmpeg could not be launched: \(underlyingDescription)"
        case .processFailed(let exitCode, _, _):
            return "FFmpeg failed with exit code \(exitCode)."
        }
    }

    public var debugDescription: String {
        switch self {
        case .notFound:
            return "FFmpeg executable was not found at /opt/homebrew/bin/ffmpeg, /usr/local/bin/ffmpeg, /usr/bin/ffmpeg, or in PATH."
        case .launchFailed(let executablePath, let underlyingDescription):
            return "FFmpeg launch failed for \(executablePath): \(underlyingDescription)"
        case .processFailed(let exitCode, let standardOutput, let standardError):
            return """
            FFmpeg failed with exit code \(exitCode).
            stdout:
            \(standardOutput)
            stderr:
            \(standardError)
            """
        }
    }
}
