import SwiftUI

public struct ProgressToastStack: View {
    public let items: [ProgressToastItem]

    public init(items: [ProgressToastItem]) {
        self.items = items
    }

    public var body: some View {
        if !items.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(items) { item in
                    ProgressToastCard(item: item)
                }
            }
            .frame(width: 360, alignment: .trailing)
        }
    }
}
