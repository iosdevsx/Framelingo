import Application
import Foundation
import Settings
import SpeechToText
import SwiftUI
import VideoRendering

public enum SettingsFeatureAssembly {
    @MainActor
    public static func makeView(
        appState: AppState,
        whisperInstaller: any WhisperModelManaging,
        parakeetModelStore: any ParakeetModelManaging,
        usesEmbeddedVideoRenderingBackend: Bool,
        makeFFmpegService: @escaping @MainActor (AppSettings) -> any FFmpegService,
        fileManager: FileManager = .default
    ) -> AnyView {
        let viewModel = SettingsViewModel(
            appState: appState,
            whisperInstaller: whisperInstaller,
            parakeetModelStore: parakeetModelStore,
            usesEmbeddedVideoRenderingBackend: usesEmbeddedVideoRenderingBackend,
            makeFFmpegService: makeFFmpegService,
            fileManager: fileManager
        )
        return AnyView(SettingsView(viewModel: viewModel))
    }
}
