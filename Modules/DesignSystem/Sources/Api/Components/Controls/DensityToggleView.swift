import SwiftUI

public struct DensityToggleView: View {
    @Binding var density: EditorDensity

    public init(density: Binding<EditorDensity>) {
        _density = density
    }

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(EditorDensity.allCases) { option in
                Button { density = option } label: {
                    Text(option.rawValue.capitalized)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            density == option
                                ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.white)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .shadow(
                            color: density == option ? Color.black.opacity(0.1) : Color.clear,
                            radius: 1, y: 1
                        )
                        .foregroundStyle(density == option ? .primary : Color.primary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}
