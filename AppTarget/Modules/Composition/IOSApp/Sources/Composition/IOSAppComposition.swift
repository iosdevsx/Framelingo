import Project
import ProjectImpl
import ProjectSession
import ProjectSessionImpl
import Foundation

enum IOSAppComposition {
    @MainActor
    static func makeProductionRootView() -> IOSProductRootView {
        let fileManager = FileManager.default
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let productRoot = applicationSupport.appendingPathComponent(
            "Framelingo iOS",
            isDirectory: true
        )
        let repository = ProjectAssembly.makeRepository(
            fileManager: fileManager,
            appName: "Framelingo iOS"
        )
        let projectFileService = ProjectAssembly.makeFileService()
        let importer = IOSDocumentImportAdapter(
            fileManager: fileManager,
            mediaRootURL: productRoot.appendingPathComponent("Media", isDirectory: true),
            projectFileService: projectFileService
        )
        let share = IOSProjectShareAdapter(
            fileManager: fileManager,
            exportRootURL: fileManager.temporaryDirectory.appendingPathComponent(
                "Framelingo iOS Exports",
                isDirectory: true
            ),
            projectFileService: projectFileService
        )
        return makeRootView(
            repository: repository,
            documentImporter: importer,
            sharePreparer: share
        )
    }

    @MainActor
    static func makeRootView(
        repository: any ProjectRepository,
        documentImporter: any IOSDocumentImporting,
        sharePreparer: any IOSProjectSharePreparing
    ) -> IOSProductRootView {
        IOSProductRootView(model: makeModel(
            repository: repository,
            documentImporter: documentImporter,
            sharePreparer: sharePreparer
        ))
    }

    @MainActor
    static func makeModel(
        repository: any ProjectRepository,
        documentImporter: (any IOSDocumentImporting)? = nil,
        sharePreparer: (any IOSProjectSharePreparing)? = nil,
        processingOptions: IOSControlledProcessingOptions = .success
    ) -> IOSAppModel {
        let fileService = ProjectAssembly.makeFileService()
        let session = DefaultProjectSession(
            dependencies: ProjectSessionDependencies(
                repository: repository,
                effects: IOSControlledProcessingComposition.makeEffects(
                    projectFileService: fileService,
                    options: processingOptions
                )
            )
        )
        let fallbackRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Framelingo IOSApp Tests",
            isDirectory: true
        )
        return IOSAppModel(
            repository: repository,
            session: session,
            documentImporter: documentImporter ?? IOSDocumentImportAdapter(
                mediaRootURL: fallbackRoot.appendingPathComponent("Media", isDirectory: true),
                projectFileService: fileService,
                securityAccess: IOSSecurityScopedAccess(start: { _ in true }, stop: { _ in })
            ),
            sharePreparer: sharePreparer ?? IOSProjectShareAdapter(
                exportRootURL: fallbackRoot.appendingPathComponent("Exports", isDirectory: true),
                projectFileService: fileService
            )
        )
    }
}
