import SpeakerAnalysis

public enum SpeakerAnalysisAssembly {
    public static func makeMockDiarizationEngine()
        -> any SpeakerDiarizationEngine {
        MockSpeakerDiarizationEngine()
    }

    public static func makeFluidAudioDiarizationEngine(
        progressHandler: DiarizationProgressHandler? = nil
    ) -> any SpeakerDiarizationEngine {
        FluidAudioSpeakerDiarizationEngine(
            progressHandler: progressHandler
        )
    }

    public static func makePassthroughAlignmentEngine()
        -> any SubtitleAlignmentEngine {
        PassthroughSubtitleAlignmentEngine()
    }

    public static func makeCueLevelAlignmentEngine()
        -> any SubtitleAlignmentEngine {
        CueLevelSubtitleAlignmentEngine()
    }

    public static func makeWordLevelAlignmentEngine()
        -> any SubtitleAlignmentEngine {
        WordLevelSubtitleAlignmentEngine()
    }
}
