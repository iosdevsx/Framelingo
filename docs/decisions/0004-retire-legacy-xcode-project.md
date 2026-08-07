# ADR-0004: Retire the legacy Xcode project

- Status: Accepted
- Date: 2026-08-07
- Supersedes: [ADR-0003](0003-tuist-generated-workspace.md)
- Superseded by: —

## Context

The generated Tuist workspace now builds and tests the modular macOS product,
builds and tests the iOS product, and produces the credential-free macOS
archive. Keeping the original `Framelingo.xcodeproj`, monolithic sources, tests,
and parity tooling creates a second product definition and lets the two copies
drift.

## Decision

Tuist manifests are the only source of truth for product targets, schemes,
resources, settings, and test plans. Production code lives under
`AppTarget/Modules`, while the thin app entry points live under `AppTarget` and
`AppTargetIOS`. The checked-in Xcode project, monolithic source tree, monolithic
tests, and source-parity audit are removed.

The application asset catalog moves to `AppTarget/Resources`. The protected
release script generates the workspace and archives the Tuist macOS scheme, so
release packaging does not retain a dependency on the retired project.

## Alternatives considered

- Keep the old project as a parity reference: preserves a fallback but continues
  dual maintenance after the modular product has become the validated path.
- Remove the old project but keep its sources and tests: reduces project-file
  drift while leaving duplicate implementation and test ownership in the tree.
- Remove the old release script without replacement: completes source cleanup
  but drops the established signed/notarized distribution workflow.

## Consequences

- A clean clone must generate the workspace before product builds or releases.
- Product settings and resources must be changed in Tuist-owned files only.
- Historical parity is preserved in Git history and the archived migration
  change, not in live source trees.
- CI and local verification exercise the same generated workspace.
