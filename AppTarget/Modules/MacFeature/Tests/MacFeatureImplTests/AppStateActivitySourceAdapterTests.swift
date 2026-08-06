import Combine
import XCTest

@testable import MacFeatureImpl

@MainActor
final class AppStateActivitySourceAdapterTests: XCTestCase {
    func testProgressFlowsFromCanonicalOwnerAndDismissRoutesBack() {
        let dependencies = MacCompositionRoot.makeDependencies()
        let appState = dependencies.appState
        let source = AppStateActivitySourceAdapter(appState: appState).source
        var snapshots = [source.snapshot]
        let subscription = source.snapshots.sink { snapshots.append($0) }

        appState.startTranscriptionActivity(projectName: "Demo")
        appState.updateTranscriptionActivity(statusText: "Transcribing", progress: 0.5)

        let item = snapshots.last?.items.first
        XCTAssertEqual(item?.title, "Demo")
        XCTAssertEqual(item?.progress, 0.5)

        if let id = item?.id {
            appState.finishTranscriptionActivity(success: true)
            source.dismiss(id: id)
        }
        XCTAssertNil(appState.transcriptionActivity)
        _ = subscription
    }
}
