import MacFeatureImpl
import SwiftUI

@main
struct FramelingoApp: App {
    private let rootView = MacFeatureAssembly.makeDefaultRootView()

    var body: some Scene {
        WindowGroup {
            rootView
        }
        .commands {
            MacFeatureAssembly.makeDefaultCommands()
        }
    }
}
