import Foundation
import Media
import ProjectPreparation
import VideoRendering

public typealias ProjectPreparationFFmpegServiceBuilder =
    (ProjectPreparationConfiguration) -> any FFmpegService

public struct ProjectPreparationFileSystem {
    let fileExists: (URL) -> Bool
    let removeItem: (URL) throws -> Void

    public init(
        fileExists: @escaping (URL) -> Bool,
        removeItem: @escaping (URL) throws -> Void
    ) {
        self.fileExists = fileExists
        self.removeItem = removeItem
    }

    public static func live(fileManager: FileManager = .default) -> Self {
        Self(
            fileExists: { fileManager.fileExists(atPath: $0.path) },
            removeItem: { try fileManager.removeItem(at: $0) }
        )
    }
}

public enum ProjectPreparationAssembly {
    public static func makeProjectPreparer(
        mediaMetadataProvider: any MediaMetadataProviding,
        waveformLoader: any WaveformLoading,
        makeFFmpegService: @escaping ProjectPreparationFFmpegServiceBuilder,
        fileSystem: ProjectPreparationFileSystem = .live(),
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) -> any ProjectPreparing {
        DefaultProjectPreparer(
            mediaMetadataProvider: mediaMetadataProvider,
            waveformLoader: waveformLoader,
            makeFFmpegService: makeFFmpegService,
            fileSystem: fileSystem,
            temporaryDirectory: temporaryDirectory
        )
    }
}
