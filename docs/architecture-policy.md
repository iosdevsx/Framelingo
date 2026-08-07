# Architecture policy

`Scripts/architecture/policy.yml` is the machine-readable source of truth for
package-layer directions, direct fan-out budgets, external package permissions,
and exact direction exceptions. The policy is evaluated from current
`Package.swift` files, never from the generated Architecture Site snapshot.

Run the complete local gate with:

```sh
mise run architecture:check
```

## Schema version 1

The root contains exactly these fields:

- `schema_version`: currently `1`.
- `layers`: layer names mapped to `paths`, `allowed_local`, `allowed_external`,
  and `fan_out.local`/`fan_out.external`.
- `packages`: exact local package names with optional `allowed_external`,
  `local_fan_out`, or `external_fan_out` overrides.
- `exceptions`: exact `source` and `target` local package names, a non-empty
  `rationale`, and optional quoted ISO `expires_on` date.

Layer `paths` are repository-relative glob patterns and must classify each local
package exactly once. Every other package or layer reference is exact: wildcards
are rejected. Same-layer dependencies require the layer name in its own
`allowed_local` list. External permissions and local/external fan-out counts are
separate. Fan-out counts unique direct edges only.

Unknown fields, unsupported schema versions, bad references, malformed limits,
unclassified or ambiguously classified packages, and expired exceptions fail the
check. Direction exceptions never suppress cycle or fan-out failures.

## Baseline budgets

The initial limits use the current direct-edge distribution. Ordinary packages
use their layer's observed practical ceiling. Existing composition and
coordination packages above that ceiling (`MacApp`, `ProjectFeature`, and
`ProjectSession`) use exact measured overrides; `VideoExport` has the same kind
of narrow override. External access is denied by default and enabled only for
the three packages that currently declare one external dependency.

Core-to-Infrastructure is forbidden at the layer level. Three existing edges
are documented as exact exceptions in the policy rather than weakening the
direction for all Core packages.
