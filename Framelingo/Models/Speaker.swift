import SwiftUI

struct Speaker: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var colorHex: String

    var color: Color { Color(hex: colorHex) ?? Color.gray }

    static let defaults: [Speaker] = [
        Speaker(id: "speaker_1", name: "Speaker 1", colorHex: "#0a84ff"),
        Speaker(id: "speaker_2", name: "Speaker 2", colorHex: "#bf5af2"),
        Speaker(id: "speaker_3", name: "Speaker 3", colorHex: "#30d158"),
        Speaker(id: "speaker_4", name: "Speaker 4", colorHex: "#ff9f0a"),
    ]
}
