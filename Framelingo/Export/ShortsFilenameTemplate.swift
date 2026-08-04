import Foundation

/// Expands the shorts filename template (`{project}`, `{index}`, `{title}`)
/// into a filesystem-safe base name, and resolves collisions in a destination
/// directory by numeric suffixing.
enum ShortsFilenameTemplate {
    static func baseName(
        template: String,
        projectName: String,
        index: Int,
        totalCount: Int,
        shortTitle: String
    ) -> String {
        let paddingWidth = max(2, String(max(1, totalCount)).count)
        let paddedIndex = String(format: "%0\(paddingWidth)d", index)
        let expanded = template
            .replacingOccurrences(of: "{project}", with: projectName)
            .replacingOccurrences(of: "{index}", with: paddedIndex)
            .replacingOccurrences(of: "{title}", with: shortTitle)

        let sanitized = sanitized(expanded)
        return sanitized.isEmpty ? "Short \(paddedIndex)" : sanitized
    }

    /// Removes path separators and characters that are illegal or fragile in
    /// filenames across macOS and common upload targets.
    static func sanitized(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>\0")
        let cleaned = name
            .components(separatedBy: illegal)
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Leading dots hide the file in Finder.
        return String(cleaned.drop(while: { $0 == "." })).prefix(200).description
    }

    /// Returns a URL in `directory` for `baseName` + `fileExtension` that does
    /// not collide with an existing file or a reserved path (outputs of jobs
    /// queued in the same batch), appending " 2", " 3", … when needed.
    static func availableURL(
        in directory: URL,
        baseName: String,
        fileExtension: String,
        reservedPaths: Set<String> = [],
        fileManager: FileManager = .default
    ) -> URL {
        func url(for name: String) -> URL {
            directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
        }

        var candidate = url(for: baseName)
        var attempt = 2
        while fileManager.fileExists(atPath: candidate.path) || reservedPaths.contains(candidate.path) {
            candidate = url(for: "\(baseName) \(attempt)")
            attempt += 1
        }

        return candidate
    }
}
