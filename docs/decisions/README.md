# Architecture Decision Records

ADR фиксирует одно значимое архитектурное решение: контекст, выбранный вариант,
альтернативы и последствия. ADR нужен для решений, которые влияют на структуру,
владение состоянием, ключевые quality attributes или трудно отменяются.

## Жизненный цикл

- `Proposed` — решение обсуждается.
- `Accepted` — решение действует.
- `Deprecated` — решение больше не рекомендуется, но ещё встречается.
- `Superseded by ADR-NNNN` — решение заменено новым ADR.

Принятый ADR не переписывают под новую реальность. Создают новый документ,
который ссылается на заменённый, чтобы сохранить причину и историю компромиссов.

## Индекс

- [ADR-0001: API/Impl packages and product composition roots](0001-api-impl-packages.md)
- [ADR-0002: ProjectSession owns the active project](0002-project-session-ownership.md)
- [ADR-0003: Tuist generates product workspaces](0003-tuist-generated-workspace.md)

Для нового решения скопируйте [template.md](template.md), выберите следующий
номер и используйте короткое имя файла в kebab-case.
