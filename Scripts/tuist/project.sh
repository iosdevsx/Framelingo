#!/bin/sh

set -eu
. "$(dirname -- "$0")/common.sh"

workspace="$TUIST_REPOSITORY_ROOT/Framelingo-Tuist.xcworkspace"
scheme="Framelingo-Tuist"
ios_scheme="Framelingo-iOS"
ios_package="$TUIST_REPOSITORY_ROOT/AppTarget/Modules/Composition/IOSApp"
derived_data="$TUIST_REPOSITORY_ROOT/DerivedData/Tuist"

require_generated_workspace() {
    [ -d "$workspace" ] || fail "Generated workspace is missing. Run 'mise run generate' first."
}

prepare_output_path() {
    output_path=$1
    if [ -e "$output_path" ]; then
        case "$output_path" in
            "$derived_data"/*) find "$output_path" -depth -delete ;;
            *) fail "Refusing to replace output outside $derived_data: $output_path" ;;
        esac
    fi
    mkdir -p "$(dirname -- "$output_path")"
}

print_invocation() {
    note "Workspace: $workspace"
    note "Scheme: $scheme"
    note "Configuration: $1"
    note "Destination: $2"
}

case "${1:-}" in
    generate)
        note "Generating Framelingo-Tuist.xcworkspace (source packages, no cloud cache, no Xcode launch)"
        tuist_exec generate run --no-open --cache-profile none
        ;;
    generate-open)
        note "Generating Framelingo-Tuist.xcworkspace and opening it in Xcode"
        tuist_exec generate run --no-open --cache-profile none
        /usr/bin/open "$workspace"
        ;;
    edit)
        note "Opening the permanent Tuist manifest project"
        tuist_exec edit --permanent
        ;;
    graph)
        note "Writing dependency graph to DerivedData/Tuist/graph.json"
        mkdir -p "$derived_data"
        tuist_exec graph --format json --no-open --output-path "$derived_data"
        ;;
    clean)
        [ "$TUIST_REPOSITORY_ROOT" != "/" ] || fail "Refusing to clean the filesystem root."
        [ -e "$TUIST_REPOSITORY_ROOT/.git" ] || fail "Refusing to clean outside a Git worktree: $TUIST_REPOSITORY_ROOT"
        [ -f "$TUIST_REPOSITORY_ROOT/Project.swift" ] || fail "Refusing to clean a repository without the Framelingo Project.swift manifest."
        [ -f "$TUIST_REPOSITORY_ROOT/.mise.toml" ] || fail "Refusing to clean a repository without the Framelingo Mise configuration."
        note "Removing repository-local generated Tuist and DerivedData output"
        for generated_path in \
            "$TUIST_REPOSITORY_ROOT/Framelingo-Tuist.xcodeproj" \
            "$TUIST_REPOSITORY_ROOT/Framelingo-Tuist.xcworkspace" \
            "$TUIST_REPOSITORY_ROOT/Manifests.xcodeproj" \
            "$TUIST_REPOSITORY_ROOT/Manifests.xcworkspace" \
            "$derived_data" \
            "$TUIST_REPOSITORY_ROOT/Derived"
        do
            if [ -e "$generated_path" ]; then
                find "$generated_path" -depth -delete
            fi
        done
        ;;
    build)
        platform=${2:-macos}
        configuration=${CONFIGURATION:-Debug}
        case "$platform" in
            macos)
                require_generated_workspace
                destination="platform=macOS,arch=arm64"
                print_invocation "$configuration" "$destination"
                xcodebuild build \
                    -workspace "$workspace" \
                    -scheme "$scheme" \
                    -configuration "$configuration" \
                    -destination "$destination" \
                    -derivedDataPath "$derived_data/Build-$configuration" \
                    -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
                    ARCHS=arm64 \
                    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
                ;;
            ios)
                destination="${TUIST_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
                scheme="$ios_scheme"
                require_generated_workspace
                print_invocation "$configuration" "$destination"
                xcodebuild build \
                    -workspace "$workspace" \
                    -scheme "$scheme" \
                    -configuration "$configuration" \
                    -destination "$destination" \
                    -derivedDataPath "$derived_data/Build-iOS-$configuration" \
                    -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
                    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
                ;;
            ipados)
                destination="${TUIST_IPADOS_DESTINATION:-platform=iOS Simulator,name=iPad Pro 13-inch (M5)}"
                scheme="$ios_scheme"
                require_generated_workspace
                print_invocation "$configuration" "$destination"
                xcodebuild build \
                    -workspace "$workspace" \
                    -scheme "$scheme" \
                    -configuration "$configuration" \
                    -destination "$destination" \
                    -derivedDataPath "$derived_data/Build-iPadOS-$configuration" \
                    -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
                    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
                ;;
            *) fail "Unknown build platform '$platform'. Use macos, ios, or ipados." ;;
        esac
        ;;
    test)
        platform=${2:-macos}
        case "$platform" in
            macos)
                require_generated_workspace
                destination="platform=macOS,arch=arm64"
                result_bundle="$derived_data/Test/Results/Framelingo.xcresult"
                prepare_output_path "$result_bundle"
                print_invocation "Debug" "$destination"
                xcodebuild test \
                    -workspace "$workspace" \
                    -scheme "$scheme" \
                    -testPlan FramelingoComplete \
                    -destination "$destination" \
                    -derivedDataPath "$derived_data/Test" \
                    -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
                    -resultBundlePath "$result_bundle" \
                    ARCHS=arm64 \
                    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
                ;;
            ios)
                destination="${TUIST_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
                scheme="IOSApp"
                print_invocation "Debug" "$destination"
                (
                    cd "$ios_package"
                    xcodebuild test \
                        -scheme "$scheme" \
                        -configuration Debug \
                        -destination "$destination" \
                        -derivedDataPath "$derived_data/Test-iOS" \
                        -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
                        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
                )
                ;;
            ipados)
                destination="${TUIST_IPADOS_DESTINATION:-platform=iOS Simulator,name=iPad Pro 13-inch (M5)}"
                scheme="IOSApp"
                print_invocation "Debug" "$destination"
                (
                    cd "$ios_package"
                    xcodebuild test \
                        -scheme "$scheme" \
                        -configuration Debug \
                        -destination "$destination" \
                        -derivedDataPath "$derived_data/Test-iPadOS" \
                        -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
                        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
                )
                ;;
            *) fail "Unknown test platform '$platform'. Use macos, ios, or ipados." ;;
        esac
        ;;
    verify-ios)
        require_generated_workspace
        destination="${TUIST_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
        scheme="$ios_scheme"
        ruby "$TUIST_REPOSITORY_ROOT/Scripts/audit-module-boundaries.rb" --self-test
        ruby "$TUIST_REPOSITORY_ROOT/Scripts/audit-module-boundaries.rb"
        ruby "$TUIST_REPOSITORY_ROOT/Scripts/audit-ios-app-boundaries.rb"
        print_invocation "Debug clean build" "$destination"
        xcodebuild clean build \
            -workspace "$workspace" \
            -scheme "$scheme" \
            -configuration Debug \
            -destination "$destination" \
            -derivedDataPath "$derived_data/Verify-iOS" \
            -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
        TUIST_IOS_DESTINATION="$destination" "$0" test ios
        ;;
    focused)
        test_identifier=${2:-}
        [ -n "$test_identifier" ] || fail "Pass a test identifier, for example: mise run test:focused -- SubtitlesImplTests"
        require_generated_workspace
        destination="platform=macOS,arch=arm64"
        print_invocation "Debug" "$destination"
        xcodebuild test \
            -workspace "$workspace" \
            -scheme "$scheme" \
            -destination "$destination" \
            -derivedDataPath "$derived_data/Focused" \
            -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
            -only-testing:"$test_identifier" \
            ARCHS=arm64 \
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
        ;;
    archive)
        platform=${2:-macos}
        case "$platform" in
            macos)
                require_generated_workspace
                archive_path="$derived_data/Archives/Framelingo-macOS.xcarchive"
                prepare_output_path "$archive_path"
                destination="generic/platform=macOS"
                print_invocation "Release" "$destination"
                xcodebuild archive \
                    -workspace "$workspace" \
                    -scheme "$scheme" \
                    -configuration Release \
                    -destination "$destination" \
                    -archivePath "$archive_path" \
                    -derivedDataPath "$derived_data/Archive-macOS" \
                    -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
                    ARCHS=arm64 \
                    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
                ;;
            ios)
                destination="generic/platform=iOS"
                scheme="$ios_scheme"
                require_generated_workspace
                print_invocation "Release" "$destination"
                xcodebuild archive \
                    -workspace "$workspace" \
                    -scheme "$scheme" \
                    -configuration Release \
                    -destination "$destination" \
                    -archivePath "$derived_data/Archives/Framelingo-iOS.xcarchive" \
                    -derivedDataPath "$derived_data/Archive-iOS" \
                    -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
                    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
                ;;
            *) fail "Unknown archive platform '$platform'. Use macos or ios." ;;
        esac
        ;;
    *)
        fail "Usage: $0 {generate|generate-open|edit|graph|clean|build|test|verify-ios|archive|focused}"
        ;;
esac
