# Tuist в Framelingo

Tuist хранит устройство Xcode-проекта в обычных Swift-файлах и каждый раз собирает из них одинаковый workspace. Сам сгенерированный `Framelingo-Tuist.xcworkspace` в Git не попадает: если он устарел или сломался, его проще удалить и получить заново.

Сейчас идёт переходный период. Старый `Framelingo.xcodeproj` остаётся рабочим эталоном, а новый workspace называется `Framelingo-Tuist.xcworkspace`. Основная macOS-сборка и полный тест-план уже работают через Tuist. Команды для iPhone и iPad заведены заранее, но честно завершаются ошибкой до появления отдельного mobile composition root из change `add-ios-app-composition`.

`AppTarget/Modules` подключён как синхронизированное дерево, как в InterviewTask:
группирующие каталоги остаются обычными папками, а лежащие внутри них каталоги
с `Package.swift` Xcode показывает как SPM-пакеты. Tuist не создаёт для них
отдельные `XCLocalSwiftPackageReference`.

## Первый запуск

Нужны Xcode 26.3 и [Mise](https://mise.jdx.dev/). Версии Xcode и Tuist зафиксированы в `.xcode-version` и `.mise.toml`.

```bash
mise trust
mise run setup
mise run doctor
```

`setup` устанавливает закреплённый Tuist, разрешает зависимости и генерирует workspace. `doctor` ничего не чинит молча: он проверяет Xcode, SDK, симуляторы, 27 локальных пакетов, 33 тестовых таргета и архитектурный аудит. Если проверка падает, в сообщении есть конкретное действие.

## Обычная работа

Сгенерировать проект без запуска Xcode:

```bash
mise run generate
```

Сгенерировать и сразу открыть:

```bash
mise run generate:open
```

Открыть уже созданный workspace вручную:

```bash
open Framelingo-Tuist.xcworkspace
```

Для правки самих манифестов есть отдельный проект:

```bash
mise run edit
```

Не редактируйте `Framelingo-Tuist.xcodeproj`, workspace и файлы в `Derived/`: это одноразовый результат генерации. Постоянные изменения живут в `Project.swift`, `Workspace.swift`, `Tuist.swift`, `Tuist/ProjectDescriptionHelpers` и `Tuist/Config`.

После изменения `Package.swift` или `Package.resolved` выполните:

```bash
mise run install
mise run generate
```

Корневой `.package.resolved` фиксирует общий набор внешних зависимостей сгенерированного workspace. Его нужно обновлять и коммитить вместе с осознанным обновлением зависимости.

## Сборка и тесты

```bash
mise run build:macos
CONFIGURATION=Release mise run build:macos
mise run test
```

`test` и `test:macos` означают одно и то же: полный план `FramelingoComplete`, все 33 тестовых таргета и 385 тестов на текущем baseline. Результат всегда лежит в `DerivedData/Tuist/Test/Results/Framelingo.xcresult`.

Один тест или один тестовый bundle запускается отдельно и не меняет поведение полной команды:

```bash
mise run test:focused -- FramelingoTests/FramelingoAppSmokeTests/testAppTargetLoads
mise run test:focused -- SubtitlesImplTests
```

Для диагностики графа зависимостей:

```bash
mise run graph
```

JSON появится в `DerivedData/Tuist/graph.json`. Проверка неявных связей запускается так:

```bash
./Scripts/tuist/audit-manifests.sh
ruby Scripts/tuist/audit-test-inventory.rb DerivedData/Tuist/Test/Results/Framelingo.xcresult
```

## Архив

Неподписанный macOS-архив, пригодный для проверки состава приложения:

```bash
mise run archive:macos
mise run archive:validate:macos
```

Архив создаётся в `DerivedData/Tuist/Archives/Framelingo-macOS.xcarchive`, а вторая команда проверяет bundle id, версию, arm64 executable, dSYM, Whisper, Sparkle и FFmpeg. Эти команды не читают сертификаты и не делают вид, что получился релиз: подпись, notarization и публикация будут отдельным защищённым workflow.

После появления мобильной композиции команды будут такими:

```bash
mise run build:ios
mise run build:ipados
mise run test:ios
mise run test:ipados
mise run archive:ios
```

`archive:ios` создаст один universal iOS archive для iPhone и iPad. Пока мобильного app target нет, эти команды печатают выбранный destination и понятную причину остановки вместо ложной успешной сборки.

## Если проект протух

Начните с безопасной очистки:

```bash
mise run clean
mise run install
mise run generate
```

`clean` удаляет только сгенерированные `Framelingo-Tuist.*`, `Derived/` и `DerivedData/Tuist`. Исходники, старый Xcode-проект и пользовательские данные он не трогает.

Если этого мало:

```bash
mise run doctor
mise run generate 2>&1 | tee DerivedData/tuist-generate.log
```

Не скрывайте исходную ошибку через `try?`, дополнительный `Task` или случайные build settings. В отчёт прикладывайте полный лог и, для тестов, `.xcresult` из пути выше.

## Как добавить настоящий app target

1. Сначала создайте отдельный composition package/product для платформы. App target должен зависеть от одного composition product, а не собирать сервисы сам.
2. Добавьте тонкий `@main`, ресурсы, Info.plist, destinations и deployment target в helper из `Tuist/ProjectDescriptionHelpers`.
3. Добавьте target в `Project.swift`, затем явную схему и test plan.
4. Обновите `audit-manifests.sh` и `audit-test-inventory.rb`, чтобы новый продукт нельзя было случайно потерять при следующей генерации.
5. Проверьте `doctor`, двойную чистую генерацию, Debug/Release, полный тест-план и credential-free archive. Только после этого переносите CI с shadow-режима в required.

Для iOS нельзя переиспользовать `MacApp`, Sparkle или текущие macOS-only FFmpeg binaries. Это не ограничение Tuist, а реальная граница платформенного кода и бинарных slices.

## CI и выпуск приложения

Обычный workflow `.github/workflows/ci.yml` пока собирает старый Xcode-проект и служит контрольной точкой. `.github/workflows/tuist-shadow.yml` независимо устанавливает закреплённый Tuist через Mise, генерирует workspace с чистого checkout, запускает аудиты, Debug/Release, все 385 тестов и проверяет неподписанный macOS archive. Его job называется `Generated macOS (shadow)` и помечен `continue-on-error`, поэтому на этапе сравнения он показывает проблему, но не подменяет действующий required check. При падении сохраняются полные логи и xcresult на семь дней.

Публикация релиза через Tuist намеренно ещё не включена. Для неё сначала нужно утвердить production environment, bundle ids и набор секретов для Developer ID, notarization, Sparkle и доступа к release-репозиторию. Текущий `Scripts/archive-release.sh` продолжает работать со старым Xcode-проектом и не считается частью нового CD-пути. Переключать публикацию до проверки защищённого dry run нельзя.
