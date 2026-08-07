# ProjectSession

`ProjectSession` — это одно место, где живёт открытый проект во время редактирования. Модуль следит, чтобы изменение документа применялось целиком, undo/redo не расходились с текущим состоянием, а autosave не сохранял устаревшую копию после переключения на другой проект.

В `ProjectSession` лежит публичный контракт: неизменяемые снимки состояния, открытие и закрытие документа, история, группы длительных взаимодействий и явное сохранение. В `ProjectSessionImpl` находится реализация транзакций, истории и отложенного сохранения.

## Владение и границы

`ProjectSession` является production-владельцем активного `Project`, истории,
autosave и project-scoped processing effects. `MacApp` и `IOSApp` создают по одной
сессии на workspace, а `ProjectFeature` работает с ней через узкие публичные
протоколы и immutable snapshots.

Модуль ничего не знает про SwiftUI, AppKit или UIKit. Presentation models могут
хранить выбор, состояние панелей и другие UI-детали, но не копию редактируемого
проекта. Все изменения субтитров и таймлайна проходят через session operations.

## Тесты

Тесты проверяют транзакции, bounded history, interaction groups, autosave,
переключение проектов и координацию processing effects.

```sh
swift test --package-path AppTarget/Modules/Workflows/ProjectSession
```
