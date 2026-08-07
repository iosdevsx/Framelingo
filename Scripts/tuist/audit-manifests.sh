#!/bin/sh

set -eu
. "$(dirname -- "$0")/common.sh"

require_command git "Git is required to audit generated-file ownership."

[ -f Project.swift ] || fail "Project.swift is missing."
[ -f Workspace.swift ] || fail "Workspace.swift is missing."
[ -f Tuist.swift ] || fail "Tuist.swift is missing."

if grep -Eq '\.package\(path:' Project.swift Tuist/ProjectDescriptionHelpers/*.swift; then
    fail "Local modules must be discovered through the synchronized AppTarget tree, not XCLocalSwiftPackageReference entries."
fi

membership_exclusion_count=$(grep -Ec '"Modules/.+"' Tuist/ProjectDescriptionHelpers/FramelingoPackages.swift)
[ "$membership_exclusion_count" = "28" ] || fail "Found $membership_exclusion_count package membership exclusions; expected 28."

flat_package_count=$(find AppTarget/Modules -mindepth 2 -maxdepth 2 -name Package.swift | wc -l | tr -d ' ')
[ "$flat_package_count" = "0" ] || fail "Packages must live inside logical module groups, not directly under AppTarget/Modules."

grouped_package_count=$(find AppTarget/Modules -mindepth 3 -maxdepth 3 -name Package.swift | wc -l | tr -d ' ')
[ "$grouped_package_count" = "28" ] || fail "Found $grouped_package_count grouped packages; expected 28."

grep -Eq 'buildableFolders:' Tuist/ProjectDescriptionHelpers/FramelingoTargets.swift || \
    fail "The app target must expose AppTarget through an Xcode synchronized folder."

for project_file in Framelingo.xcodeproj/project.pbxproj Framelingo-Tuist.xcodeproj/project.pbxproj; do
    [ -f "$project_file" ] || continue

    if grep -Eq 'XCLocalSwiftPackageReference|packageReferences =|package = .*XCLocalSwiftPackageReference' "$project_file"; then
        fail "$project_file contains explicit local-package references; packages must be discovered from the synchronized Modules tree."
    fi
done

if grep -En 'sources:[[:space:]]*\[[^]]*AppTarget/Modules/' Project.swift Tuist/ProjectDescriptionHelpers/*.swift; then
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

# Tuist's implicit-dependency inspector treats Swift files inside synchronized
# package folders as app-target sources even though the Xcode membership
# exception set excludes them. Module imports are audited separately by
# Scripts/audit-module-boundaries.rb, which understands the package boundaries.
note "Manifest ownership and synchronized package-tree audit passed"
