import Foundation
import Shorts

public struct TimelineShortsOverlay {
    public var shorts: [ShortDefinition]
    public var selectedShortID: UUID?
    public var snapToCues: Bool
    public var onSelect: (UUID) -> Void
    public var onCommitRange: (UUID, Int, Int) -> Void
    public var onCreate: (Int, Int) -> Void

    public init(
        shorts: [ShortDefinition],
        selectedShortID: UUID?,
        snapToCues: Bool,
        onSelect: @escaping (UUID) -> Void,
        onCommitRange: @escaping (UUID, Int, Int) -> Void,
        onCreate: @escaping (Int, Int) -> Void
    ) {
        self.shorts = shorts
        self.selectedShortID = selectedShortID
        self.snapToCues = snapToCues
        self.onSelect = onSelect
        self.onCommitRange = onCommitRange
        self.onCreate = onCreate
    }
}
