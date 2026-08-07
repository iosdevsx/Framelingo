# ADR-0001: API/Impl packages and product composition roots

- Status: Accepted
- Date: 2026-08-06
- Supersedes: —
- Superseded by: —

## Context

Framelingo разделён на локальные SwiftPM-пакеты. Если feature и service-модули
напрямую импортируют concrete implementations друг друга, граф снова становится
связанным монолитом, тесты требуют полной production-сборки, а перенос продукта
на другую платформу заставляет тащить macOS-зависимости.

## Decision

Каждая логическая capability публикует продукт API и, когда нужны эффекты или UI,
продукт `Impl`. API зависит только от API. Обычный `Impl` использует соседние
capabilities через API-контракты и не импортирует чужой `Impl`.

Только product composition roots (`MacApp`, `IOSApp` и будущие продукты) выбирают
concrete implementations и собирают полный граф. Исполняемый target остаётся
тонким и зависит от своего composition root.

## Alternatives considered

- Один большой SwiftPM package: проще первоначально, но не даёт независимых
  границ сборки, тестирования и платформ.
- Разрешить Impl-to-Impl зависимости: сокращает wiring, но скрывает владение и
  быстро создаёт циклический граф.
- Service locator: упрощает доступ к сервисам, но делает зависимости неявными и
  усложняет тесты.

## Consequences

- Пакеты можно собирать и тестировать независимо.
- Платформы выбирают разные implementations одних API.
- Composition содержит явный wiring и может быть многословным.
- Любая новая Impl-to-Impl связь считается архитектурным изменением и должна быть
  отражена в audit и новом ADR.
