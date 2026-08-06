public protocol WaveformLoading {
    func loadWaveform(
        for request: WaveformRequest,
        audioProvider: @escaping WaveformAudioProvider,
        progressHandler: WaveformProgressHandler?
    ) async throws -> [Double]
}

public extension WaveformLoading {
    func loadWaveform(
        for request: WaveformRequest,
        audioProvider: @escaping WaveformAudioProvider
    ) async throws -> [Double] {
        try await loadWaveform(
            for: request,
            audioProvider: audioProvider,
            progressHandler: nil
        )
    }
}
