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
