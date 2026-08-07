# Framelingo repository guidance

Framelingo is a native Swift/SwiftUI video-subtitle editor for macOS, iOS, and
iPadOS. This file is the always-on contract for coding agents. Keep it concise;
put explanations in tracked documentation and facts in generated artifacts.

## Start here

Before editing:

1. Read the nearest package `README.md` and `Package.swift`.
2. Locate the package's API, implementation, and tests before choosing an owner.
3. Check [docs/index.md](docs/index.md) for the authoritative source of each kind
   of project knowledge.
4. Preserve unrelated work in a dirty tree. Do not rewrite broad files for a
   focused change.

New production work belongs under `AppTarget/Modules`. Product workspaces are
generated from the Tuist manifests; generated `.xcodeproj` and `.xcworkspace`
files are never sources of truth.

## Repository shape

- `AppTarget/FramelingoApp.swift`: thin product entry point.
- `AppTarget/Modules/Composition`: macOS and iOS product composition roots.
- `AppTarget/Modules/Core`: domain models, policies, persistence contracts.
- `AppTarget/Modules/Workflows`: project preparation/session and processing flows.
- `AppTarget/Modules/Features`: SwiftUI feature surfaces and presentation models.
- `AppTarget/Modules/Infrastructure`: external tools and effectful adapters.
- `AppTarget/Modules/UI/DesignSystem`: reusable stateless visual primitives.
- `Project.swift`, `Workspace.swift`, `Tuist/`: generated-workspace definition.
- `Scripts/`: deterministic audits, build wrappers, and architecture export.
- `docs/`: shared explanations, decisions, how-to material, and generated data.

## Architectural invariants

- Each logical package exposes an API product and, where needed, an `Impl`
  product. API targets may depend only on API products.
- Ordinary implementation targets must not import another package's `Impl`.
  Product composition roots select concrete implementations and inject API-typed
  dependencies. See [module boundaries](docs/module-boundaries.md).
- Do not introduce a service locator or a new application-wide state container.
- `ProjectSession` is the sole mutable owner of the active project, history,
  autosave, and project-scoped effects. Presentation state may derive snapshots;
  it must not mirror editable project state.
- `Project.subtitles` is the single source of truth for subtitle text and timing.
  Editor, timeline, Shorts, import, and export must operate on that same data.
- Views stay thin. Business rules and effect orchestration belong to their owning
  core/workflow/service or presentation model, not SwiftUI view bodies.
- Keep persisted project/settings formats backward compatible unless an approved
  migration explicitly changes them.

## Swift concurrency

- UI-observable presentation owners that mutate UI state use explicit
  `@MainActor`. Service protocols, Codable models, parsers, and pure engines stay
  non-isolated unless their ownership genuinely requires an actor.
- The project intentionally does not enable module-wide default actor isolation.
- Do not add `nonisolated`, `@MainActor`, `@unchecked Sendable`, `Task {}`,
  `Task.detached`, `DispatchQueue`, or `try?` merely to silence diagnostics.
- Before adding `nonisolated`, prove that the enclosing type is actor-isolated and
  that the member does not touch isolated mutable state. Document why it is safe.
- Prefer structured async/await. Never block the main thread during file, process,
  model, transcription, translation, or export work.

## FFmpeg and file safety

- Invoke processes with executable URLs and argument arrays, never shell strings.
- Support spaces and non-ASCII paths; capture stdout, stderr, termination status,
  and cancellation explicitly.
- Do not force-unwrap URLs, files, process output, or persisted data.
- User-facing failures must explain the failed operation and a useful recovery.

## Change discipline

- Make the smallest change that puts responsibility in the correct owner.
- Do not duplicate state to work around a Binding or isolation problem.
- Do not implement adjacent future features without an explicit request.
- Add or update tests with behavior changes. Pure parsing, formatting, mapping,
  persistence, and export logic require focused unit coverage.
- If a change alters an architectural decision, add a new ADR under
  `docs/decisions/`; accepted ADRs are superseded, not silently rewritten.
- Update the owning package README when its responsibility, public surface,
  dependency boundary, or standalone test command changes.

## Verification

Use the narrowest relevant check first, then broaden in proportion to risk:

```sh
mise run docs:check
swift test --package-path AppTarget/Modules/<Category>/<Package>
mise run test:focused -- <TestTarget-or-TestIdentifier>
mise run doctor
mise run build:macos
mise run test:macos
mise run verify:ios
```

For manifest or dependency changes, also run:

```sh
ruby Scripts/audit-module-boundaries.rb --self-test
ruby Scripts/audit-module-boundaries.rb
mise run architecture:export
```

Do not claim completion without reporting which checks ran and any checks that
could not run.
