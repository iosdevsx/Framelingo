<div align="center">
  <img src="AppTarget/Resources/Assets.xcassets/AppIcon.appiconset/appicon.png" width="128" height="128" alt="Framelingo icon">

  # Framelingo

  **Нативная macOS‑студия для создания, синхронизации и экспорта субтитров.**

  Превращайте видео в аккуратные субтитры локально — от распознавания речи<br>до таймлайна, разметки спикеров и готового MP4.

  [![macOS 15.6+](https://img.shields.io/badge/macOS-15.6%2B-111111?style=flat-square&logo=apple)](https://www.apple.com/macos/)
  [![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-111111?style=flat-square&logo=apple)](https://support.apple.com/116943)
  [![Swift 5](https://img.shields.io/badge/Swift-5-F05138?style=flat-square&logo=swift&logoColor=white)](https://www.swift.org/)
  [![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0D96F6?style=flat-square&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
</div>

---

## Возможности

| | |
|---|---|
| 🎙️ **Локальная транскрибация** | Whisper.cpp с VAD или Parakeet через FluidAudio — исходное видео не отправляется в облако |
| 👥 **Определение спикеров** | Диаризация, автоматическое сопоставление реплик и переименование участников |
| 🎞️ **Удобный таймлайн** | Волновая форма, масштабирование, точная настройка границ реплик и синхронное воспроизведение |
| ✍️ **Редактор субтитров** | Исходный и переводной текст, предупреждения о таймингах, undo/redo и несколько режимов рабочего пространства |
| ✂️ **Монтаж без разрушения исходника** | Виртуальные разрезы и обрезка видео с автоматическим пересчётом субтитров |
| 📤 **Гибкий экспорт** | SRT, WebVTT и TXT, подписи спикеров, а также MP4 со встроенными субтитрами |
| 🎨 **Оформление видео** | Шрифт, цвета, фон, рамка, позиция, разрешение, FPS, кодек и качество экспорта |
| 📥 **Импорт субтитров** | SRT, VTT, ASS, SSA, TXT и SBV с предпросмотром перед добавлением в проект |
| 💾 **Файлы проектов** | Сохранение и повторное открытие проектов в формате `.subtitleedit` |

## Как это работает

```text
Видео → извлечение аудио → распознавание речи → определение спикеров
      → редактура и синхронизация → экспорт субтитров или готового видео
```

1. Перетащите в Framelingo файл `MP4`, `MOV`, `M4V`, `WEBM` или `MKV`.
2. Выберите локальный движок распознавания и установите модель в **Settings → Tools**.
3. Запустите транскрибацию, проверьте текст и таймкоды на таймлайне.
4. При необходимости переименуйте спикеров, импортируйте перевод или отредактируйте видео.
5. Экспортируйте отдельные субтитры либо MP4 с уже встроенным оформлением.

> [!NOTE]
> Распознавание и обработка медиа выполняются на Mac. Интернет нужен при первой загрузке моделей и для проверки обновлений приложения.

## Системные требования

- Mac с процессором Apple Silicon (`arm64`)
- macOS 15.6 или новее
- Xcode 26.3 — точная версия закреплена для воспроизводимой сборки из исходников
- Свободное место для моделей: комплект Parakeet занимает примерно 1 ГБ; размер Whisper зависит от выбранной модели

## Установка

### Готовая сборка

Подписанные и нотариально заверенные архивы публикуются в [Framelingo Releases](https://github.com/iosdevsx/Framelingo-releases/tree/main/releases). Скачайте актуальный ZIP, перенесите `Framelingo.app` в папку `Applications` и запустите приложение.

Дальнейшие обновления устанавливаются через встроенный механизм Sparkle — проверку можно запустить вручную из меню приложения.

### Сборка из исходников

```bash
git clone https://github.com/iosdevsx/Framelingo.git
cd Framelingo
mise trust
mise run setup
```

После этого откройте `Framelingo-Tuist.xcworkspace`, выберите схему **Framelingo-Tuist** и запустите проект клавишами `⌘R`. Зависимости FluidAudio и Sparkle загрузятся через Swift Package Manager автоматически. FFmpegKit и arm64‑сборка `whisper-cli` уже находятся в репозитории.

Собрать и проверить проект из терминала можно так:

```bash
mise run doctor
mise run generate
mise run build:macos
mise run test
```

Подробный список команд, устройство generated-файлов и разбор проблем есть в [`docs/tuist.md`](docs/tuist.md).

> [!NOTE]
> Tuist manifests являются единственным источником истины для product workspace.
> Сгенерированные `Framelingo-Tuist.*` коммитить не нужно.

## Локальные модели

Framelingo поддерживает два движка распознавания:

- **Whisper.cpp** — универсальный мультиязычный вариант. Исполняемый файл встроен в приложение, а выбранная модель и опциональная Silero VAD загружаются из настроек.
- **Parakeet** — быстрый движок FluidAudio для 25 европейских языков, включая русский, английский, украинский, немецкий, французский и испанский. Для неподдерживаемого языка приложение может использовать установленный Whisper.

Модели сохраняются локально в каталогах Application Support и кэша FluidAudio. Их не нужно загружать повторно при каждом запуске.

## Форматы

| Назначение | Поддерживаемые форматы |
|---|---|
| Входное видео | MP4, MOV, M4V, WEBM, MKV |
| Импорт субтитров | SRT, VTT, ASS, SSA, TXT, SBV |
| Экспорт субтитров | SRT, WebVTT, TXT |
| Экспорт видео | MP4, H.264 |
| Файл проекта | `.subtitleedit` |

## Технологии

- **SwiftUI + AppKit + AVFoundation** — интерфейс и воспроизведение видео
- **whisper.cpp** — локальное мультиязычное распознавание речи
- **FluidAudio / Parakeet** — ASR и диаризация спикеров
- **FFmpegKit** — локальный SPM-пакет `AppTarget/Modules/Infrastructure/FFmpeg`; подготовка аудио и рендеринг скрыты за API `VideoRendering`
- **Sparkle** — безопасные автоматические обновления
- **XCTest** — модульные тесты таймлайна, импорта, распознавания и экспорта

## Архитектура и структура проекта

Код разделён на независимые локальные Swift Package Manager-пакеты. Каждый
логический модуль экспортирует API-продукт `<Module>` и реализацию
`<Module>Impl` из `Sources/Api` и `Sources/Impl`. Доменные и сервисные пакеты
связываются через API-контракты; concrete implementations выбираются в одном
macOS composition root.

Папки внутри `Modules` нужны только для навигации и отражают ответственность
пакета. Конечные каталоги (`Media`, `ProjectFeature`, `FFmpeg` и остальные) —
настоящие SPM-пакеты со своим `Package.swift`. Xcode находит их прямо в
синхронизированном дереве `AppTarget`; отдельных ссылок на локальные пакеты в
проекте нет. Имена SwiftPM packages/products от группировки не меняются.

`DesignSystem` содержит отдельные `Tokens` (цвета, типографика, отступы,
радиусы), `Components` и environment values. Feature-specific state и логика
таймлайна туда не входят.

Архитектура приложения остаётся MVVM. Настройки, каталог проектов, processing pipelines
и очередь экспорта принадлежат профильным модулям. `ProjectSession` — единственный
владелец открытого проекта, состояния редактора, истории, autosave и проектных эффектов.

`MacAppComposition` собирает репозитории, провайдеры и сервисы через узкие
API-протоколы и передаёт их в feature factories. Это позволяет
подменять эффекты в тестах без service locator и не заставляет протоколизировать
чистые детерминированные вычисления.

`Timeline` и `TimelineFeature` намеренно разделены: первый пакет содержит
platform-neutral модели и алгоритмы монтажа/маппинга/валидации, второй — одну
интерактивную SwiftUI-реализацию, используемую в субтитрах, редакторе и Shorts.

Разрешённые зависимости описаны в
[`docs/module-boundaries.md`](docs/module-boundaries.md), а актуальные topology и
runtime-сценарии генерируются для
[`Architecture Site`](Tools/ArchitectureSite/README.md). Общая карта документации
и источников истины находится в [`docs/index.md`](docs/index.md).

`ProjectSession` уже владеет открытым проектом и его эффектами; `MacApp` и
`IOSApp` являются отдельными product composition roots. Tuist генерирует общий
workspace для macOS, iPhone и iPad.

## Тесты

Проверить отдельный пакет независимо:

```bash
swift build --package-path AppTarget/Modules/Features/TimelineFeature
swift test --package-path AppTarget/Modules/Features/TimelineFeature
```

Проверить macOS application target:

```bash
mise run generate
mise run build:macos
mise run test:macos
```

## Текущее состояние

Framelingo активно развивается. Локальные распознавание, диаризация, редактирование, импорт и экспорт реализованы; провайдер автоматического перевода пока демонстрационный. Переводной текст можно редактировать вручную или импортировать из файла субтитров.

---

<div align="center">
  Сделано для тех, кому нужен полный контроль над субтитрами — прямо на Mac.
</div>
