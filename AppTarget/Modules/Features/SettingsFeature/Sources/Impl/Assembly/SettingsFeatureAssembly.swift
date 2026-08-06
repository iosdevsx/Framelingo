import Foundation
import Project
import Settings
import SpeechToText
import SwiftUI
import VideoRendering

public enum SettingsFeatureAssembly {
    @MainActor
    public static func makeView(
        settingsAccess: SettingsAccess,
        activeProjectExportSettings: any ActiveProjectExportSettingsManaging,
        whisperInstaller: any WhisperModelManaging,
        parakeetModelStore: any ParakeetModelManaging,
        usesEmbeddedVideoRenderingBackend: Bool,
        makeFFmpegService: @escaping @MainActor (AppSettings) -> any FFmpegService,
        fileManager: FileManager = .default
    ) -> AnyView {
        let viewModel = SettingsViewModel(
            settingsAccess: settingsAccess,
            activeProjectExportSettings: activeProjectExportSettings,
            whisperInstaller: whisperInstaller,
            parakeetModelStore: parakeetModelStore,
            usesEmbeddedVideoRenderingBackend: usesEmbeddedVideoRenderingBackend,
            makeFFmpegService: makeFFmpegService,
            fileManager: fileManager
        )
        return AnyView(SettingsView(viewModel: viewModel))
    }
}
