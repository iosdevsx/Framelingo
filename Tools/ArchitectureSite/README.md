# Framelingo Architecture Site

Interactive package topology, impact analysis, and runtime pipeline views for
the Framelingo repository.

## Refresh architecture data

Run this from the repository root:

```bash
mise run architecture:export
```

The exporter and architecture guardrails share
`Scripts/architecture/package_graph.rb`, so the generated view and policy check
use the same deterministic local/external identities and direct edges. The
exporter combines that graph with documented runtime scenarios, then updates the
canonical snapshot under `docs/architecture/` and the site snapshot at
`Tools/ArchitectureSite/app/architecture-data.json`.

The snapshot tracks package topology, test targets, and runtime scenarios. It
does not track Swift source-file contents or counts, so ordinary file additions
and edits do not require regeneration.

Validate current manifests against the versioned policy and the source-level
boundary rules with:

```bash
mise run architecture:check
```

The generated JSON explains current topology; it is not enforcement input. The
check always reads current manifests, so a changed edge cannot hide behind a
stale snapshot.

## Run locally

```bash
cd Tools/ArchitectureSite
npm run dev
```

Use `npm run build` to validate the production bundle.

## Automatic refresh after merge

`.github/workflows/refresh-architecture-site.yml` runs after a pull request is
merged into `main`. It regenerates both snapshots, validates the site, and
commits changed JSON files back to `main` as `github-actions[bot]`.

The workflow uses `GITHUB_TOKEN` by default. If branch protection does not allow
GitHub Actions to push directly to `main`, add a repository secret named
`ARCHITECTURE_BOT_TOKEN` containing a fine-grained token with Contents read/write
permission and allow that bot identity through the branch rule.

## Pull request architecture diff

`.github/workflows/architecture-pr-diff.yml` compares every pull request with
its base revision using trusted tooling from `main`. It updates one bot comment
with package and dependency changes, the resulting area of influence, affected
runtime paths, and suggested test bundles. Complete base, head, JSON diff, and
Markdown reports are attached to the workflow run as an artifact.
