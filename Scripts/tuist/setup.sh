#!/bin/sh

set -eu
. "$(dirname -- "$0")/common.sh"

require_command mise "Install Mise from https://mise.jdx.dev before running setup."

note "Trusting the repository-scoped Mise configuration"
mise trust --yes "$TUIST_REPOSITORY_ROOT/.mise.toml"

note "Installing pinned tools"
mise install

"$TUIST_SCRIPT_DIR/install.sh"
"$TUIST_SCRIPT_DIR/doctor.sh"
"$TUIST_SCRIPT_DIR/project.sh" generate

note "Framelingo toolchain and generated workspace are ready"
