public struct DesignSystemInteractions {
    public var setOpenHandCursor: (_ isActive: Bool) -> Void
    public var selectionModifiers: () -> PlatformSelectionModifiers

    public init(
        setOpenHandCursor: @escaping (_ isActive: Bool) -> Void,
        selectionModifiers: @escaping () -> PlatformSelectionModifiers
    ) {
        self.setOpenHandCursor = setOpenHandCursor
        self.selectionModifiers = selectionModifiers
    }

    public static let fallback = DesignSystemInteractions(
        setOpenHandCursor: { _ in },
        selectionModifiers: { [] }
    )
}
