# Eyes

Личный видеоредактор для iPhone. Swift, SwiftUI, AVFoundation. План и этапы - в `PLAN.md`.

## Что умеет сейчас (этап 1)

- Список проектов, автосохранение
- Импорт видео из Фото, несколько клипов подряд
- Превью с воспроизведением и перемоткой
- Обрезка начала и конца выбранного клипа по полосе миниатюр
- Перестановка и удаление клипов
- Экспорт склейки в Фото

## Сборка

Нужен Mac с Xcode 16 или новее.

### Через XcodeGen

```bash
brew install xcodegen
cd eyes
xcodegen generate
open Eyes.xcodeproj
```

В Xcode: таргет `Eyes` -> Signing & Capabilities -> выбрать свою команду (Team). Подключить iPhone, выбрать его в списке устройств, нажать Run.

### Без XcodeGen

1. File -> New -> Project -> iOS App, имя `Eyes`, интерфейс SwiftUI, язык Swift.
2. Удалить созданные `ContentView.swift` и `EyesApp.swift`.
3. Перетащить папку `Eyes/` из репозитория в проект (Create groups, добавить в таргет).
4. В Info добавить ключ `Privacy - Photo Library Additions Usage Description`.
5. Minimum Deployments: iOS 17.0.

## Установка на телефон без платного аккаунта

С бесплатным Apple ID приложение работает 7 дней, затем его нужно переустановить из Xcode. С платным аккаунтом разработчика можно ставить через TestFlight без ограничения.

## Структура

```
Eyes/
  App/        точка входа
  Models/     Project, Clip
  Storage/    ProjectStore (JSON), MediaLibrary (файлы видео)
  Render/     CompositionBuilder: Project -> AVMutableComposition
  Export/     VideoExporter, PhotoLibrarySaver
  Features/   экраны: ProjectList, Editor, Export
  Support/    CMTime и форматирование времени
```
