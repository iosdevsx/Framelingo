# Settings and Project Catalog migration ledger

This ledger records the pre-migration `AppState` ownership surface and its
replacement. It is intentionally kept until the `Application` package is
retired so later changes can audit that ownership is not reintroduced.

| Current consumer | Transitional dependency | Replacement contract |
| --- | --- | --- |
| `MacAppComposition` | `SettingsAssembly.loadSettings/saveSettings` | One `SettingsManaging` owner from `SettingsImpl`; factories receive `SettingsAccess` snapshots |
| `AppState` | `settings` plus `saveSettings` callback | `currentSettings` read accessor only for transitional export work |
| `ProjectViewModel` | `appState.settings` | `SettingsAccess` snapshot supplied in `ProjectFeatureDependencies` |
| `SettingsViewModel` | reads/writes `appState.settings` | `SettingsAccess` for global settings |
| `SettingsViewModel` | edits selected project's export settings and saves through `appState.projectRepository` | narrow `ActiveProjectExportSettingsManaging` adapter |
| `HomeViewModel` | `appState.recentProjects` | observable `ProjectCatalogManaging.snapshot.summaries` |
| `HomeViewModel` | catalog refresh/open through `appState.projectRepository` | `ProjectCatalogManaging.refresh/open` |
| `HomeViewModel` | create/import persistence through `appState.projectRepository` | explicitly injected `ProjectRepository`, followed by `ProjectCatalogManaging.register` after success |
| `ProjectViewModel` | save/autosave through `appState.projectRepository` and mutation of `recentProjects` | injected `ProjectRepository`, followed by `ProjectCatalogManaging.register` after success |
| `AppState.deleteProject` | prepared-audio cleanup, repository delete, recents mutation, selection clearing | `ProjectCatalogManaging.delete`; selection clearing remains a caller responsibility |
| `ApplicationAssembly` / `AppStateDependencies` | construct and vend settings, recents, repository | remove those owner inputs; retain only temporary selection/workflow/export inputs |

## Baseline

- Settings package tests pass with legacy and current payload fixtures.
- Project package tests pass with legacy Project decoding and repository CRUD.
- ProjectFeature undo/autosave/single-source characterization tests pass.
- `ProjectFeatureAssemblyTests.testWorkspaceModesRequestTheirExpectedCapabilitySurfaces`
  failed once in the full suite because SwiftUI surfaces were still empty, then
  passed in isolation; treat it as a pre-existing lifecycle flake rather than a
  migration regression.
