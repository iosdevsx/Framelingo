public struct SpeechModelDownloadProgress: Equatable, Sendable {
    public var fractionCompleted: Double?
    public var status: String

    public init(fractionCompleted: Double?, status: String) {
        self.fractionCompleted = fractionCompleted
        self.status = status
    }
}
