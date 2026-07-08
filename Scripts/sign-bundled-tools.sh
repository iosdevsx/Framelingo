#!/bin/sh
# Re-signs the bundled Whisper CLI + its dylibs with the Developer ID
# identity used for distribution.
#
# Why this is needed: BundledTools/Whisper is added to the app target as a
# folder reference in the "Copy Bundle Resources" build phase, not as an
# "Embed Frameworks" entry with the CodeSignOnCopy attribute, so Xcode never
# re-signs it. It ships ad-hoc-signed by default (see
# `codesign -dv BundledTools/Whisper/whisper-cli`). Worse, `xcodebuild
# -exportArchive` re-signs loose Resources binaries too, but without
# `--options runtime` -- so even a Run Script build phase that signs them
# correctly during `archive` gets silently overwritten by `-exportArchive`
# afterwards. So this script must run AFTER export, directly against the
# exported .app (see Scripts/archive-release.sh), not as an Xcode build
# phase (also avoids fighting User Script Sandboxing for no benefit).
#
# A hardened runtime, Developer-ID-signed .app that contains ad-hoc-signed
# nested Mach-O binaries fails Apple notarization ("secure timestamp
# missing" / "hardened runtime not enabled" on the nested binary).
#
# Usage: CODESIGNING_FOLDER_PATH=/path/to/Framelingo.app sh sign-bundled-tools.sh
#
# Falls back to ad-hoc signing when the Developer ID certificate isn't
# present in the keychain, so this never blocks anyone without that specific
# cert from at least producing a locally-runnable (non-distributable) build.

set -eu
set -o pipefail

DEVELOPER_ID_IDENTITY="Developer ID Application: Yury Loginov (TWW7UPTWB8)"

if [ -z "${CODESIGNING_FOLDER_PATH:-}" ]; then
    echo "warning: sign-bundled-tools.sh: CODESIGNING_FOLDER_PATH is not set, skipping"
    exit 0
fi

WHISPER_DIR="$CODESIGNING_FOLDER_PATH/Contents/Resources/Whisper"

if [ ! -d "$WHISPER_DIR" ]; then
    echo "warning: sign-bundled-tools.sh: $WHISPER_DIR not found, skipping"
    exit 0
fi

if security find-identity -v -p codesigning 2>/dev/null | grep -qF "$DEVELOPER_ID_IDENTITY"; then
    IDENTITY="$DEVELOPER_ID_IDENTITY"
    SIGN_OPTS="--options runtime --timestamp"
else
    echo "warning: sign-bundled-tools.sh: '$DEVELOPER_ID_IDENTITY' not found in keychain -- ad-hoc signing bundled Whisper binaries instead (fine for local Debug runs, NOT valid for a distributable Release archive)"
    IDENTITY="-"
    SIGN_OPTS=""
fi

find "$WHISPER_DIR" -type f -perm -u+x -print0 | while IFS= read -r -d '' BIN; do
    echo "Signing $(basename "$BIN") with $IDENTITY"
    codesign --force $SIGN_OPTS --sign "$IDENTITY" "$BIN"
done
