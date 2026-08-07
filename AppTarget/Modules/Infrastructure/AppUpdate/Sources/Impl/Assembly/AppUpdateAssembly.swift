import AppUpdate

@MainActor
public enum AppUpdateAssembly {
    public static func makeChecker(startingUpdater: Bool = true) -> any AppUpdateChecking {
        SparkleAppUpdateChecker(startingUpdater: startingUpdater)
    }
}
