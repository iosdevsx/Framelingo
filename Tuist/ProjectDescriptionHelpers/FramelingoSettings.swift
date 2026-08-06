import ProjectDescription

public enum FramelingoSettings {
    public static let configurations: [Configuration] = [
        .debug(name: "Debug", xcconfig: "Tuist/Config/Debug.xcconfig"),
        .release(name: "Release", xcconfig: "Tuist/Config/Release.xcconfig"),
    ]

    public static let project: Settings = .settings(
        configurations: configurations,
        defaultSettings: .recommended,
        defaultConfiguration: "Debug"
    )

    public static let macOSApplication: Settings = .settings(
        base: [
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "CODE_SIGN_IDENTITY": "Apple Development",
            "CODE_SIGN_STYLE": "Automatic",
            "COMBINE_HIDPI_IMAGES": "YES",
            "CURRENT_PROJECT_VERSION": "4",
            "DEVELOPMENT_TEAM": "TWW7UPTWB8",
            "ENABLE_APP_SANDBOX": "NO",
            "ENABLE_HARDENED_RUNTIME": "YES",
            "ENABLE_PREVIEWS": "YES",
            "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
            "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks",
            "MARKETING_VERSION": "2.0.1",
            "REGISTER_APP_GROUPS": "YES",
            "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
            "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY": "YES",
        ],
        configurations: configurations,
        defaultSettings: .recommended
    )

    public static let macOSTests: Settings = .settings(
        base: [
            "CODE_SIGN_IDENTITY": "Apple Development",
            "CODE_SIGN_STYLE": "Automatic",
            "CURRENT_PROJECT_VERSION": "4",
            "DEVELOPMENT_TEAM": "TWW7UPTWB8",
            "MARKETING_VERSION": "2.0.1",
        ],
        configurations: configurations,
        defaultSettings: .recommended
    )

    public static let futureMobileApplication: SettingsDictionary = [
        "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO",
        "TARGETED_DEVICE_FAMILY": "1,2",
    ]
}
