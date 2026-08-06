public struct Speaker: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var colorHex: String

    public init(id: String, name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    public static let defaults: [Speaker] = [
        Speaker(id: "speaker_1", name: "Speaker 1", colorHex: "#0a84ff"),
        Speaker(id: "speaker_2", name: "Speaker 2", colorHex: "#bf5af2"),
        Speaker(id: "speaker_3", name: "Speaker 3", colorHex: "#30d158"),
        Speaker(id: "speaker_4", name: "Speaker 4", colorHex: "#ff9f0a"),
    ]
}
