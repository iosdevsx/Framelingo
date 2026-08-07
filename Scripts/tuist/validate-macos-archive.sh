#!/bin/sh

set -eu
. "$(dirname -- "$0")/common.sh"

archive_path=${1:-"$TUIST_REPOSITORY_ROOT/DerivedData/Tuist/Archives/Framelingo-macOS.xcarchive"}
app_path="$archive_path/Products/Applications/Framelingo.app"
app_info="$app_path/Contents/Info.plist"
executable="$app_path/Contents/MacOS/Framelingo"

[ -d "$archive_path" ] || fail "macOS archive is missing: $archive_path. Run 'mise run archive:macos'."
[ -f "$app_info" ] || fail "Archived Framelingo Info.plist is missing."
[ -x "$executable" ] || fail "Archived Framelingo executable is missing."
[ -d "$archive_path/dSYMs/Framelingo.app.dSYM" ] || fail "Framelingo app dSYM is missing from the archive."
[ -f "$app_path/Contents/Resources/Whisper/whisper-cli" ] || fail "Bundled whisper-cli is missing from the archive."
[ -f "$app_path/Contents/Resources/Assets.car" ] || fail "Compiled asset catalog is missing from the archive."
[ -d "$app_path/Contents/Frameworks/Sparkle.framework" ] || fail "Sparkle.framework is missing from the archive."
[ -d "$app_path/Contents/Frameworks/ffmpegkit.framework" ] || fail "ffmpegkit.framework is missing from the archive."

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$app_info"
}

[ "$(plist_value CFBundleIdentifier)" = "com.somegreatapp.Framelingo" ] || fail "Unexpected macOS bundle identifier."
[ "$(plist_value CFBundleShortVersionString)" = "2.0.1" ] || fail "Unexpected macOS marketing version."
[ "$(plist_value CFBundleVersion)" = "4" ] || fail "Unexpected macOS build number."
[ "$(plist_value LSMinimumSystemVersion)" = "15.6" ] || fail "Unexpected macOS deployment target."

file "$executable" | grep -q 'Mach-O 64-bit executable arm64' || fail "Archived executable is not arm64-only."

if codesign --verify "$app_path" >/dev/null 2>&1; then
    fail "Credential-free archive unexpectedly contains a valid app signature; release signing belongs to the protected release workflow."
fi

note "Credential-free macOS archive is valid: $archive_path"
