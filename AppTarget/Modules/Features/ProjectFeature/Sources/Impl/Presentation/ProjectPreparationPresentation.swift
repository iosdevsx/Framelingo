import ProjectPreparation

enum ProjectPreparationPresentation {
    static func status(for progress: ProjectPreparationProgress) -> String {
        if let detail = progress.providerDetail, !detail.isEmpty {
            return detail
        }
        return switch progress.phase {
        case .readingSourceMetadata:
            "Preparing project..."
        case .readingDuration:
            "Reading video duration..."
        case .preparingWaveform:
            "Preparing waveform..."
        }
    }

    static func status(for outcome: ProjectPreparationOutcome) -> String {
        switch outcome {
        case .ready:
            "Project ready"
        case .degraded(.waveformUnavailable):
            "Project ready. Waveform unavailable."
        case .degraded(.waveformUnavailableAndCleanupFailed):
            "Project ready. Waveform unavailable; temporary audio cleanup failed."
        }
    }
}
