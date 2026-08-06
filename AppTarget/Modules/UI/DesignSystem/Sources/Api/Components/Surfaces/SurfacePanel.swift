import SwiftUI

public struct SurfacePanel<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DesignSpacing.medium)
            .background(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.large)
                    .stroke(.primary.opacity(0.06), lineWidth: 0.5)
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: DesignRadius.large))
    }
}
