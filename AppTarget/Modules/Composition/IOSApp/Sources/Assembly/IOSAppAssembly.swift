import SwiftUI

/// The executable-facing surface of the iOS product composition.
public enum IOSAppAssembly {
    @MainActor
    public static func makeRootView() -> AnyView {
        AnyView(IOSAppComposition.makeProductionRootView())
    }
}
