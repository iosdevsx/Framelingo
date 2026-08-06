import Combine
import ExportFeature
import XCTest

@MainActor
final class ExportPlatformAndActivityContractTests: XCTestCase {
    func testRevealAndCopyPortsForwardSemanticValuesAndExplicitResults() {
        let url = URL(fileURLWithPath: "/tmp/output.mp4")
        var revealedURL: URL?
        var copiedText: String?
        let reveal = ExportOutputRevealing {
            revealedURL = $0
            return .success
        }
        let copy = ExportDiagnosticCopying {
            copiedText = $0
            return .failure(ExportPlatformFailure(message: "Clipboard unavailable"))
        }

        XCTAssertEqual(reveal.reveal(url), .success)
        XCTAssertEqual(revealedURL, url)
        XCTAssertEqual(
            copy.copy("debug"),
            .failure(ExportPlatformFailure(message: "Clipboard unavailable"))
        )
        XCTAssertEqual(copiedText, "debug")
    }

    func testActivitySourcePublishesProgressAndRoutesDismissToOwner() {
        let initial = ProductActivitySnapshot(items: [])
        let subject = CurrentValueSubject<ProductActivitySnapshot, Never>(initial)
        var dismissedID: String?
        let source = ProductActivitySource(
            snapshot: { subject.value },
            snapshots: { subject.eraseToAnyPublisher() },
            dismiss: { dismissedID = $0 }
        )
        var received = initial
        let subscription = source.snapshots.sink { received = $0 }
        let item = ProductActivityItem(
            id: "export-1",
            title: "Demo",
            subtitle: "Exporting",
            progress: 0.5,
            status: .running,
            canDismiss: false
        )

        subject.send(ProductActivitySnapshot(items: [item]))
        source.dismiss(id: item.id)

        XCTAssertEqual(received.items.first?.progress, 0.5)
        XCTAssertEqual(dismissedID, item.id)
        _ = subscription
    }
}
