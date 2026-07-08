#!/bin/sh
# Builds a signed, notarized, distributable Framelingo.app for manual
# hand-off (Developer ID signing + notarization, no App Store), and
# publishes it as a Sparkle auto-update to the Framelingo-releases repo.
#
# One-time setup before this works:
#   1. Notarization credentials (needs your Apple ID, can't be scripted):
#      xcrun notarytool store-credentials "Framelingo-Notary" \
#          --key ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8 \
#          --key-id XXXXXXXXXX --issuer XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
#      (or --apple-id you@example.com --team-id TWW7UPTWB8 for an
#      app-specific-password profile instead of an API key)
#   2. Push access to github.com/iosdevsx/Framelingo-releases (public repo
#      that hosts appcast.xml + release archives, separate from this
#      private source repo since Sparkle needs an unauthenticated HTTPS feed).
#   3. Sparkle EdDSA signing key in this Mac's keychain (already generated
#      via `generate_keys` when auto-update was first wired up; only needs
#      redoing on a new machine).
#
# CURRENT_PROJECT_VERSION is bumped automatically (Sparkle compares
# CFBundleVersion to decide if an update exists). MARKETING_VERSION is only
# bumped when one of --major/--minor/--patch is passed -- the script can't
# know what kind of release this is. Both are rolled back if the release
# fails before the archive is published.
#
# Usage: Scripts/archive-release.sh [--major|--minor|--patch]
#
# Output:
#   build/Framelingo.xcarchive   -- raw archive
#   build/export/Framelingo.app  -- signed, notarized, stapled app
#   pushed to Framelingo-releases: releases/Framelingo-<version>-b<build>.zip
#                                    + releases/appcast.xml

set -eu

# Optional marketing-version bump on top of the always-automatic build bump:
#   --patch  1.2 -> 1.2.1   (bugfix re-release)
#   --minor  1.2 -> 1.3     (new features)
#   --major  1.2 -> 2.0     (big/breaking changes)
BUMP_KIND=""
case "${1-}" in
    "") ;;
    --major|--minor|--patch) BUMP_KIND="${1#--}" ;;
    *)  echo "usage: Scripts/archive-release.sh [--major|--minor|--patch]" >&2
        exit 64 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Framelingo.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DERIVED_DATA_PATH="$BUILD_DIR/DerivedData"
EXPORT_OPTIONS="$SCRIPT_DIR/ExportOptions.plist"
NOTARY_PROFILE="Framelingo-Notary"
RELEASES_REPO_URL="https://github.com/iosdevsx/Framelingo-releases.git"
RELEASES_REPO_DIR="$BUILD_DIR/Framelingo-releases"
RELEASES_RAW_BASE="https://raw.githubusercontent.com/iosdevsx/Framelingo-releases/main"
SPARKLE_TOOLS_DIR="$ROOT_DIR/.sparkle-tools"
SPARKLE_TOOLS_VERSION="2.9.4"
SU_FEED_URL="$RELEASES_RAW_BASE/releases/appcast.xml"
SU_PUBLIC_ED_KEY="G9fIRzqXcLGqqj5Yk8NxqaFurhEzEIZQWMa0C5UMc/E="

if [ ! -x "$SPARKLE_TOOLS_DIR/bin/generate_appcast" ]; then
    echo "==> Fetching Sparkle $SPARKLE_TOOLS_VERSION CLI tools (one-time, cached at $SPARKLE_TOOLS_DIR)"
    mkdir -p "$SPARKLE_TOOLS_DIR"
    curl -fsSL -o "/tmp/sparkle-tools-$SPARKLE_TOOLS_VERSION.tar.xz" \
        "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_TOOLS_VERSION/Sparkle-$SPARKLE_TOOLS_VERSION.tar.xz"
    tar -xJf "/tmp/sparkle-tools-$SPARKLE_TOOLS_VERSION.tar.xz" -C "$SPARKLE_TOOLS_DIR"
fi

echo "==> Checking notarization credentials (fail fast before a 2+ minute build)"
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "error: no notarytool credentials found for profile '$NOTARY_PROFILE'." >&2
    echo "Run this once first (App Store Connect API key):" >&2
    echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\" >&2
    echo "      --key ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8 \\" >&2
    echo "      --key-id XXXXXXXXXX --issuer XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" >&2
    echo "or (Apple ID + app-specific password):" >&2
    echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\" >&2
    echo "      --apple-id you@example.com --team-id TWW7UPTWB8" >&2
    exit 1
fi

# Auto-bump the build number across all targets (same as `agvtool
# next-version -all`). The EXIT trap restores the pre-bump project.pbxproj
# unless the release made it all the way to a published archive, so a failed
# build/notarization/push never leaves a half-released version behind.
PBXPROJ="$ROOT_DIR/Framelingo.xcodeproj/project.pbxproj"
OLD_BUILD=$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION = \([0-9][0-9]*\);.*/\1/p' "$PBXPROJ" | sort -n | tail -1)
if [ -z "$OLD_BUILD" ]; then
    echo "error: could not read CURRENT_PROJECT_VERSION from $PBXPROJ" >&2
    exit 1
fi
NEW_BUILD=$((OLD_BUILD + 1))
PBXPROJ_BACKUP=$(mktemp /tmp/framelingo-pbxproj-backup.XXXXXX)
cp "$PBXPROJ" "$PBXPROJ_BACKUP"
PUBLISHED=0
NEW_MARKETING=""
restore_version_on_failure() {
    if [ "$PUBLISHED" -eq 0 ]; then
        cp "$PBXPROJ_BACKUP" "$PBXPROJ"
        echo "note: release did not publish -- restored project.pbxproj (build $NEW_BUILD -> $OLD_BUILD${NEW_MARKETING:+, version $NEW_MARKETING -> $OLD_MARKETING})" >&2
    fi
    rm -f "$PBXPROJ_BACKUP"
}
trap restore_version_on_failure EXIT
trap 'exit 130' INT HUP TERM

echo "==> Bumping CURRENT_PROJECT_VERSION $OLD_BUILD -> $NEW_BUILD (rolls back automatically if the release fails)"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9][0-9]*;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"

if [ -n "$BUMP_KIND" ]; then
    OLD_MARKETING=$(sed -n 's/^[[:space:]]*MARKETING_VERSION = \([0-9.][0-9.]*\);.*/\1/p' "$PBXPROJ" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
    IFS=. read -r V_MAJOR V_MINOR V_PATCH <<EOF
$OLD_MARKETING
EOF
    V_MINOR=${V_MINOR:-0}
    V_PATCH=${V_PATCH:-0}
    case "$BUMP_KIND" in
        major) NEW_MARKETING="$((V_MAJOR + 1)).0" ;;
        minor) NEW_MARKETING="$V_MAJOR.$((V_MINOR + 1))" ;;
        patch) NEW_MARKETING="$V_MAJOR.$V_MINOR.$((V_PATCH + 1))" ;;
    esac
    echo "==> Bumping MARKETING_VERSION $OLD_MARKETING -> $NEW_MARKETING (--$BUMP_KIND)"
    sed -i '' "s/MARKETING_VERSION = [0-9.][0-9.]*;/MARKETING_VERSION = $NEW_MARKETING;/g" "$PBXPROJ"
fi

echo "==> Cleaning $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving (Release configuration, isolated DerivedData -- no stale incremental state)"
xcodebuild \
    -project "$ROOT_DIR/Framelingo.xcodeproj" \
    -scheme Framelingo \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination 'generic/platform=macOS' \
    clean archive

echo "==> Exporting signed app (Developer ID)"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

# GENERATE_INFOPLIST_FILE=YES only synthesizes Info.plist keys Xcode
# recognizes -- INFOPLIST_KEY_SUFeedURL/SUPublicEDKey in project.pbxproj are
# silently dropped (verified empirically). Inject them directly into the
# exported Info.plist instead, before the app gets its final signature
# below (editing it after signing would invalidate the seal, same reason
# the Whisper binaries have to be fixed before the final re-sign too).
echo "==> Injecting Sparkle Info.plist keys"
PLIST="$EXPORT_PATH/Framelingo.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :SUFeedURL string $SU_FEED_URL" "$PLIST"
/usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SU_PUBLIC_ED_KEY" "$PLIST"

APP_PATH="$EXPORT_PATH/Framelingo.app"
DEVELOPER_ID_IDENTITY="Developer ID Application: Yury Loginov (TWW7UPTWB8)"
ENTITLEMENTS_PLIST="$BUILD_DIR/entitlements.plist"

# `xcodebuild -exportArchive` re-signs the whole bundle for distribution,
# including the loose BundledTools/Whisper binaries in Resources -- but
# without --options runtime, so they come out of export ad-hoc-adjacent
# (Developer ID identity, no hardened runtime). Re-sign them properly, then
# re-sign the outer .app so its resource seal matches the updated binaries
# (resigning nested files after the outer seal is generated invalidates it).
echo "==> Re-signing bundled Whisper binaries with hardened runtime"
CODESIGNING_FOLDER_PATH="$APP_PATH" "$SCRIPT_DIR/sign-bundled-tools.sh"

echo "==> Re-sealing Framelingo.app after updating nested binaries"
codesign -d --entitlements "$ENTITLEMENTS_PLIST" --xml "$APP_PATH"
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS_PLIST" \
    --sign "$DEVELOPER_ID_IDENTITY" \
    "$APP_PATH"

echo "==> Verifying signature (pre-notarization)"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|flags"

echo "==> Submitting for notarization (can take a few minutes)"
NOTARY_ZIP="$BUILD_DIR/Framelingo-for-notarization.zip"
ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "==> Gatekeeper assessment (should now be accepted)"
spctl -a -vvv -t execute "$APP_PATH"

echo "==> Publishing update to $RELEASES_REPO_URL"
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
APP_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
rm -rf "$RELEASES_REPO_DIR"
git clone --depth 1 "$RELEASES_REPO_URL" "$RELEASES_REPO_DIR"
mkdir -p "$RELEASES_REPO_DIR/releases"
# Build number in the filename: re-releasing the same marketing version must
# not overwrite a zip in place -- raw.githubusercontent.com caches, and a
# stale cached zip would no longer match its EdDSA signature in the appcast.
ditto -c -k --keepParent "$APP_PATH" "$RELEASES_REPO_DIR/releases/Framelingo-$APP_VERSION-b$APP_BUILD.zip"

"$SPARKLE_TOOLS_DIR/bin/generate_appcast" \
    --download-url-prefix "$RELEASES_RAW_BASE/releases/" \
    "$RELEASES_REPO_DIR/releases"

git -C "$RELEASES_REPO_DIR" add -A
if git -C "$RELEASES_REPO_DIR" diff --cached --quiet; then
    echo "note: no changes to publish (version $APP_VERSION already released)"
else
    git -C "$RELEASES_REPO_DIR" commit -m "Release $APP_VERSION (build $APP_BUILD)"
    git -C "$RELEASES_REPO_DIR" push origin main
    PUBLISHED=1
fi

echo ""
echo "Done: $APP_PATH"
echo "Notarized and stapled -- opens on any Mac without a Gatekeeper warning."
if [ "$PUBLISHED" -eq 1 ]; then
    echo "project.pbxproj now has CURRENT_PROJECT_VERSION = $NEW_BUILD${NEW_MARKETING:+, MARKETING_VERSION = $NEW_MARKETING} -- commit it."
fi
