<div align="center">
  <img src="Framelingo/Assets.xcassets/AppIcon.appiconset/appicon.png" width="128" height="128" alt="Framelingo icon">

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
- Xcode 26.3 или совместимая более новая версия — только для сборки из исходников
- Свободное место для моделей: комплект Parakeet занимает примерно 1 ГБ; размер Whisper зависит от выбранной модели

## Установка

### Готовая сборка

Подписанные и нотариально заверенные архивы публикуются в [Framelingo Releases](https://github.com/iosdevsx/Framelingo-releases/tree/main/releases). Скачайте актуальный ZIP, перенесите `Framelingo.app` в папку `Applications` и запустите приложение.

Дальнейшие обновления устанавливаются через встроенный механизм Sparkle — проверку можно запустить вручную из меню приложения.

### Сборка из исходников

```bash
git clone https://github.com/iosdevsx/Framelingo.git
cd Framelingo
open Framelingo.xcodeproj
```

В Xcode выберите схему **Framelingo** и запустите проект клавишами `⌘R`. Зависимости FluidAudio и Sparkle загрузятся через Swift Package Manager автоматически. FFmpegKit и arm64‑сборка `whisper-cli` уже находятся в репозитории.

Собрать проект из терминала можно так:

```bash
xcodebuild \
  -project Framelingo.xcodeproj \
  -scheme Framelingo \
  -destination 'platform=macOS,arch=arm64' \
  build
```

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
- **FFmpegKit** — локальный SPM-пакет `AppTarget/Modules/FFmpeg`; подготовка аудио и рендеринг скрыты за API `VideoRendering`
- **Sparkle** — безопасные автоматические обновления
- **XCTest** — модульные тесты таймлайна, импорта, распознавания и экспорта

## Архитектура и структура проекта

Код разделён на независимые локальные Swift Package Manager-пакеты. Каждый
логический модуль экспортирует API-продукт `<Module>` и реализацию
`<Module>Impl` из `Sources/Api` и `Sources/Impl`. Доменные и сервисные пакеты
связываются через API-контракты; concrete implementations выбираются в одном
macOS composition root.

```text
AppTarget/
├── FramelingoApp.swift                           # тонкий @main target
└── Modules/
    ├── Subtitles, Timeline, Shorts, SpeakerAnalysis  # domain
    ├── Media, Translation, SpeechToText              # processing
    ├── VideoRendering, VideoExport, Project, ProjectSession, Settings
    ├── DesignSystem                                  # tokens + shared components
    ├── HomeFeature, ProjectFeature, SettingsFeature, ExportFeature
    ├── SubtitleEditorFeature, TimelineFeature, PlayerFeature, ShortsFeature
    ├── MacFeature                                    # macOS composition
    └── FFmpeg                                        # vendor binary integration

Framelingo/              # неизменённый behavioral baseline миграции
BundledTools/Whisper/    # ресурс macOS-приложения
```

`DesignSystem` содержит отдельные `Tokens` (цвета, типографика, отступы,
радиусы), `Components` и environment values. Feature-specific state и логика
таймлайна туда не входят.

Архитектура приложения остаётся MVVM. Настройки, каталог проектов, processing pipelines
и очередь экспорта принадлежат профильным модулям; `ProjectViewModel` пока владеет рабочим состоянием редактора, а
`ProjectViewModel.project.subtitles` является единственным production-источником
текста и таймингов субтитров. Новый platform-neutral `ProjectSession` уже задаёт
транзакции, историю и autosave для следующего шага миграции, но пока не подключён
к рабочему экрану и не создаёт второго владельца документа.

`MacCompositionRoot` собирает репозитории, провайдеры и сервисы через узкие
API-протоколы и передаёт их в ViewModel/feature assemblies. Это позволяет
подменять эффекты в тестах без service locator и не заставляет протоколизировать
чистые детерминированные вычисления.

`Timeline` и `TimelineFeature` намеренно разделены: первый пакет содержит
platform-neutral модели и алгоритмы монтажа/маппинга/валидации, второй — одну
интерактивную SwiftUI-реализацию, используемую в субтитрах, редакторе и Shorts.

Полный граф владения и разрешённых зависимостей описан в
[`module-graph.md`](openspec/changes/modularize-codebase-with-spm/module-graph.md),
а правила миграции — в OpenSpec change `modularize-codebase-with-spm`.

Следующие архитектурные шаги — переключение редактирования и эффектов на готовый ProjectSession,
централизация Mac composition и добавление iOS composition. Tuist пока отложен. Сейчас checked-in Xcode-проект
собирает macOS shell из `MacFeatureImpl`. Доменные границы уже не завязаны на
AppKit, но адаптация существующих SwiftUI/AppKit interaction seams под iOS
будет отдельной задачей, а не скрытой частью модуляризации.

## Тесты

Проверить отдельный пакет независимо:

```bash
swift build --package-path AppTarget/Modules/TimelineFeature
swift test --package-path AppTarget/Modules/TimelineFeature
```

Проверить macOS application target:

```bash
xcodebuild build \
  -project Framelingo.xcodeproj \
  -scheme Framelingo \
  -destination 'platform=macOS,arch=arm64'

xcodebuild test \
  -project Framelingo.xcodeproj \
  -scheme Framelingo \
  -destination 'platform=macOS,arch=arm64'
```

## Текущее состояние

Framelingo активно развивается. Локальные распознавание, диаризация, редактирование, импорт и экспорт реализованы; провайдер автоматического перевода пока демонстрационный. Переводной текст можно редактировать вручную или импортировать из файла субтитров.

---

<div align="center">
  Сделано для тех, кому нужен полный контроль над субтитрами — прямо на Mac.
</div>
