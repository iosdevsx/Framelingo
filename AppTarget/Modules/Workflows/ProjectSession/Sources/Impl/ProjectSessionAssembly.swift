import ProjectSession

public enum ProjectSessionAssembly {
    @MainActor
    public static func makeSession(
        dependencies: ProjectSessionDependencies
    ) -> any ProjectSession {
        DefaultProjectSession(dependencies: dependencies)
    }
}
