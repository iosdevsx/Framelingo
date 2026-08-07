import SwiftUI

public extension EnvironmentValues {
    var designSystemInteractions: DesignSystemInteractions {
        get { self[DesignSystemInteractionsKey.self] }
        set { self[DesignSystemInteractionsKey.self] = newValue }
    }
}
