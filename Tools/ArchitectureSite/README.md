# Framelingo Architecture Site

Interactive package topology, impact analysis, and runtime pipeline views for
the Framelingo repository.

## Refresh architecture data

Run this from the repository root:

```bash
mise run architecture:export
```

The exporter reads Swift package manifests and the documented runtime scenarios,
then updates both the canonical snapshot under `docs/architecture/` and the site
snapshot at `Tools/ArchitectureSite/app/architecture-data.json`.

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
