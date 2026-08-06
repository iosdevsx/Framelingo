import Foundation

public struct MediaFile: Identifiable, Codable, Equatable {
    public let id: UUID
    public var originalURL: URL
    public var fileName: String
    public var fileExtension: String
    public var sizeBytes: Int64
    public var durationMs: Int?

    public var readableSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case originalURL
        case fileName
        case fileExtension
        case sizeBytes
        case durationMs
    }

    public init(
        id: UUID,
        originalURL: URL,
        fileName: String,
        fileExtension: String,
        sizeBytes: Int64,
        durationMs: Int?
    ) {
        self.id = id
        self.originalURL = originalURL
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.sizeBytes = sizeBytes
        self.durationMs = durationMs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        fileExtension = try container.decode(String.self, forKey: .fileExtension)
        sizeBytes = try container.decode(Int64.self, forKey: .sizeBytes)
        durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)

        let urlString = try container.decode(String.self, forKey: .originalURL)
        if let url = URL(string: urlString) {
            originalURL = url
        } else {
            originalURL = URL(fileURLWithPath: urlString)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(originalURL.absoluteString, forKey: .originalURL)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(fileExtension, forKey: .fileExtension)
        try container.encode(sizeBytes, forKey: .sizeBytes)
        try container.encodeIfPresent(durationMs, forKey: .durationMs)
    }
}
