import Foundation

struct ProjectFileService {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func exportProject(_ project: Project, to fileURL: URL) throws {
        let data = try encoder.encode(project)
        try data.write(to: fileURL, options: .atomic)
    }

    func importProject(from fileURL: URL) throws -> Project {
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(Project.self, from: data)
    }
}

enum ProjectFileError: LocalizedError {
    case videoFileMissing(String)

    var errorDescription: String? {
        switch self {
        case .videoFileMissing(let path):
            "Project opened, but the source video file was not found:\n\(path)"
        }
    }
}
