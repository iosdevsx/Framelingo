import ExportFeature
import PlayerFeature
import ProjectFeature
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
                appState: appState,
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
            appState: appState,
            dependencies: TestDoubles.projectFeatureDependencies(appState: appState),
            projectMode: Binding(get: { mode }, set: { mode = $0 }),
            components: TestDoubles.projectFeatureComponents()
        )
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
}
