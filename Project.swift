import ProjectDescription
import ProjectDescriptionHelpers

FramelingoManifestAssertions.validateFoundation()

let project = Project(
    name: "Framelingo-Tuist",
    organizationName: "Framelingo",
    options: .options(
        automaticSchemesOptions: .disabled,
        developmentRegion: "en",
        disableShowEnvironmentVarsInScriptPhases: true,
        xcodeProjectName: "Framelingo-Tuist"
    ),
    settings: FramelingoSettings.project,
    targets: [
        FramelingoTargets.macOSApplication(),
        FramelingoTargets.macOSTests(),
        FramelingoTargets.iOSApplication(),
    ],
    schemes: [
        FramelingoSchemes.macOS(
            testPlan: .relativeToRoot("Tuist/TestPlans/FramelingoComplete.xctestplan")
        ),
        FramelingoSchemes.iOS(),
    ],
    additionalFiles: [
        "README.md",
        "docs/**",
        "TestPlan.xctestplan",
        "Tuist/**",
    ],
    resourceSynthesizers: []
)
