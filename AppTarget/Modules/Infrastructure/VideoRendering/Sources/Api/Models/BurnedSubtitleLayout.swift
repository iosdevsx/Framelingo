import CoreGraphics

public struct BurnedSubtitleLayout: Equatable {
    public var selectedText: String
    public var wrappedLines: [String]
    public var textSize: CGSize
    public var backgroundRect: CGRect
    public var textPosition: CGPoint

    public var wrappedText: String { wrappedLines.joined(separator: "\n") }

    public init(
        selectedText: String,
        wrappedLines: [String],
        textSize: CGSize,
        backgroundRect: CGRect,
        textPosition: CGPoint
    ) {
        self.selectedText = selectedText
        self.wrappedLines = wrappedLines
        self.textSize = textSize
        self.backgroundRect = backgroundRect
        self.textPosition = textPosition
    }
}
