import ProjectDescription

public enum FramelingoTargets {
    public static let applicationName = "Framelingo"
    public static let testName = "FramelingoTests"
    public static let iOSApplicationName = "FramelingoIOS"

    public static func macOSApplication() -> Target {
        .target(
            name: applicationName,
            destinations: FramelingoPlatform.macOSDestinations,
            product: .app,
            productName: "Framelingo",
            bundleId: "com.somegreatapp.Framelingo",
            deploymentTargets: FramelingoPlatform.macOSDeploymentTargets,
            infoPlist: .dictionary([
                "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
                "CFBundleExecutable": "$(EXECUTABLE_NAME)",
                "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                "CFBundleInfoDictionaryVersion": "6.0",
                "CFBundleName": "$(PRODUCT_NAME)",
                "CFBundlePackageType": "$(PRODUCT_BUNDLE_PACKAGE_TYPE)",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "LSApplicationCategoryType": "public.app-category.video",
                "NSHumanReadableCopyright": "",
            ]),
            resources: [
                "AppTarget/Resources/Assets.xcassets",
                .folderReference(path: "BundledTools/Whisper"),
            ],
            buildableFolders: [
                .folder(
                    "AppTarget",
                    exceptions: .exceptions([
                        .exception(excluded: FramelingoPackages.appTargetMembershipExclusions),
                    ])
                ),
            ],
            scripts: [
                .pre(
                    script: "ruby \"$SRCROOT/Scripts/audit-module-boundaries.rb\"",
                    name: "Audit Module Boundaries",
                    inputPaths: [
                        "$(SRCROOT)/AppTarget/Modules/**",
                        "$(SRCROOT)/Scripts/audit-module-boundaries.rb",
                    ],
                    basedOnDependencyAnalysis: false,
                    shellPath: "/bin/zsh"
                ),
            ],
            dependencies: [
                .package(product: "MacApp"),
            ],
            settings: FramelingoSettings.macOSApplication
        )
    }

    public static func macOSTests() -> Target {
        .target(
            name: testName,
            destinations: FramelingoPlatform.macOSDestinations,
            product: .unitTests,
            bundleId: "com.somegreatapp.FramelingoTests",
            deploymentTargets: FramelingoPlatform.macOSDeploymentTargets,
            infoPlist: .default,
            sources: ["AppTargetTests/**"],
            dependencies: [
                .target(name: applicationName),
            ] + FramelingoPackages.testDiscoveryProducts.map {
                .package(product: $0)
            },
            settings: FramelingoSettings.macOSTests
        )
    }

    public static func iOSApplication() -> Target {
        .target(
            name: iOSApplicationName,
            destinations: FramelingoPlatform.universalIOSDestinations,
            product: .app,
            productName: "Framelingo",
            bundleId: "com.somegreatapp.Framelingo.ios",
            deploymentTargets: FramelingoPlatform.mobileDeploymentTargets,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Framelingo",
                "UILaunchScreen": [:],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight",
                ],
            ]),
            sources: ["AppTargetIOS/**"],
            dependencies: [
                .package(product: "IOSApp"),
            ],
            settings: FramelingoSettings.iOSApplication
        )
    }

}
