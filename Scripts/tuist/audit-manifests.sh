#!/bin/sh

set -eu
. "$(dirname -- "$0")/common.sh"

require_command git "Git is required to audit generated-file ownership."
require_command rg "ripgrep is required to audit manifest declarations."

[ -f Project.swift ] || fail "Project.swift is missing."
[ -f Workspace.swift ] || fail "Workspace.swift is missing."
[ -f Tuist.swift ] || fail "Tuist.swift is missing."

declared_package_count=$(rg -c '\.package\(path: "AppTarget/Modules/' Tuist/ProjectDescriptionHelpers/FramelingoPackages.swift)
[ "$declared_package_count" = "27" ] || fail "Tuist must expose all 27 local packages so every package test target is testable."

mac_app_package_count=$(rg -c '\.package\(path: "AppTarget/Modules/Composition/MacApp"\)' Tuist/ProjectDescriptionHelpers/FramelingoPackages.swift)
[ "$mac_app_package_count" = "1" ] || fail "The MacApp package reference must be declared exactly once."

flat_package_count=$(find AppTarget/Modules -mindepth 2 -maxdepth 2 -name Package.swift | wc -l | tr -d ' ')
[ "$flat_package_count" = "0" ] || fail "Packages must live inside logical module groups, not directly under AppTarget/Modules."

grouped_package_count=$(find AppTarget/Modules -mindepth 3 -maxdepth 3 -name Package.swift | wc -l | tr -d ' ')
[ "$grouped_package_count" = "27" ] || fail "Found $grouped_package_count grouped packages; expected 27."

rg -q '"AppTarget/Modules/\*/\*/Sources/\*\*"' Project.swift || \
    fail "Project.swift must expose the grouped module tree inside the main generated project."

if rg -n 'sources:[[:space:]]*\[[^]]*AppTarget/Modules/' Project.swift Tuist/ProjectDescriptionHelpers; then
    fail "Tuist must depend on package products, not compile package sources directly."
fi

tracked_generated=$(git ls-files \
    'Framelingo-Tuist.xcodeproj/**' \
    'Framelingo-Tuist.xcworkspace/**' \
    'Manifests.xcodeproj/**' \
    'Manifests.xcworkspace/**' \
    'Derived/**' \
    'DerivedData/**')
[ -z "$tracked_generated" ] || fail "Generated output is tracked:\n$tracked_generated"

tuist_exec inspect dependencies --only implicit

note "Manifest ownership, module grouping, and explicit-dependency audit passed"
