import VideoRendering

func makeDefaultVerticalSubtitleStyle() -> VideoExportSettings {
    var style = VideoExportSettings()
    style.fontSize = 64
    style.maxLines = 3
    style.subtitlePositionX = 0.5
    style.subtitlePositionY = 0.68
    return style
}
