# ADR-0002: ProjectSession owns the active project

- Status: Accepted
- Date: 2026-08-06
- Supersedes: —
- Superseded by: —

## Context

Редактирование проекта затрагивает субтитры, таймлайн, Shorts, undo/redo,
autosave и длительные processing effects. Владение этими данными во ViewModel
экрана или в нескольких feature-моделях создаёт конкурирующие копии и допускает
сохранение устаревшего состояния.

## Decision

Один `ProjectSession` владеет активным `Project`, транзакциями редактирования,
историей, interaction groups, autosave и project-scoped effects. Feature-модули
получают узкие session protocols и отображают immutable snapshots или чисто
presentation-состояние.

`Project.subtitles` остаётся единственным источником истины для текста и таймингов.
Timeline, editor, Shorts, import и export не создают отдельный редактируемый
subtitle store.

## Alternatives considered

- Оставить владение в `ProjectViewModel`: связывает бизнес-жизненный цикл проекта
  со SwiftUI presentation и мешает совместному использованию capabilities.
- По store на feature: локально удобно, но требует двусторонней синхронизации и
  разрешения конфликтов.
- Глобальный `AppState`: расширяет lifetime состояния и превращается в service
  locator/application umbrella.

## Consequences

- Изменения проекта проходят через session operations и единый порядок эффектов.
- Undo/redo и autosave видят одну последовательность состояний.
- Presentation models могут иметь локальное UI-состояние, но не копию проекта.
- Новые edit capabilities должны расширять узкие session protocols или чистые
  domain policies, а не обходить session.
