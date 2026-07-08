import Foundation

enum SpeakerAnalysisStage: String, Equatable {
    case preparingAudio
    case downloadingModels
    case diarizingSpeakers
    case aligningSubtitles

    var displayName: String {
        switch self {
        case .preparingAudio:
            "Preparing audio..."
        case .downloadingModels:
            "Preparing speaker models..."
        case .diarizingSpeakers:
            "Analyzing speakers..."
        case .aligningSubtitles:
            "Aligning subtitles..."
        }
    }
}
