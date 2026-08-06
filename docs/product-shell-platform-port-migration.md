# Product shell and platform-port migration

## Previous ownership inventory

| Previous surface | Readers/writers | Replacement |
| --- | --- | --- |
| `AppState.selectedProject` | Home open, ProjectViewModel load/save synchronization, Settings project export style, MainNavigationView and Sidebar | One `MacProductShell.selectedProject`, exposed to features through `HomeProjectOpening`, `ProjectSelectionAccess`, and `ActiveProjectExportSettingsManaging` |
| `MainNavigationView.hasOpenedProject` | MainNavigationView | `MacProductShell.hasOpenedProject` |
| `MainNavigationView.workspaceMode` / `projectMode` | Sidebar, ProjectFeature, navigation synchronization callbacks | `MacProductShell.workspaceMode` / `projectMode` with one synchronization implementation |
| `AppState.closeSelectedProject` | Product close flow | `MacProductShell.closeSelectedProject`, using `PreparedMediaCleanup` before clearing selection |
| `AppState.revealVideoExport` | Activity toast | `ExportOutputRevealing`, implemented by `AppKitOutputRevealAdapter` in MacFeatureImpl |
| `AppState.copyText` | Activity toast | `ExportDiagnosticCopying`, implemented by `AppKitDiagnosticCopyAdapter` in MacFeatureImpl |
| `ProjectFeatureDependencies.pickSubtitleFile` | ProjectViewModel subtitle import | `SubtitleDocumentPicker`, implemented by `AppKitSubtitleDocumentPickerAdapter` in MacFeatureImpl |
| Direct Application activity reads in ExportFeature | Activity toast | `ProductActivitySource`; temporary `AppStateActivitySourceAdapter` remains in MacFeatureImpl |

## Remaining Application compatibility surface

`AppState` now contains only workflow/export compatibility state pending the dedicated extraction changes:

- transcription activity and its canonical actions;
- video-export queue, payloads, and queue actions;
- workflow services still used by ProjectFeature until pipeline extraction;
- subtitle export and translation services still used by the transitional ProjectViewModel;
- current settings read access required by the existing video-export worker.

It no longer owns a selected project, navigation, Finder reveal, clipboard copy, or subtitle-picker authority.

## Persistence compatibility

This migration changes no project JSON, settings encoding, repository paths, or persisted model fields. It only moves in-memory product ownership and platform-operation wiring. The repository is ready for pipeline/export extraction and the later `retire-application-package` change.
