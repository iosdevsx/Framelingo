import AppUpdate
import SwiftUI

@MainActor
struct MacFeatureCommands: Commands {
    let updateChecker: any AppUpdateChecking

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                updateChecker.checkForUpdates()
            }
        }
    }
}
