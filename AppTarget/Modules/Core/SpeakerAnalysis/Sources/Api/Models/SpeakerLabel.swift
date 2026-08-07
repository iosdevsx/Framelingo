public struct SpeakerLabel: Identifiable, Codable, Hashable {
    public let id: Int
    public var displayName: String

    public init(id: Int, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}
