# ADR-0005: Declarative architecture policy from SwiftPM manifests

- Status: Accepted
- Date: 2026-08-07
- Supersedes: —
- Superseded by: —

## Context

The Architecture Site extracted package topology while the boundary audit kept
allowed directions partly in prose and imperative Ruby. A stale generated
snapshot could not safely act as enforcement input, and adding a second graph
implementation would let explanation and enforcement drift apart.

## Decision

Use one side-effect-free reader for local SwiftPM manifests. Architecture export
and guardrail evaluation consume its deterministic local/external package graph.
Store layer classification, allowed directions, external permissions, direct
fan-out limits, overrides, and exact exceptions in the versioned
`Scripts/architecture/policy.yml` schema.

`Scripts/audit-module-boundaries.rb` remains the aggregate entry point and owns
source-level API/Impl, product-composer, retirement, and ownership checks. It
evaluates graph policy once. `mise run architecture:check` runs focused tooling
self-tests before that aggregate audit. The Tuist manifest audit remains an
independent parity and generated-workspace ownership check.

## Alternatives considered

- Validate the checked-in Architecture Site JSON: rejected because it may be
  stale after a manifest edit.
- Keep directions in Ruby constants: rejected because policy changes are less
  reviewable and mix graph data with source-scanning mechanics.
- Put policy in Tuist manifests: rejected because SwiftPM manifests are package
  dependency truth and the check must not require workspace generation.

## Consequences

New or moved packages fail unless one path layer classifies them. Cycles,
forbidden directions, external access, and fan-out growth receive stable,
actionable violations locally and in CI. Exact exceptions remain visible data
with required rationales and optional expiration. The strict reader intentionally
supports only documented literal dependency declarations; unsupported Swift
expressions fail instead of disappearing from the graph.
