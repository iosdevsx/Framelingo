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

    public static func iOS() -> Scheme {
        .scheme(
            name: "Framelingo-iOS",
            shared: true,
            buildAction: .buildAction(targets: [.target(FramelingoTargets.iOSApplicationName)]),
            runAction: .runAction(
                configuration: "Debug",
                executable: .executable(.target(FramelingoTargets.iOSApplicationName))
            ),
            archiveAction: .archiveAction(
                configuration: "Release",
                revealArchiveInOrganizer: false,
                customArchiveName: "Framelingo-iOS"
            ),
            profileAction: .profileAction(
                configuration: "Release",
                executable: .executable(.target(FramelingoTargets.iOSApplicationName))
            ),
            analyzeAction: .analyzeAction(configuration: "Debug")
        )
    }
}
