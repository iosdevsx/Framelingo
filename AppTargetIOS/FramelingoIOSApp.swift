import IOSApp
import SwiftUI

@main
struct FramelingoIOSApp: App {
    private let rootView = IOSAppAssembly.makeRootView()

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }
}
