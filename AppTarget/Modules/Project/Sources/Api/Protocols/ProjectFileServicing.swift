import Foundation

public protocol ProjectFileServicing {
    func exportProject(_ project: Project, to fileURL: URL) throws
    func importProject(from fileURL: URL) throws -> Project
}
