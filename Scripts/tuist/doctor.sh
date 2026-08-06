#!/bin/sh

set -eu
. "$(dirname -- "$0")/common.sh"

require_command mise "Install Mise from https://mise.jdx.dev."
require_command xcodebuild "Install Xcode $XCODE_EXPECTED_VERSION and select it with xcode-select."
require_command xcrun "Install Xcode command-line tools."
require_command ruby "Ruby is required by the module-boundary audit."
require_command jq "jq is required by test-inventory checks."

actual_tuist_version=$(tuist_exec version)
[ "$actual_tuist_version" = "$TUIST_EXPECTED_VERSION" ] || \
    fail "Tuist $actual_tuist_version is active; expected $TUIST_EXPECTED_VERSION. Run 'mise install'."

actual_xcode_version=$(xcodebuild -version | sed -n '1s/^Xcode //p')
[ "$actual_xcode_version" = "$XCODE_EXPECTED_VERSION" ] || \
    fail "Xcode $actual_xcode_version is selected; expected $XCODE_EXPECTED_VERSION from .xcode-version."

sdk_list=$(xcodebuild -showsdks)
printf '%s\n' "$sdk_list" | grep -q -- '-sdk macosx' || fail "The macOS SDK is missing from Xcode."
printf '%s\n' "$sdk_list" | grep -q -- '-sdk iphoneos' || fail "The iOS device SDK is missing from Xcode."
printf '%s\n' "$sdk_list" | grep -q -- '-sdk iphonesimulator' || fail "The iOS simulator SDK is missing from Xcode."

package_count=$(find AppTarget/Modules -mindepth 3 -maxdepth 3 -name Package.swift | wc -l | tr -d ' ')
[ "$package_count" = "27" ] || fail "Found $package_count module manifests; expected 27. Run the module audit before changing the inventory."

test_target_count=$(jq '.testTargets | length' TestPlan.xctestplan)
[ "$test_target_count" = "33" ] || fail "TestPlan.xctestplan contains $test_target_count targets; expected 33."

ruby Scripts/audit-module-boundaries.rb --self-test >/dev/null
ruby Scripts/audit-module-boundaries.rb >/dev/null

if xcrun simctl list devices available -j 2>/dev/null | jq -e '.devices | to_entries | map(select(.value | length > 0)) | length > 0' >/dev/null; then
    simulator_status="available"
else
    simulator_status="not available (macOS work is usable; install an iOS runtime before mobile builds)"
fi

note "Tuist: $actual_tuist_version"
note "Xcode: $actual_xcode_version"
note "Local module packages: $package_count"
note "Complete test-plan targets: $test_target_count"
note "Simulator runtime: $simulator_status"
note "Doctor checks passed"
