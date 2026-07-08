//
//  FramelingoApp.swift
//  Framelingo
//
//  Created by Юрий Логинов on 27.04.2026.
//

import Sparkle
import SwiftUI

@main
struct FramelingoApp: App {
    @StateObject private var appState = AppState()

    // Plain `let`, not `@StateObject`: SPUStandardUpdaterController isn't an
    // ObservableObject. App-conforming structs are instantiated once by the
    // runtime for the app's lifetime (unlike View structs), so a stored
    // `let` here is safe and is Sparkle's documented SwiftUI integration
    // pattern.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }
    }
}
