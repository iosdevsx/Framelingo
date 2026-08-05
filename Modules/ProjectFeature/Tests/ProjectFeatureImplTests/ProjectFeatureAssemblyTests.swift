import ProjectFeature
import SwiftUI
import XCTest

import ProjectFeatureImpl

@MainActor
final class ProjectFeatureAssemblyTests: XCTestCase {
    func testPublicAssemblyConstructsWorkspaceViewFromAPIContracts() {
        let appState = TestDoubles.appState(project: TestDoubles.project())
        var mode = ProjectWorkspaceMode.subtitles

        _ = ProjectFeatureAssembly.makeView(
            appState: appState,
            dependencies: TestDoubles.projectFeatureDependencies(appState: appState),
            projectMode: Binding(get: { mode }, set: { mode = $0 }),
            makeExportVideoViewModel: { _ in fatalError("The composition test does not present export UI") }
        )
    }
}
