#!/bin/sh

set -eu
. "$(dirname -- "$0")/common.sh"

assert_fails_with() {
    expected=$1
    shift

    output_file=$(mktemp)
    if "$@" >"$output_file" 2>&1; then
        find "$output_file" -delete
        fail "Expected command to fail: $*"
    fi

    if ! grep -Fq "$expected" "$output_file"; then
        note "Unexpected output from: $*"
        sed -n '1,80p' "$output_file"
        find "$output_file" -delete
        fail "Expected failure message containing: $expected"
    fi

    find "$output_file" -delete
}

assert_fails_with \
    "Unknown build platform 'watchos'" \
    ./Scripts/tuist/project.sh build watchos

assert_fails_with \
    "Pass a test identifier" \
    ./Scripts/tuist/project.sh focused

assert_fails_with \
    "Complete add-ios-app-composition" \
    ./Scripts/tuist/project.sh build ios

assert_fails_with \
    "Required command 'mise' was not found" \
    env PATH=/usr/bin:/bin ./Scripts/tuist/doctor.sh

note "Tuist command failure-message checks passed"
