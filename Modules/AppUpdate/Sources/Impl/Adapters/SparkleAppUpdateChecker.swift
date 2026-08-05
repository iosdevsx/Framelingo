import AppUpdate
import Sparkle

@MainActor
final class SparkleAppUpdateChecker: AppUpdateChecking {
    private let updaterController: SPUStandardUpdaterController

    init(startingUpdater: Bool) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
