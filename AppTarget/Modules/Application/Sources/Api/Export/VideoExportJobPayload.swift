import Project
import VideoRendering

struct VideoExportJobPayload {
    var project: Project
    var settings: VideoExportSettings
    var sourceInfo: VideoSourceInfo?
    var shortPlan: ShortExportPlan?
}
