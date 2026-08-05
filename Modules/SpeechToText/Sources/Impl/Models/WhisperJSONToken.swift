struct WhisperJSONToken: Decodable {
    let text: String
    let offsets: WhisperJSONOffsets
    let p: Double?

    enum CodingKeys: String, CodingKey {
        case text, offsets, p
    }
}
