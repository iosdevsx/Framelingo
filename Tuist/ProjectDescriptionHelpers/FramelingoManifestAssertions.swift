import ProjectDescription

public enum FramelingoManifestAssertions {
    public static func validateFoundation() {
        precondition(FramelingoPlatform.macOSDestinations == [.mac])
        precondition(FramelingoPlatform.universalIOSDestinations == [.iPhone, .iPad])
        precondition(FramelingoPlatform.macOSDeploymentTargets.macOS == "15.6")
        precondition(FramelingoPlatform.mobileDeploymentTargets.iOS == "18.0")
        precondition(FramelingoSettings.futureMobileApplication["TARGETED_DEVICE_FAMILY"] == "1,2")
        precondition(FramelingoTargets.applicationName != FramelingoTargets.testName)
    }
}
