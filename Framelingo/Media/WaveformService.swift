import Foundation

typealias WaveformProgressHandler = @Sendable (_ progress: Double, _ status: String) async -> Void

struct WaveformCache: Codable, Equatable, Sendable {
    var version: Int
    var mediaPath: String
    var mediaSizeBytes: Int64
    var mediaModificationTime: TimeInterval?
    var durationMs: Int
    var peaks: [Double]
}

final class WaveformService {
    private let cacheVersion = 4
    private let appName: String
    private let cacheRootURL: URL?

    init(appName: String = "Framelingo", cacheRootURL: URL? = nil) {
        self.appName = appName
        self.cacheRootURL = cacheRootURL
    }

    func loadWaveform(
        for project: Project,
        ffmpegService: FFmpegService,
        progressHandler: WaveformProgressHandler? = nil
    ) async throws -> [Double] {
        let cacheURL = waveformCacheURL(for: project.id)
        let signature = mediaSignature(for: project)

        await progressHandler?(0.08, "Checking waveform cache...")

        if let cached = try? cachedWaveform(at: cacheURL),
           cached.version == cacheVersion,
           cached.mediaPath == signature.path,
           cached.mediaSizeBytes == signature.sizeBytes,
           cached.mediaModificationTime == signature.modificationTime,
           cached.durationMs == (project.mediaFile.durationMs ?? 0),
           !cached.peaks.isEmpty {
            await progressHandler?(1.0, "Project ready")
            return cached.peaks
        }

        let audioURL = temporaryAudioURL(for: project.id)
        defer {
            try? FileManager.default.removeItem(at: audioURL)
        }

        try FileManager.default.createDirectory(
            at: audioURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        await progressHandler?(0.18, "Extracting audio for waveform...")
        _ = try await ffmpegService.extractAudio(
            from: project.mediaFile.originalURL,
            to: audioURL
        )

        await progressHandler?(0.72, "Analyzing audio waveform...")
        let targetPeakCount = targetPeakCount(for: project)
        let peaks = try WaveformPeakAnalyzer.peaks(
            fromWAVFile: audioURL,
            targetPeakCount: targetPeakCount
        )

        await progressHandler?(0.92, "Saving waveform cache...")
        let cache = WaveformCache(
            version: cacheVersion,
            mediaPath: signature.path,
            mediaSizeBytes: signature.sizeBytes,
            mediaModificationTime: signature.modificationTime,
            durationMs: project.mediaFile.durationMs ?? 0,
            peaks: peaks
        )
        try save(cache, to: cacheURL)

        await progressHandler?(1.0, "Project ready")
        return peaks
    }

    private func targetPeakCount(for project: Project) -> Int {
        let durationMs = max(project.mediaFile.durationMs ?? project.subtitles.map(\.endMs).max() ?? 0, 1)
        let peaksPerSecond = 90
        return min(18_000, max(1_000, durationMs * peaksPerSecond / 1_000))
    }

    private func cachedWaveform(at url: URL) throws -> WaveformCache {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WaveformCache.self, from: data)
    }

    private func save(_ cache: WaveformCache, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(cache)
        try data.write(to: url, options: .atomic)
    }

    private func mediaSignature(for project: Project) -> (path: String, sizeBytes: Int64, modificationTime: TimeInterval?) {
        let url = project.mediaFile.originalURL
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes?[.size] as? NSNumber
        let modificationDate = attributes?[.modificationDate] as? Date

        return (
            url.path,
            size?.int64Value ?? project.mediaFile.sizeBytes,
            modificationDate?.timeIntervalSince1970
        )
    }

    private func waveformCacheURL(for projectID: UUID) -> URL {
        projectDirectory(for: projectID)
            .appendingPathComponent("waveform.json")
    }

    private func temporaryAudioURL(for projectID: UUID) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("waveform-\(UUID().uuidString).wav")
    }

    private func projectDirectory(for projectID: UUID) -> URL {
        let applicationSupportURL = cacheRootURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return applicationSupportURL
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
    }
}

private enum WaveformPeakAnalyzer {
    static func peaks(fromWAVFile url: URL, targetPeakCount: Int) throws -> [Double] {
        let data = try Data(contentsOf: url)
        let wav = try wavPCMData(in: data)
        let bytesPerSample = wav.bitsPerSample / 8
        let bytesPerFrame = bytesPerSample * wav.channelCount
        let frameCount = wav.audioData.count / bytesPerFrame
        guard frameCount > 0 else {
            throw WaveformServiceError.emptyAudio
        }

        let peakCount = min(max(targetPeakCount, 1), frameCount)
        let framesPerPeak = max(1, frameCount / peakCount)
        var peaks: [Double] = []
        peaks.reserveCapacity(peakCount)

        var frameIndex = 0
        while frameIndex < frameCount {
            let endIndex = min(frameIndex + framesPerPeak, frameCount)
            var maxAmplitude: Int32 = 0

            var index = frameIndex
            while index < endIndex {
                let frameOffset = wav.audioData.startIndex + index * bytesPerFrame
                for channel in 0..<wav.channelCount {
                    let byteOffset = frameOffset + channel * bytesPerSample
                    let raw = int16(in: wav.audioData, offset: byteOffset)
                    maxAmplitude = max(maxAmplitude, Int32(abs(Int(raw))))
                }
                index += 1
            }

            peaks.append(min(1.0, Double(maxAmplitude) / 32_768.0))
            frameIndex = endIndex
        }

        return peaks
    }

    private static func wavPCMData(in data: Data) throws -> WAVPCMData {
        guard data.count >= 12,
              asciiString(in: data, offset: 0, length: 4) == "RIFF",
              asciiString(in: data, offset: 8, length: 4) == "WAVE" else {
            throw WaveformServiceError.unsupportedAudio
        }

        var offset = 12
        var format: WAVFormat?
        var audioData: Data?

        while offset + 8 <= data.count {
            let chunkID = asciiString(in: data, offset: offset, length: 4)
            let chunkSize = Int(littleEndianUInt32(in: data, offset: offset + 4))
            let dataOffset = offset + 8
            let chunkEnd = dataOffset + chunkSize

            guard chunkEnd <= data.count else {
                throw WaveformServiceError.unsupportedAudio
            }

            if chunkID == "fmt " {
                format = try wavFormat(in: data, offset: dataOffset, size: chunkSize)
            } else if chunkID == "data" {
                audioData = data.subdata(in: dataOffset..<chunkEnd)
            }

            offset = chunkEnd + (chunkSize % 2)
        }

        guard let format,
              format.audioFormat == 1,
              format.bitsPerSample == 16,
              format.channelCount > 0 else {
            throw WaveformServiceError.unsupportedAudio
        }

        guard let audioData, !audioData.isEmpty else {
            throw WaveformServiceError.emptyAudio
        }

        return WAVPCMData(
            audioData: audioData,
            channelCount: format.channelCount,
            bitsPerSample: format.bitsPerSample
        )
    }

    private static func wavFormat(in data: Data, offset: Int, size: Int) throws -> WAVFormat {
        guard size >= 16, offset + 16 <= data.count else {
            throw WaveformServiceError.unsupportedAudio
        }

        return WAVFormat(
            audioFormat: Int(littleEndianUInt16(in: data, offset: offset)),
            channelCount: Int(littleEndianUInt16(in: data, offset: offset + 2)),
            bitsPerSample: Int(littleEndianUInt16(in: data, offset: offset + 14))
        )
    }

    private static func int16(in data: Data, offset: Int) -> Int16 {
        let low = UInt16(data[offset])
        let high = UInt16(data[offset + 1])
        return Int16(bitPattern: high << 8 | low)
    }

    private static func littleEndianUInt16(in data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset])
            | UInt16(data[offset + 1]) << 8
    }

    private static func littleEndianUInt32(in data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func asciiString(in data: Data, offset: Int, length: Int) -> String {
        guard offset + length <= data.count else {
            return ""
        }

        return String(data: data.subdata(in: offset..<(offset + length)), encoding: .ascii) ?? ""
    }
}

private struct WAVPCMData {
    var audioData: Data
    var channelCount: Int
    var bitsPerSample: Int
}

private struct WAVFormat {
    var audioFormat: Int
    var channelCount: Int
    var bitsPerSample: Int
}

enum WaveformServiceError: LocalizedError {
    case emptyAudio
    case unsupportedAudio

    var errorDescription: String? {
        switch self {
        case .emptyAudio:
            return "Audio waveform could not be generated because the audio track is empty."
        case .unsupportedAudio:
            return "Audio waveform could not be generated from the extracted audio format."
        }
    }
}
