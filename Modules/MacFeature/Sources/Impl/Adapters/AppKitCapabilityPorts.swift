import AppKit
import ExportFeature
import Foundation
import SubtitleEditorFeature
import UniformTypeIdentifiers

@MainActor
struct AppKitSubtitleDocumentPickerAdapter {
    typealias RunPanel = @MainActor ([UTType]) throws -> URL?

    private let runPanel: RunPanel

    init(runPanel: @escaping RunPanel = Self.runOpenPanel) {
        self.runPanel = runPanel
    }

    var port: SubtitleDocumentPicker {
        SubtitleDocumentPicker { request in
            let contentTypes = Self.contentTypes(for: request.allowedFileExtensions)
            guard !contentTypes.isEmpty else {
                return .failed(
                    SubtitleDocumentPickerFailure(message: "No supported subtitle document types were provided.")
                )
            }

            do {
                guard let url = try runPanel(contentTypes) else { return .cancelled }
                return .selected(url)
            } catch let error as LocalizedError {
                return .failed(
                    SubtitleDocumentPickerFailure(
                        message: error.errorDescription ?? "Could not open the subtitle document picker."
                    )
                )
            } catch {
                return .failed(
                    SubtitleDocumentPickerFailure(message: "Could not open the subtitle document picker.")
                )
            }
        }
    }

    static func contentTypes(for extensions: [String]) -> [UTType] {
        extensions.compactMap { UTType(filenameExtension: $0.lowercased()) }
    }

    private static func runOpenPanel(allowedContentTypes: [UTType]) throws -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Import Subtitles"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = allowedContentTypes
        return panel.runModal() == .OK ? panel.url : nil
    }
}

@MainActor
struct AppKitOutputRevealAdapter {
    private let fileExists: (String) -> Bool
    private let revealAction: (URL) throws -> Void

    init(
        fileExists: @escaping (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        reveal: @escaping (URL) throws -> Void = {
            NSWorkspace.shared.activateFileViewerSelecting([$0])
        }
    ) {
        self.fileExists = fileExists
        revealAction = reveal
    }

    var port: ExportOutputRevealing {
        ExportOutputRevealing { url in
            guard url.isFileURL, fileExists(url.path) else {
                return .failure(ExportPlatformFailure(message: "The exported file could not be found."))
            }

            do {
                try revealAction(url)
                return .success
            } catch {
                return .failure(ExportPlatformFailure(message: "Could not reveal the exported file in Finder."))
            }
        }
    }
}

@MainActor
struct AppKitDiagnosticCopyAdapter {
    private let copyAction: (String) throws -> Bool

    init(copy: @escaping (String) throws -> Bool = { value in
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(value, forType: .string)
    }) {
        copyAction = copy
    }

    var port: ExportDiagnosticCopying {
        ExportDiagnosticCopying { text in
            guard !text.isEmpty else {
                return .failure(ExportPlatformFailure(message: "There is no diagnostic text to copy."))
            }

            do {
                return try copyAction(text)
                    ? .success
                    : .failure(ExportPlatformFailure(message: "Could not copy diagnostics to the clipboard."))
            } catch {
                return .failure(ExportPlatformFailure(message: "Could not copy diagnostics to the clipboard."))
            }
        }
    }
}
