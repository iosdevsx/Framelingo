# IOSApp

`IOSApp` — product composition root универсального приложения для iPhone и iPad.
Он выбирает concrete implementations хранилища и `ProjectSession`, соединяет их
с feature API и отдаёт исполняемому target один публичный `IOSAppAssembly`.

## Что лежит внутри

- `Composition` создаёт файловый `ProjectRepository`, одну сессию проекта и
  platform-appropriate processing capabilities.
- `Shell` и `State` управляют верхнеуровневой навигацией и presentation state, не
  дублируя редактируемый проект.
- `Adapters` реализуют document import, picker и подготовку файлов для системного
  share sheet с учётом security-scoped URLs.
- `Presentation` предоставляет iOS-варианты player и subtitle editor surfaces.
- `Assembly` — единственный публичный вход для тонкого executable target.

## Граница модуля

`IOSApp` может импортировать необходимые `Impl`-продукты, потому что выбирает
реализации для продукта. Бизнес-правила проектов, субтитров и processing flows
остаются в профильных Core и Workflow пакетах.

AppKit, Sparkle и macOS-only FFmpeg binaries не должны попадать в этот граф.
Недоступная на iOS capability выражается через composition contract, а не через
скрытую зависимость от macOS implementation.

## Тесты

Тесты проверяют composition, document adapters, совместимость проектов,
контролируемые processing outcomes и основные взаимодействия iPhone/iPad shell.

```sh
swift test --package-path AppTarget/Modules/Composition/IOSApp
```
