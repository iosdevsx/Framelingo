#!/bin/sh

set -eu

TUIST_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TUIST_REPOSITORY_ROOT=$(CDPATH= cd -- "$TUIST_SCRIPT_DIR/../.." && pwd)
TUIST_EXPECTED_VERSION=4.203.3
XCODE_EXPECTED_VERSION=26.3

cd "$TUIST_REPOSITORY_ROOT"

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

note() {
    printf '==> %s\n' "$*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' was not found. $2"
}

tuist_exec() {
    mise exec -- tuist "$@"
}
