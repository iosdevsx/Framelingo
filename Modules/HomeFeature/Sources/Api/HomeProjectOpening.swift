import Project

/// The only product-shell authority Home needs after it has loaded a project.
@MainActor
public struct HomeProjectOpening {
    private let openAction: (Project) -> Void

    public init(open: @escaping (Project) -> Void) {
        openAction = open
    }

    public func open(_ project: Project) {
        openAction(project)
    }
}
