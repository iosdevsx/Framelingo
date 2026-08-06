public struct PlatformSelectionModifiers: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let extendSelection = PlatformSelectionModifiers(rawValue: 1 << 0)
    public static let toggleSelection = PlatformSelectionModifiers(rawValue: 1 << 1)
}
