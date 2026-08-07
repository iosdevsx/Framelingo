import SwiftUI

public enum DesignTypography {
    public static let title = Font.title2.weight(.semibold)
    public static let sectionTitle = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let timecode = Font.system(.caption, design: .monospaced)
}
