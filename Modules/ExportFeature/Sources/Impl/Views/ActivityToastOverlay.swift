import Combine
import DesignSystem
import ExportFeature
import SwiftUI

@MainActor
private final class ActivityToastViewModel: ObservableObject {
    @Published private(set) var snapshot: ProductActivitySnapshot
    @Published var platformErrorMessage: String?

    private let source: ProductActivitySource
    private let outputRevealer: ExportOutputRevealing
    private let diagnosticCopier: ExportDiagnosticCopying
    private var subscription: AnyCancellable?

    init(
        source: ProductActivitySource,
        outputRevealer: ExportOutputRevealing,
        diagnosticCopier: ExportDiagnosticCopying
    ) {
        self.source = source
        self.outputRevealer = outputRevealer
        self.diagnosticCopier = diagnosticCopier
        snapshot = source.snapshot
        subscription = source.snapshots.sink { [weak self] snapshot in
            self?.snapshot = snapshot
        }
    }

    func reveal(_ url: URL) {
        if case .failure(let failure) = outputRevealer.reveal(url) {
            platformErrorMessage = failure.message
        }
    }

    func copy(_ text: String) {
        if case .failure(let failure) = diagnosticCopier.copy(text) {
            platformErrorMessage = failure.message
        }
    }

    func dismiss(_ id: String) {
        source.dismiss(id: id)
    }
}

struct ActivityToastOverlay: View {
    @StateObject private var viewModel: ActivityToastViewModel

    init(
        source: ProductActivitySource,
        outputRevealer: ExportOutputRevealing,
        diagnosticCopier: ExportDiagnosticCopying
    ) {
        _viewModel = StateObject(
            wrappedValue: ActivityToastViewModel(
                source: source,
                outputRevealer: outputRevealer,
                diagnosticCopier: diagnosticCopier
            )
        )
    }

    var body: some View {
        ProgressToastStack(items: toastItems)
            .alert(
                "Platform Operation Failed",
                isPresented: Binding(
                    get: { viewModel.platformErrorMessage != nil },
                    set: { if !$0 { viewModel.platformErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.platformErrorMessage ?? "")
            }
    }

    private var toastItems: [ProgressToastItem] {
        viewModel.snapshot.items.prefix(4).map(toastItem)
    }

    private func toastItem(_ item: ProductActivityItem) -> ProgressToastItem {
        var actions: [ProgressToastAction] = []

        if let outputURL = item.outputURL {
            actions.append(
                ProgressToastAction(title: "Reveal in Finder") {
                    viewModel.reveal(outputURL)
                }
            )
        }

        if let diagnosticText = item.diagnosticText {
            actions.append(
                ProgressToastAction(title: "Copy Debug") {
                    viewModel.copy(diagnosticText)
                }
            )
        }

        return ProgressToastItem(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle,
            detail: item.detail,
            progress: item.progress,
            status: item.status.progressToastStatus,
            errorMessage: item.errorMessage,
            actions: actions,
            onDismiss: item.canDismiss ? { viewModel.dismiss(item.id) } : nil
        )
    }
}

private extension ProductActivityStatus {
    var progressToastStatus: ProgressToastStatus {
        switch self {
        case .running: .running
        case .succeeded: .succeeded
        case .failed: .failed
        }
    }
}
