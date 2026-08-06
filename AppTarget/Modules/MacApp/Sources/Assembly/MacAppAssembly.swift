import AppUpdate
import SwiftUI

/// Minimal public entry surface for the macOS executable.
public enum MacAppAssembly {
    @MainActor
    public static func makeRootView() -> AnyView {
        MacAppComposition.makeProductionRootView()
    }

    @MainActor
    public static func makeUpdateChecker(
        startingUpdater: Bool = true
    ) -> any AppUpdateChecking {
        MacAppComposition.makeUpdateChecker(startingUpdater: startingUpdater)
    }

    @MainActor
    public static func makeCommands(
        updateChecker: any AppUpdateChecking
    ) -> some Commands {
        MacAppCommands(updateChecker: updateChecker)
    }

    @MainActor
    public static func makeDefaultCommands(
        startingUpdater: Bool = true
    ) -> some Commands {
        MacAppCommands(
            updateChecker: makeUpdateChecker(startingUpdater: startingUpdater)
        )
    }
}
