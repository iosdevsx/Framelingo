import MacApp
import SwiftUI

@main
struct FramelingoApp: App {
    private let rootView = MacAppAssembly.makeRootView()

    var body: some Scene {
        WindowGroup {
            rootView
        }
        .commands {
            MacAppAssembly.makeDefaultCommands()
        }
    }
}
