public struct SubtitleWarning: Equatable {
    public enum Kind: Equatable { case warn, bad }
    public let kind: Kind
    public let message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }
}
