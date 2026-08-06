import Combine
import Foundation
import Project
import Settings
import SpeechToText
import Testing
import VideoRendering
@testable import SettingsFeatureImpl

@MainActor
struct SettingsViewModelTests {
    @Test
    func globalSettingsCommitUsesAPIAccessAndObservesPersistenceFailure() {
        var initial = AppSettings.default
        initial.ffmpegPath = "/initial"
        let subject = CurrentValueSubject<SettingsSnapshot, Never>(
            SettingsSnapshot(settings: initial, persistenceState: .idle)
        )
        var committed: [AppSettings] = []
        let access = SettingsAccess(
            snapshot: { subject.value },
            snapshots: { subject.eraseToAnyPublisher() },
            reload: {},
            update: { settings in
                committed.append(settings)
                subject.send(SettingsSnapshot(
                    settings: settings,
                    persistenceState: .saved
                ))
            }
        )
        let adapter = RecordingExportSettingsAdapter(current: nil)
        let viewModel = makeViewModel(settingsAccess: access, adapter: adapter)

        viewModel.settings.ffmpegPath = "/updated"
        viewModel.save()

        #expect(committed.map(\.ffmpegPath) == ["/updated"])
        #expect(viewModel.settings.ffmpegPath == "/updated")

        subject.send(SettingsSnapshot(
            settings: viewModel.settings,
            persistenceState: .failed(SettingsPersistenceFailure(
                operation: .save,
                message: "Settings save failed."
            ))
        ))
        #expect(viewModel.settingsPersistenceMessage == "Settings save failed.")
    }

    @Test
    func projectExportSettingsUseSeparateAdapterAndDoNotMutateGlobalSettings() {
        let subject = CurrentValueSubject<SettingsSnapshot, Never>(
            SettingsSnapshot(settings: .default, persistenceState: .idle)
        )
        var globalCommitCount = 0
        let access = SettingsAccess(
            snapshot: { subject.value },
            snapshots: { subject.eraseToAnyPublisher() },
            reload: {},
            update: { _ in globalCommitCount += 1 }
        )
        let adapter = RecordingExportSettingsAdapter(current: VideoExportSettings())
        let viewModel = makeViewModel(settingsAccess: access, adapter: adapter)
        var updated = VideoExportSettings()
        updated.backgroundEnabled = false

        viewModel.updateVideoExportSettings(updated)

        #expect(adapter.updates == [updated])
        #expect(viewModel.currentVideoExportSettings == updated)
        #expect(globalCommitCount == 0)
    }

    private func makeViewModel(
        settingsAccess: SettingsAccess,
        adapter: RecordingExportSettingsAdapter
    ) -> SettingsViewModel {
        SettingsViewModel(
            settingsAccess: settingsAccess,
            activeProjectExportSettings: adapter,
            whisperInstaller: TestWhisperManager(),
            parakeetModelStore: TestParakeetManager(),
            usesEmbeddedVideoRenderingBackend: true,
            makeFFmpegService: { _ in TestFFmpegService() }
        )
    }
}

@MainActor
private final class RecordingExportSettingsAdapter: ActiveProjectExportSettingsManaging {
    private(set) var current: VideoExportSettings?
    private(set) var updates: [VideoExportSettings] = []

    init(current: VideoExportSettings?) {
        self.current = current
    }

    func update(_ settings: VideoExportSettings) {
        current = settings
        updates.append(settings)
    }
}

private enum SettingsFeatureTestError: Error {
    case unused
}

private struct TestWhisperManager: WhisperModelManaging {
    func install(
        model: WhisperModel,
        progressHandler: @escaping @Sendable (WhisperInstallStage, Double?) async -> Void
    ) async throws -> WhisperInstallation {
        throw SettingsFeatureTestError.unused
    }
}

private struct TestParakeetManager: ParakeetModelManaging {
    let approximateDownloadSizeText = "0 MB"
    func modelsArePresent() -> Bool { false }
    func installModels(
        progressHandler: @escaping @Sendable (SpeechModelDownloadProgress) async -> Void
    ) async throws {
        throw SettingsFeatureTestError.unused
    }
}

private struct TestFFmpegService: FFmpegService {
    func checkAvailability() async throws -> FFmpegInfo {
        throw SettingsFeatureTestError.unused
    }

    func extractAudio(
        from videoURL: URL,
        to outputURL: URL,
        clips: [ExportClipRange]?
    ) async throws -> URL {
        throw SettingsFeatureTestError.unused
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        clips: [ExportClipRange]?,
        verticalReframe: VerticalReframePlan?,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        throw SettingsFeatureTestError.unused
    }
}
