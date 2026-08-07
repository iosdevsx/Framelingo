import AppKit
import ExportFeature
import PlayerFeature
import ProjectFeature
import Shorts
import ShortsFeature
import SubtitleEditorFeature
import SwiftUI
import Timeline
import TimelineFeature
import XCTest

import ProjectFeatureImpl

@MainActor
final class ProjectFeatureAssemblyTests: XCTestCase {
    func testWorkspaceModesRequestTheirExpectedCapabilitySurfaces() async throws {
        var project = TestDoubles.project()
        project.editTimeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 10_000,
                    timelineStartMs: 0,
                    timelineEndMs: 10_000
                )
            ],
            totalDurationMs: 10_000
        )
        let expectations: [ProjectWorkspaceMode: Set<String>] = [
            .subtitles: ["player", "subtitleTimeline", "cueList", "editorPane"],
            .edit: ["player", "editTimeline"],
            .shorts: ["shorts", "subtitleTimeline"],
        ]

        for mode in ProjectWorkspaceMode.allCases {
            let appState = TestDoubles.appState(project: project)
            var requestedSurfaces: Set<String> = []
            var selectedMode = mode
            let view = ProjectFeatureAssembly.makeView(
                dependencies: TestDoubles.projectFeatureDependencies(appState: appState),
                projectMode: Binding(
                    get: { selectedMode },
                    set: { selectedMode = $0 }
                ),
                components: recordingComponents { requestedSurfaces.insert($0) }
            )
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(width: 1_200, height: 800)

            _ = renderer.nsImage
            try await Task.sleep(for: .milliseconds(120))
            _ = renderer.nsImage

            XCTAssertEqual(requestedSurfaces, expectations[mode], "Unexpected surfaces for \(mode)")
        }
    }

    func testPublicAssemblyConstructsWorkspaceViewFromAPIContracts() {
        let appState = TestDoubles.appState(project: TestDoubles.project())
        var mode = ProjectWorkspaceMode.subtitles

        _ = ProjectFeatureAssembly.makeView(
            dependencies: TestDoubles.projectFeatureDependencies(appState: appState),
            projectMode: Binding(get: { mode }, set: { mode = $0 }),
            components: TestDoubles.projectFeatureComponents()
        )
    }

    func testShortsActionsAfterParentRerenderMutatePreservedPresentationModel() async throws {
        let short = ShortDefinition(title: "Selected", startMs: 1_000, endMs: 4_000)
        var project = TestDoubles.project()
        project.shorts = [short]

        let appState = TestDoubles.appState(project: project)
        let dependencies = TestDoubles.projectFeatureDependencies(appState: appState)
        let trigger = AssemblyRenderTrigger()
        let probe = ShortsWorkspaceProbe()
        let baseComponents = TestDoubles.projectFeatureComponents()
        let components = ProjectFeatureComponents(
            player: baseComponents.player,
            timeline: baseComponents.timeline,
            subtitleEditor: baseComponents.subtitleEditor,
            shorts: ShortsFeatureFactory { request in
                probe.capture(request)
                return AnyView(EmptyView())
            },
            export: baseComponents.export
        )
        let host = NSHostingView(
            rootView: AssemblyRerenderHost(
                appState: appState,
                dependencies: dependencies,
                components: components,
                trigger: trigger
            )
        )
        host.frame = NSRect(x: 0, y: 0, width: 1_200, height: 800)
        host.layoutSubtreeIfNeeded()

        try await waitUntil { probe.captureCount > 0 }
        let initialCaptureCount = probe.captureCount

        trigger.revision += 1
        host.layoutSubtreeIfNeeded()
        try await waitUntil { probe.captureCount > initialCaptureCount }

        let actions = try XCTUnwrap(probe.actions)
        actions.selectShort(id: short.id)
        host.layoutSubtreeIfNeeded()
        try await waitUntil { probe.state?.selectedShortID == short.id }

        withExtendedLifetime(host) {}
    }

    private func recordingComponents(
        record: @escaping @MainActor (String) -> Void
    ) -> ProjectFeatureComponents {
        ProjectFeatureComponents(
            player: PlayerFeatureFactory { _ in
                record("player")
                return AnyView(EmptyView())
            },
            timeline: TimelineFeatureFactory(
                makeSubtitleTimeline: { _ in
                    record("subtitleTimeline")
                    return AnyView(EmptyView())
                },
                makeEditTimeline: { _ in
                    record("editTimeline")
                    return AnyView(EmptyView())
                }
            ),
            subtitleEditor: SubtitleEditorFeatureFactory(
                makeCueList: { _ in
                    record("cueList")
                    return AnyView(EmptyView())
                },
                makeEditorPane: { _ in
                    record("editorPane")
                    return AnyView(EmptyView())
                },
                makeSubtitleEditor: { _ in
                    record("subtitleEditor")
                    return AnyView(EmptyView())
                },
                makeImportPreview: { _ in
                    record("importPreview")
                    return AnyView(EmptyView())
                }
            ),
            shorts: ShortsFeatureFactory { _ in
                record("shorts")
                return AnyView(EmptyView())
            },
            export: ExportFeatureFactory(
                makeVideoSheet: { _ in
                    record("videoExport")
                    return AnyView(EmptyView())
                },
                makeSubtitleOptionsSheet: { _ in
                    record("subtitleExport")
                    return AnyView(EmptyView())
                }
            )
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<50 {
            if condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Timed out waiting for the SwiftUI state update")
    }
}

@MainActor
private final class AssemblyRenderTrigger: ObservableObject {
    @Published var revision = 0
}

@MainActor
private final class ShortsWorkspaceProbe {
    private(set) var captureCount = 0
    private(set) var state: ShortsWorkspaceState?
    private(set) var actions: ShortsWorkspaceActions?

    func capture(_ request: ShortsWorkspaceRequest) {
        captureCount += 1
        state = request.state
        actions = request.actions
    }
}

@MainActor
private struct AssemblyRerenderHost: View {
    let appState: TestDoubles.Context
    let dependencies: ProjectFeatureDependencies
    let components: ProjectFeatureComponents
    @ObservedObject var trigger: AssemblyRenderTrigger
    @State private var mode = ProjectWorkspaceMode.shorts

    var body: some View {
        let _ = trigger.revision
        ProjectFeatureAssembly.makeView(
            dependencies: dependencies,
            projectMode: $mode,
            components: components
        )
    }
}
