import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        compatibleXcodeVersions: .exact("26.3"),
        generationOptions: .options(
            defaultConfiguration: "Debug",
            buildInsightsDisabled: true,
            testInsightsDisabled: true,
            enableCaching: false,
            defaultSwiftVersion: "5"
        )
    )
)
