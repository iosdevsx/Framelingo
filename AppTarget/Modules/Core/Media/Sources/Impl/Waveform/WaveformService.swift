import Foundation
import Media

final class WaveformService: WaveformLoading {
    private let cacheVersion = 4
    private let appName: String
    private let cacheRootURL: URL?

    init(appName: String = "Framelingo", cacheRootURL: URL? = nil) {
        self.appName = appName
        self.cacheRootURL = cacheRootURL
    }

    func loadWaveform(
        for request: WaveformRequest,
        audioProvider: @escaping WaveformAudioProvider,
        progressHandler: WaveformProgressHandler?
    ) async throws -> [Double] {
        let cacheURL = waveformCacheURL(for: request.projectID)
        let signature = mediaSignature(for: request)

        await progressHandler?(0.08, "Checking waveform cache...")

        if let cached = try? cachedWaveform(at: cacheURL),
           cached.version == cacheVersion,
           cached.mediaPath == signature.path,
           cached.mediaSizeBytes == signature.sizeBytes,
           cached.mediaModificationTime == signature.modificationTime,
           cached.durationMs == (request.durationMs ?? 0),
           !cached.peaks.isEmpty {
            await progressHandler?(1.0, "Project ready")
            return cached.peaks
        }

        await progressHandler?(0.18, "Extracting audio for waveform...")
        let audioURL = try await audioProvider()

        await progressHandler?(0.72, "Analyzing audio waveform...")
        let peaks = try WaveformPeakAnalyzer.peaks(
            fromWAVFile: audioURL,
            targetPeakCount: targetPeakCount(for: request)
        )

        await progressHandler?(0.92, "Saving waveform cache...")
        let cache = WaveformCache(
            version: cacheVersion,
            mediaPath: signature.path,
            mediaSizeBytes: signature.sizeBytes,
            mediaModificationTime: signature.modificationTime,
            durationMs: request.durationMs ?? 0,
            peaks: peaks
        )
        try save(cache, to: cacheURL)

        await progressHandler?(1.0, "Project ready")
        return peaks
    }

    private func targetPeakCount(for request: WaveformRequest) -> Int {
        let durationMs = max(request.durationMs ?? request.fallbackContentEndMs ?? 0, 1)
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

    private func mediaSignature(
        for request: WaveformRequest
    ) -> (path: String, sizeBytes: Int64, modificationTime: TimeInterval?) {
        let url = request.mediaURL
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
            size?.int64Value ?? request.mediaSizeBytes,
            modificationDate?.timeIntervalSince1970
        )
    }

    private func waveformCacheURL(for projectID: UUID) -> URL {
        projectDirectory(for: projectID).appendingPathComponent("waveform.json")
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
