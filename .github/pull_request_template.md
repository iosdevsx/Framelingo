## Summary

<!-- What changed and why? Keep this focused on observable behavior and ownership. -->

## Verification

<!-- List exact commands/checks run and their results. Explain anything not run. -->

- [ ] Focused tests or audits
- [ ] Relevant platform build/test

## Knowledge impact

Mark every applicable item; explain `N/A` where the impact is not obvious.

- [ ] Package responsibility/API/dependency changed → owning package README updated
- [ ] Significant architectural decision changed → new ADR added or existing Proposed ADR updated
- [ ] Package graph/runtime scenario changed → `mise run architecture:export` run
- [ ] Build, test, or contributor workflow changed → `AGENTS.md` or `docs/` updated
- [ ] Persisted format changed → compatibility/migration documentation and fixtures updated
- [ ] No documentation impact

## Final checklist

- [ ] `mise run docs:check`
- [ ] No unrelated files or generated workspaces included
- [ ] User-facing errors remain actionable
