public enum SpeechModelStatus: Equatable, Sendable {
    case notInstalled
    case downloading(progress: Double?)
    case installed
    case failed(message: String)
}
