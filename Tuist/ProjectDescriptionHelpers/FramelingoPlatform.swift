import ProjectDescription

public enum FramelingoPlatform {
    public static let macOSDestinations: Destinations = [.mac]
    public static let universalIOSDestinations: Destinations = [.iPhone, .iPad]

    public static let macOSDeploymentTargets: DeploymentTargets = .macOS("15.6")
    public static let mobileDeploymentTargets: DeploymentTargets = .iOS("18.0")

    public static let macOSDestination = "platform=macOS,arch=arm64"
    public static let genericMacOSDestination = "generic/platform=macOS"
    public static let genericIOSDestination = "generic/platform=iOS"
}
