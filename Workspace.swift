import ProjectDescription

let workspace = Workspace(
    name: "Framelingo-Tuist",
    projects: ["."],
    additionalFiles: [
        ".mise.toml",
        ".xcode-version",
        "Tuist.swift",
    ]
)
