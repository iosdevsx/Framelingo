import Timeline

public enum TimelineAssembly {
    public static func makeEditService() -> any EditTimelineEditing {
        EditTimelineService()
    }
}
