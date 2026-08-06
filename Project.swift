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
    packages: FramelingoPackages.localModules,
    settings: FramelingoSettings.project,
    targets: [
        FramelingoTargets.macOSApplication(),
        FramelingoTargets.macOSTests(),
    ],
    schemes: [
        FramelingoSchemes.macOS(
            testPlan: .relativeToRoot("Tuist/TestPlans/FramelingoComplete.xctestplan")
        ),
    ],
    additionalFiles: [
        "README.md",
        "docs/**",
        "AppTarget/Modules/*/*/Package.swift",
        "AppTarget/Modules/*/*/Package.resolved",
        "AppTarget/Modules/*/*/README.md",
        "AppTarget/Modules/*/*/Sources/**",
        "AppTarget/Modules/*/*/Tests/**",
        "TestPlan.xctestplan",
        "Tuist/**",
    ]
)
