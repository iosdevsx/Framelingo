import ProjectDescription

public enum FramelingoSchemes {
    public static func macOS(testPlan: TestPlan? = nil) -> Scheme {
        let testAction = testPlan.map {
            TestAction.testPlans([$0], configuration: "Debug")
        } ?? TestAction.targets(
            [.testableTarget(target: .target(FramelingoTargets.testName))],
            configuration: "Debug"
        )

        return .scheme(
            name: "Framelingo-Tuist",
            shared: true,
            buildAction: .buildAction(targets: [.target(FramelingoTargets.applicationName)]),
            testAction: testAction,
            runAction: .runAction(
                configuration: "Debug",
                executable: .executable(.target(FramelingoTargets.applicationName))
            ),
            archiveAction: .archiveAction(
                configuration: "Release",
                revealArchiveInOrganizer: false,
                customArchiveName: "Framelingo"
            ),
            profileAction: .profileAction(
                configuration: "Release",
                executable: .executable(.target(FramelingoTargets.applicationName))
            ),
            analyzeAction: .analyzeAction(configuration: "Debug")
        )
    }
}
