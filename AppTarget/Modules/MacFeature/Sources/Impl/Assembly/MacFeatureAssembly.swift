import AppUpdate
import AppUpdateImpl
import MacFeature
import SwiftUI

public enum MacFeatureAssembly {
    @MainActor
    public static func makeDefaultRootView() -> AnyView {
        makeRootView(dependencies: MacCompositionRoot.makeDependencies())
    }

    @MainActor
    public static func makeDefaultUpdateChecker(
        startingUpdater: Bool = true
    ) -> any AppUpdateChecking {
        AppUpdateAssembly.makeChecker(startingUpdater: startingUpdater)
    }

    @MainActor
    public static func makeRootView(
        dependencies: MacFeatureDependencies
    ) -> AnyView {
        AnyView(
            MainNavigationView(dependencies: dependencies)
                .environmentObject(dependencies.appState)
        )
    }

    @MainActor
    public static func makeCommands(
        updateChecker: any AppUpdateChecking
    ) -> some Commands {
        MacFeatureCommands(updateChecker: updateChecker)
    }

    @MainActor
    public static func makeDefaultCommands(
        startingUpdater: Bool = true
    ) -> some Commands {
        MacFeatureCommands(
            updateChecker: AppUpdateAssembly.makeChecker(
                startingUpdater: startingUpdater
            )
        )
    }
}
