import Foundation

enum IOSDocumentSelectionOutcome {
    case selected(URL)
    case cancelled
    case failed(any Error)
}

enum IOSDocumentPickerAdapter {
    static func outcome(
        from result: Result<[URL], any Error>
    ) -> IOSDocumentSelectionOutcome {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return .cancelled }
            return .selected(url)
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain,
               nsError.code == NSUserCancelledError {
                return .cancelled
            }
            return .failed(error)
        }
    }
}
