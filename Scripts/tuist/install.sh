#!/bin/sh

set -eu
. "$(dirname -- "$0")/common.sh"

require_command mise "Run 'mise run setup' first."

note "Using Tuist $(tuist_exec version)"
tuist_exec install
