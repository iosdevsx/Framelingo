import Foundation

struct FFmpegInfo: Equatable {
    var executableURL: URL
    var version: String
}

typealias FFmpegProgressHandler = @Sendable (_ processedTimeMs: Int) async -> Void

protocol FFmpegService {
    func checkAvailability() async throws -> FFmpegInfo
    func extractAudio(from videoURL: URL, to outputURL: URL) async throws -> URL
    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL
}

extension FFmpegService {
    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings
    ) async throws -> URL {
        try await burnSubtitles(
            videoURL: videoURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: settings,
            progressHandler: nil
        )
    }
}

final class ProcessFFmpegService: FFmpegService {
    private let preferredExecutableURL: URL

    init(
        preferredExecutableURL: URL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    ) {
        self.preferredExecutableURL = preferredExecutableURL.standardizedFileURL
    }

    func checkAvailability() async throws -> FFmpegInfo {
        let executableURL = try resolveExecutableURL()
        let result = try await runFFmpeg(executableURL: executableURL, arguments: ["-version"])
        let version = result.standardOutput
            .split(separator: "\n")
            .first
            .map(String.init) ?? "ffmpeg version unknown"

        return FFmpegInfo(executableURL: executableURL, version: version)
    }

    func extractAudio(from videoURL: URL, to outputURL: URL) async throws -> URL {
        let executableURL = try resolveExecutableURL()
        let inputAccess = videoURL.startAccessingSecurityScopedResource()
        let outputAccess = outputURL.deletingLastPathComponent().startAccessingSecurityScopedResource()
        defer {
            if inputAccess {
                videoURL.stopAccessingSecurityScopedResource()
            }
            if outputAccess {
                outputURL.deletingLastPathComponent().stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        _ = try await runFFmpeg(
            executableURL: executableURL,
            arguments: [
                "-y",
                "-i", videoURL.path,
                "-vn",
                "-af", "aresample=async=1:first_pts=0",
                "-acodec", "pcm_s16le",
                "-ar", "16000",
                "-ac", "1",
                outputURL.path
            ]
        )

        return outputURL
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        let executableURL = try resolveExecutableURL()
        let videoAccess = videoURL.startAccessingSecurityScopedResource()
        let subtitlesAccess = subtitlesURL.startAccessingSecurityScopedResource()
        let outputAccess = outputURL.deletingLastPathComponent().startAccessingSecurityScopedResource()
        defer {
            if videoAccess {
                videoURL.stopAccessingSecurityScopedResource()
            }
            if subtitlesAccess {
                subtitlesURL.stopAccessingSecurityScopedResource()
            }
            if outputAccess {
                outputURL.deletingLastPathComponent().stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        _ = try await runFFmpeg(
            executableURL: executableURL,
            arguments: [
                "-y",
                "-nostats",
                "-progress", "pipe:1",
                "-i", videoURL.path,
                "-vf", "ass=\(escapedSubtitleFilterPath(subtitlesURL.path))",
                "-c:v", "libx264",
                "-crf", "\(settings.quality.crf)",
                "-preset", settings.preset.rawValue,
                "-c:a", "copy",
                outputURL.path
            ],
            progressHandler: progressHandler
        )

        return outputURL
    }

    private func resolveExecutableURL() throws -> URL {
        let preferredPath = normalizePath(preferredExecutableURL.path)
        if FileManager.default.isExecutableFile(atPath: preferredPath) {
            return URL(fileURLWithPath: preferredPath)
        }

        let fallbackPaths = [
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        if let path = fallbackPaths.first(where: FileManager.default.isExecutableFile) {
            return URL(fileURLWithPath: path)
        }

        let pathEnvironment = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let executablePath = pathEnvironment
            .split(separator: ":")
            .map { String($0) }
            .map { URL(fileURLWithPath: $0).appendingPathComponent("ffmpeg").path }
            .first(where: FileManager.default.isExecutableFile)

        if let executablePath {
            return URL(fileURLWithPath: executablePath)
        }

        throw FFmpegServiceError.notFound
    }

    private func runFFmpeg(
        executableURL: URL,
        arguments: [String],
        progressHandler: FFmpegProgressHandler? = nil
    ) async throws -> FFmpegProcessResult {
        // Detached at .userInitiated: launches and waits out an external FFmpeg
        // process (can run for minutes on large exports) independent of the
        // caller's task priority/cancellation, so the process is always drained
        // and its continuation resumed rather than orphaned by a cancelled parent.
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments

            let standardOutput = Pipe()
            let standardError = Pipe()
            process.standardOutput = standardOutput
            process.standardError = standardError

            // Detached: `readOutput`/`readDataToEndOfFile()` below block their
            // thread until the pipe closes (i.e. until the process exits). Blocking
            // calls must not run on the cooperative thread pool, so each pump gets
            // its own dedicated thread via detachment rather than a structured
            // child task.
            let outputTask = Task.detached(priority: .utility) {
                await Self.readOutput(
                    from: standardOutput.fileHandleForReading,
                    progressHandler: progressHandler
                )
            }
            let errorTask = Task.detached(priority: .utility) {
                standardError.fileHandleForReading.readDataToEndOfFile()
            }

            return try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { process in
                    Task {
                        let outputData = await outputTask.value
                        let errorData = await errorTask.value
                        let output = String(data: outputData, encoding: .utf8) ?? ""
                        let error = String(data: errorData, encoding: .utf8) ?? ""

                        guard process.terminationStatus == 0 else {
                            continuation.resume(
                                throwing: FFmpegServiceError.processFailed(
                                    exitCode: process.terminationStatus,
                                    standardOutput: output,
                                    standardError: error
                                )
                            )
                            return
                        }

                        continuation.resume(
                            returning: FFmpegProcessResult(
                                standardOutput: output,
                                standardError: error
                            )
                        )
                    }
                }

                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    outputTask.cancel()
                    errorTask.cancel()
                    continuation.resume(
                        throwing: FFmpegServiceError.launchFailed(
                            executablePath: executableURL.path,
                            underlyingDescription: error.localizedDescription
                        )
                    )
                }
            }
        }.value
    }

    private static func readOutput(
        from handle: FileHandle,
        progressHandler: FFmpegProgressHandler?
    ) async -> Data {
        var output = Data()
        var progressBuffer = ""

        while !Task.isCancelled {
            let data = handle.availableData
            guard !data.isEmpty else {
                break
            }

            output.append(data)

            guard let progressHandler else {
                continue
            }

            let processedValues = FFmpegProgressParser.processedTimeValues(
                from: data,
                buffer: &progressBuffer
            )
            for processedTimeMs in processedValues {
                await progressHandler(processedTimeMs)
            }
        }

        return output
    }

    private func normalizePath(_ path: String) -> String {
        path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private func escapedSubtitleFilterPath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: ":", with: "\\:")
    }
}

struct FFmpegProcessResult: Equatable {
    var standardOutput: String
    var standardError: String
}

private enum FFmpegProgressParser {
    static func processedTimeValues(from data: Data, buffer: inout String) -> [Int] {
        guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
            return []
        }

        buffer.append(chunk)
        let lines = buffer.components(separatedBy: .newlines)
        buffer = lines.last ?? ""
        return lines.dropLast().compactMap(processedTimeMs(from:))
    }

    private static func processedTimeMs(from line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if let value = trimmed.value(after: "out_time_ms="),
           let microseconds = Int(value) {
            return max(0, microseconds / 1_000)
        }

        if let value = trimmed.value(after: "out_time=") {
            return parseTimestampMilliseconds(value)
        }

        return nil
    }

    private static func parseTimestampMilliseconds(_ value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard parts.count == 3,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return nil
        }

        let secondParts = parts[2].split(separator: ".", maxSplits: 1)
        guard let seconds = Int(secondParts[0]) else {
            return nil
        }

        let milliseconds: Int
        if secondParts.count == 2 {
            let fraction = String(secondParts[1].prefix(3))
            milliseconds = Int(fraction.padding(toLength: 3, withPad: "0", startingAt: 0)) ?? 0
        } else {
            milliseconds = 0
        }

        return ((hours * 60 + minutes) * 60 + seconds) * 1_000 + milliseconds
    }
}

private extension String {
    func value(after prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}

enum FFmpegServiceError: LocalizedError, CustomDebugStringConvertible {
    case notFound
    case launchFailed(executablePath: String, underlyingDescription: String)
    case processFailed(exitCode: Int32, standardOutput: String, standardError: String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "FFmpeg was not found. Install FFmpeg or set the correct path."
        case .launchFailed(_, let underlyingDescription):
            return "FFmpeg could not be launched: \(underlyingDescription)"
        case .processFailed(let exitCode, _, _):
            return "FFmpeg failed with exit code \(exitCode)."
        }
    }

    var debugDescription: String {
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
