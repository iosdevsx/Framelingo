import Foundation
import TranslationPipeline

enum TranslationPipelinePresentation {
    static func message(for error: Error) -> String {
        let localizedError = error as? LocalizedError
        return localizedError?.errorDescription ?? "Translation failed."
    }

    static func message(for error: TranslationPipelineError) -> String {
        error.errorDescription ?? "Translation failed."
    }
}
