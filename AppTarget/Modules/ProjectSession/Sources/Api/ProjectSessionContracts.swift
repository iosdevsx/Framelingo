import Combine
import Foundation
import Project

@MainActor
public protocol ProjectSessionObserving: AnyObject {
    var snapshot: ProjectSessionSnapshot { get }
    var snapshots: AnyPublisher<ProjectSessionSnapshot, Never> { get }
}

@MainActor
public protocol ProjectSessionDocumentLifecycle: AnyObject {
    func open(_ project: Project)
    func close()
}

@MainActor
public protocol ProjectSessionHistoryControlling: AnyObject {
    func undo()
    func redo()
    func beginInteraction(named name: String)
    func endInteraction(named name: String)
}

@MainActor
public protocol ProjectSessionPersisting: AnyObject {
    func save() async
}

/// Read-only identity seam for focused coordinators introduced by later changes.
/// Mutation authority remains internal to ProjectSessionImpl.
@MainActor
public protocol ProjectSessionExtensionAccessing: AnyObject {
    var activeProjectID: UUID? { get }
}

@MainActor
public protocol ProjectSession:
    ProjectSessionObserving,
    ProjectSessionDocumentLifecycle,
    ProjectSessionHistoryControlling,
    ProjectSessionPersisting,
    ProjectSessionExtensionAccessing
{}
