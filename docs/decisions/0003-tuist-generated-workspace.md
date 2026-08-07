# ADR-0003: Tuist generates product workspaces

- Status: Superseded by ADR-0004
- Date: 2026-08-06
- Supersedes: —
- Superseded by: [ADR-0004](0004-retire-legacy-xcode-project.md)

## Context

Ручное редактирование Xcode project-файлов плохо проверяется review, легко теряет
targets и settings и затрудняет воспроизводимое добавление macOS/iOS продуктов.
Логические модули уже описаны независимыми SwiftPM manifests, поэтому дублировать
их полный граф в другом формате также нежелательно.

## Decision

Tuist manifests являются source of truth для product targets, schemes, resources,
entitlements и test plans. Версия Tuist закреплена через Mise; локальная разработка
и CI используют одинаковые `mise run …` команды. Сгенерированные `.xcodeproj` и
`.xcworkspace` не коммитятся.

SwiftPM `Package.swift` остаются source of truth для логических модулей и их
API/Impl зависимостей. Старый checked-in Xcode project сохраняется только как
временный parity reference до завершения cutover.

## Alternatives considered

- Продолжать вручную поддерживать Xcode project: меньше tooling, но нет
  детерминированной генерации и удобного структурного review.
- Перенести все package targets в Tuist: создаёт два описания модульного графа и
  теряет независимый `swift test --package-path` workflow.
- Коммитить generated workspace: увеличивает diff noise и позволяет generated
  output расходиться с manifests.

## Consequences

- Чистый clone должен воспроизводить workspace закреплённой командой.
- Изменения manifests проходят doctor, generation, Debug/Release и test inventory.
- Разработчику нужен закреплённый Tuist/Mise toolchain.
- До окончательного cutover существует ограниченная стоимость поддержки parity
  reference, но обязательный CI использует generated workspace.
