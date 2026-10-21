# Telegram для macOS (Swift) — архитектура и точки расширения

Источник: `github.com/TelegramOrg/Telegram-macos-Swift` (официальный репозиторий), свежий клон,
коммит `579cebbf` (2025-07-29). Анализ выполнен по исходному коду.

**Родословная репозитория:** `TelegramOrg/Telegram-macos-Swift` — официальное зеркало
проекта `overtake/TelegramSwift` (сообщество, во главе с «overtake»), на который Telegram
ссылается с macos.telegram.org. Лицензия — **GPL-2.0**, то есть форк разрешён
(подробности в разделе 6.2).

## 1. Общая картина

| Метрика | Значение |
|---|---|
| Swift-файлов в `Telegram-Mac/` | 951 (~440 770 строк) |
| Swift-файлов в `packages/` | 291 |
| SwiftPM-пакетов | 56 |
| Подмодулей (C/ObjC-библиотеки) | 8 |
| Размер клона | ~136 МБ |

Это **нативный Swift-клиент**, а не обёртка над tdesktop: тот же UIKit-подход, что и в iOS-клиенте
Telegram, но с macOS-спецификой (AppKit + UIKit-мост, NSWindow, Dock, меню-бар).

### 1.1 Два важных нюанса репозитория

1. **`packages/TelegramUI/` в git-дереве пуст** — содержит только `.swiftpm/`. Весь UI-код
   лежит в `Telegram-Mac/` (943 .swift в корне + 20 поддиректорий). Это не баг: так устроен
   текущий мак-клиент.
2. **Все 8 сабмодулей пусты** при shallow-клоне без `--recursive`. Без
   `git submodule update --init --recursive` **сборка невозможна**: `Telegram-Mac/` содержит
   773 импорта `TelegramCore` и 677 импорта `Postbox`. Пин ядра —
   `a24bbe45f9861f736a79916a50898512f751e0dc` из `overtake/Telegram-iOS`.

### 1.2 Клиент использует новый API `TelegramEngine`

Обращения к ядру идут через `engine.*` (непубличный API `TelegramEngine`):
`engine.peers.*` (429 вызовов), `engine.messages.*` (202), `engine.data.*` (156),
`engine.stickers.*` (74), `engine.payments.*` (73), `engine.accountData.*` (64),
`engine.auth.*` (38), `engine.calls.*` (37), `engine.privacy.*` (26), `engine.account.*` (26).

**Риск:** `engine.*` — непубличный API, он ломается при обновлении ядра.
При форке это нужно учитывать при оценке сопровождения.

### Структура

```
Telegram-macos-Swift/
├── Telegram-Mac/              — код приложения (~951 .swift)
│   ├── AccountContext.swift   — контекст аккаунта (настройки, premium, подписки)
│   ├── SharedAccountContext.swift — разделяемое состояние + меню-бар (NSStatusItem)
│   ├── ChatController.swift   — экран чата
│   ├── ChatMessageItem.swift  — модель сообщения (рендер-логика)
│   ├── ChatMessageView.swift  — представление сообщения
│   ├── ChatRowView.swift      — строка списка сообщений
│   ├── ChatInputView.swift    — панель ввода
│   ├── ChatInputActionsView / ChatInputAttachView / ChatInputMenuView
│   ├── ChatMessageMenuItems.swift — контекстное меню сообщения
│   ├── ChatListController / ChatListRowView — список чатов
│   ├── ChatScheduleController.swift — отложенные сообщения
│   ├── SimilarChannelsController.swift — «похожие каналы»
│   ├── UNUserNotifications.swift — уведомления (UNUserNotificationCenter)
│   ├── NotificationPreferencesController.swift
│   ├── GeneralSettingsViewController.swift и др. — разделы настроек
│   ├── FastSettings.swift     — быстрый доступ к настройкам
│   └── SettingsSearchableItems.swift — индекс поиска по настройкам
├── packages/                  — SwiftPM-пакеты
│   ├── TelegramUI/            — основной UI-слой (самый крупный)
│   ├── TelegramMedia, TelegramSystem, TelegramIconsTheme, ThemeSettings
│   ├── InAppSettings/         — модели и персистентность настроек
│   ├── Translate/             — перевод (нативно есть!)
│   ├── Reactions/             — реакции
│   ├── InAppPurchaseManager/  — покупки и Premium
│   ├── Dock/                  — интеграция с Dock
│   ├── Strings, Localization, Colors, ColorPalette
│   ├── TGUIKit, Svg, InputView, OCR, DetectSpeech, HotKey, ...
├── core-xprojects/            — C/ObjC: ffmpeg, openssl, webrtc, tde2e
└── submodules/                — Sparkle, libprisma, libtgvoip, regex, rlottie,
                                 telegram-ios (ядро MTProto), tg_owt, tgcalls
```

## 2. Слои

```
┌─────────────────────────────────────────────┐
│  Telegram-Mac/            — экраны, контроллеры, AppKit-интеграция
├─────────────────────────────────────────────┤
│  packages/TelegramUI/     — переиспользуемые UI-компоненты
├─────────────────────────────────────────────┤
│  packages/InAppSettings/  — модели настроек (Codable → UserDefaults)
├─────────────────────────────────────────────┤
│  submodules/telegram-ios  — MTProto, Postbox (хранилище), account manager
├─────────────────────────────────────────────┤
│  core-xprojects, submodules — ffmpeg, webrtc, tgcalls, Sparkle
└─────────────────────────────────────────────┘
```

**Важное следствие:** UI-слой форка (то, где живёт большинство фич AyuGram — внешний вид,
панель ввода, контекстные меню, настройки) полностью на Swift и не требует правок ядра.
Ядро нужно трогать только для Ghost Mode.

## 3. Ключевые точки расширения (проверено в коде)

### 3.1 Настройки — чистая точка входа

`packages/InAppSettings/` хранит настройки как `Codable`-структуры в `UserDefaults`
с типизированными ключами (`ApplicationSpecificPreferencesKeys`).
`Telegram-Mac/FastSettings.swift` — глобальный фасад доступа.
`SettingsSearchableItems.swift` — индекс для поиска по настройкам.

**Для форка:** одна новая Codable-структура (например `GergramSettings`) + ключ +
раздел настроек в стиле `GeneralSettingsViewController` + регистрация в поиске.
Стоимость добавления 100+ флагов — низкая, в отличие от Qt-подхода AyuGram.

### 3.2 Premium — одна точка

```swift
// Telegram-Mac/AccountContext.swift:539
private(set) var isPremium: Bool = false {
    didSet {
        #if !SHARE
        self.reactions.isPremium = isPremium
        #endif
    }
}

// Telegram-Mac/AccountContext.swift:547
var premiumIsBlocked: Bool {
    return self.premiumLimits.premium_purchase_blocked
}
```

Весь клиент спрашивает премиум через `context.isPremium`.
**Local Premium = переопределить этот флаг** (или добавить `|| gergramSettings.localPremium`).
Это самая дешёвая фича из всего списка.

### 3.3 Typing — перехват на уровне приложения

```swift
// Telegram-Mac/ChatInputView.swift:904
chatInteraction.context.account.updateLocalInputActivity(
    peerId: .init(peerId: peer.id, category: chatInteraction.mode.activityCategory(...)),
    activity: .typingText,
    isPresent: isPresent
)

// Telegram-Mac/ChatInputView.swift:220 — снятие активности
interaction.context.account.updateLocalInputActivity(..., activity: .typingText, isPresent: false)
```

**Ghost Mode «не отправлять typing»** — перехват этого вызова на уровне UI-слоя
работает: ядро превращает активность в RPC. Оговорка: у ядра есть и другие пути
отправки активности (например, при загрузке файлов), поэтому полное подавление
требует правки ядра.

### 3.4 Read receipts — 3 точки в Swift, но надёжнее патч ядра

Отправка прочтений инициируется из Swift-��лоя в трёх местах:

```swift
// Telegram-Mac/AccountContext.swift:1363-1372
engine.messages.applyMaxReadIndexInteractively(index: ...)

// Telegram-Mac/ChatController.swift:2637-2646
engine.messages.keepMessageCountersSyncrhonized(...)
```

Дальше цепочка уходит в ядро:
`ApplyMaxReadIndexInteractively` → `stateManager.notifyAppliedIncomingReadMessages([index.id])`
→ `State/SynchronizePeerReadState` → RPC `channels.readHistory` (каналы) /
`messages.readHistory` (чаты) / `messages.readEncryptedHistory` (секрет-чаты).

**Подавить отправку можно из Swift**, не вызывая эти методы. Но надёжный вариант —
патч ядра: клиент может инициировать прочтение и из других путей.

### 3.5 Online-статус и upload progress — только в ядре

В Swift-слое нет ни `setUserOnline`, ни `sendTyping`, ни отправки прогресса загрузки —
это целиком `telegram-ios` (`ManagedAccountPresence` → `account.updateStatus(offline:)`,
`AccountStateManager`, upload-менеджеры).

**Следствие:** Ghost Mode в части online/typing/upload-progress требует собственного
форка подмодуля `telegram-ios` (патчить его коммиты и тянуть за собой в обновлениях).
Это основная техническая сложность проекта, но объём патча — единицы функций, а не
200 файлов, как в AyuGram.

### 3.6 Уведомления

`Telegram-Mac/UNUserNotifications.swift` — системные уведомления через
`UNUserNotificationCenter`: категории, `replyCategory` (быстрый ответ),
`badge`, `sound`, удаление доставленных.
`NotificationPreferencesController.swift` — настройки уведомлений.

Пункт AyuGram «отключить задержку уведомлений» на macOS частично неприменим:
задержку задаёт система. Вариант для форка — собственные in-app баннеры
поверх окна.

### 3.7 Меню-бар и Dock

```swift
// Telegram-Mac/SharedAccountContext.swift:145
private var statusItem: NSStatusItem?
// :229
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
// :223
statusItem?.menu = menu
```

Есть готовый `NSStatusItem` — это прямой аналог трея AyuGram.
Переключатели Ghost Mode / Streamer Mode / тёмная тема размещаются здесь.
Плюс пакет `packages/Dock/` для Dock-интеграции.

### 3.8 Streamer Mode — одна строка

В текущем клиенте `NSWindow.sharingType` **не используется нигде** (проверено ripgrep) —
фичи нет. Реализация в Swift:

```swift
window.sharingType = enabled ? .none : .readOnly
```

AyuGram на macOS делает ровно то же самое через `NSWindowSharingNone`
(`ayu/features/streamer_mode/platform/mac/streamer_mode_mac.mm`).

### 3.9 Контекстное меню, панель ввода, список чатов

- `ChatMessageMenuItems.swift` — построение меню сообщения (те самые 7 переключаемых пунктов AyuGram)
- `ChatInputView.swift`, `ChatInputActionsView.swift`, `ChatInputAttachView.swift`, `ChatInputMenuView.swift` — панель ввода (кнопки скрытия)
- `ChatListController.swift`, `ChatListRowView.swift`, `ChatListFilterController.swift` — список чатов и папки
- `ChatMessageItem.swift`, `ChatMessageView.swift`, `ChatRowView.swift` — рендер сообщений (радиусы, шрифты, ширина, секунды, хвосты)

### 3.10 Точные точки для остальных механик (найдены в коде)

| Механика | Файл:строка | Что делаем |
|---|---|---|
| Прочтение stories | `StoryChatContent.swift:1314, 1615, 1972` → `engine.messages.markStoryAsSeen` | Подавляем вызов |
| Отложенные сообщения | `ChatController.swift:4095-4107` (`scheduleWhenOnlineDate`), `:3849` (`scheduleTime:`), `ChatScheduleController.swift` | Переиспользуем под Ghost Mode |
| Предупреждение о story | `StoryListView.swift:146`, `ChatController.swift:4617`, `StoryModalController.swift:382, 2976` | Показываем модалку подтверждения |
| «Прочитать все» | `engine.messages.markAllChatsAsReadInteractively` (в engine-API) — UI-кнопки в клиенте нет | Добавляем кнопку |
| Широкие сообщения | `ChatRowItem.swift:332-334` (`widthForContent = min(800, width)`) | Меняем константу |
| Моноширинный шрифт | `packages/TGUIKit/Sources/TGFont.swift:109` (`NSFont.normal(_:)`), `:116` (`normalMonospaced`) | Единая точка подстановки шрифта |
| Секунды в сообщениях | `ChatRowItem.swift:2371-2376` (`dateFormatter.string(from:)`) | Добавляем формат с секундами |
| «Хвосты» сообщений | `ChatRowItem.swift:1953-1958` (`neighbors: .none / .both`), `ChatMessageBubbleImages.swift` | Меняем выбор иконки хвоста |
| Канал-бейдж | `FastSettings.swift:237` (`hasHashtagChannelBadge`) | Флаг уже есть |
| ID пира в профиле | `GroupInfoEntries.swift:1849-1855` (`case let .peerId(_, value, viewType)` → «PEER ID») | **Уже реализовано** |
| Бейдж приложения | `GlobalBadgeNode.swift:148`, `DockControl.swift:87` (`settings.iconSelected`) | Переключатель |
| Детали сообщения | `MessageReadMenuItem.swift:210` → `engine.messages.messageReadStats(id:)` | Уже есть |
| Перемотка голосовых | `packages/TelegramMedia/Sources/MediaPlayer.swift:207-297` (`seek(timestamp:)`) | Примитив есть, нужен UI |
| Контекстное меню | `ChatMessageMenuItems.swift:253` (`chatMenuItems(for:...) -> Signal<[ContextMenuItem], NoError>`) | Единая фабрика меню |
| Material-переключатели | `ReactionsWindowController.swift:55`, `AddReactionManager.swift:552, 1272` (`visualEffect.material`) | Переключатель |
| Копирование контента | `GroupInfoEntries.swift:1853` (`canCopy: true`), ядро `Peers/CopyProtection.swift` | Переключатель |
| URL-сcheme | `AppDelegate.swift:232` (`kAEGetURL`), `:1329` (`handleURLEvent`), `InAppLinks.swift:140, 1745` | Добавляем ветку `tg://user?id=` |

**Чего в клиенте нет и придётся писать с нуля:** jump to beginning (в клиенте только
scroll-to-bottom), масштабирование ленты (zoom), история ссылок, удаление всех чатов
(массово — в ядре), скруглённые/круглые стикеры (рендер в ядре).

## 4. Что в macOS-клиенте уже есть (переносить не нужно)

| Фича AyuGram | Статус в macOS-клиенте | Файл |
|---|---|---|
| Перевод сообщений | **Есть нативно** (пакет `Translate`) | `packages/Translate`, `TranslateTableRowItem.swift` |
| Отложенные сообщения | **Есть нативно** | `ChatScheduleController.swift` |
| Похожие каналы (экран) | **Есть нативно** | `SimilarChannelsController.swift` |
| Счётчик непрочитанных в уведомлениях | **Есть нативно** (toggle) | `NotificationPreferencesController.swift` |
| Stories | **Есть нативно** | — |
| Premium / покупки | **Есть нативно** | `packages/InAppPurchaseManager` |
| Тёмная тема | **Есть нативно** | `packages/ThemeSettings` |
| Реакции | **Есть нативно** | `packages/Reactions` |
| Спонсорские сообщения (реклама) | **Есть нативно** (скрытие через настройки) | — |
| Конфигурация панели ввода | Частично (свои настройки есть) | `ChatInputView` |
| Иконка приложения (Dark/Blue/Black) | **Есть нативно** (AlternateIcons + галерея) | `DockControl.swift:87`, `DockIconRowItem.swift` |
| ID пира в профиле | **Уже есть** (пункт «PEER ID») | `GroupInfoEntries.swift:1849-1855` |
| Канал-бейдж (хештег-канал) | **Есть нативно** | `FastSettings.swift:237` |
| Скрытие «похожих каналов» | **Часть в ядре**: `engine.peers.toggleRecommendedChannelsHidden` | `ChatChannelSuggestView.swift:42` |
| Бейдж и счётчики на иконке | **Есть нативно** | `GlobalBadgeNode.swift:148`, `InAppNotificationSettings.swift:111` |
| Детали сообщения (кто прочитал) | **Есть нативно** | `MessageReadMenuItem.swift:210` |
| Копирование/защита контента | **Есть нативно** | `GroupInfoEntries.swift:1853`, ядро `CopyProtection.swift` |
| Движок «прочитать все» | **Есть в engine-API** (UI-кнопки нет) | `engine.messages.markAllChatsAsReadInteractively` |
| Реакции, счётчики, таймеры | **Есть нативно** | `packages/Reactions`, `AddReactionManager.swift` |
| Перемотка голосовых (примитив) | **Частично** — `seek()` есть, UI-скроллбар в ядре | `packages/TelegramMedia/Sources/MediaPlayer.swift:207-297` |

Вывод: ~18 из ~109 фич AyuGram уже реализованы в апстриме macOS-клиента.
Их нужно лишь «переключить» нашим флагом, а не писать заново.

## 5. Чего в клиенте нет (нужно реализовывать полностью)

- Ghost Mode — online-пакеты, upload progress (typing и прочтения подавляются из Swift)
- Анти-Recall: хранение удалённых сообщений, просмотр удалённых, история правок
- Streamer Mode
- Message Shot (рендер переписки в изображение)
- Regex-фильтры сообщений + Zalgo-санитайзер
- AyuSync / AyuForward (rich-forward, синхронизация настроек между устройствами)
- Локальный премиум (как флаг — дёшево)
- Пользовательский шрифт / моноширинный шрифт (в мак-клиенте настраивается только размер)
- Jump to beginning, масштабирование ленты (zoom), история ссылок, массовое удаление чатов
- Подтверждения отправки (стикер / GIF / голосовое / кружок)
- Настройки радиуса скругления пузырей и аватаров
- «Широкие» сообщения (wideMultiplier)
- Кастомный URL-scheme `tg://user?id=`
- Скрытие/сворачивание панелей интерфейса по аналогии с AyuGram Drawer
- Маркеры «удалено»/«изменено» (у нас уже есть дефолтные, но не настраиваемые)

## 6. Особенности и риски форка

### 6.1 Обязательные шаги

```bash
git clone https://github.com/TelegramOrg/Telegram-macos-Swift.git --recurse-submodules
git submodule update --init --recursive
```

Примечание: `INSTALL.md` в самом официальном зеркале предписывает клонировать
`overtake/TelegramSwift` — то есть сам Telegram считает основным репозиторием проекта
именно его, а `TelegramOrg/Telegram-macos-Swift` использует как зеркало.
Workspace-конфиг (`Telegram-Mac.xcworkspace/xcshareddata/Telegram-Mac.xcscmblueprint`)
тоже указывает на `github.com:overtake/TelegramSwift.git`.

Без `submodules/telegram-ios` сборка невозможна (773 импорта `TelegramCore`,
677 импорта `Postbox`). Также пусты: `Sparkle` (подключён в `Telegram-Mac.xcworkspace`),
`tg_owt`, `tgcalls`, `libtgvoip`, `rlottie`, `libprisma`, `regex`, `CodeSyntax`, `RLottie_Xcode`.

### 6.2 Откуда форкать и как обновлять

Репозиторий `TelegramOrg/Telegram-macos-Swift` — **зеркало** (на GitHub он помечен
`fork: True`) проекта `overtake/TelegramSwift`, который ведёт сообщество во главе
с «overtake» и на который Telegram официально ссылается с macos.telegram.org.

| Репозиторий | Роль | Ветки |
|---|---|---|
| `TelegramOrg/Telegram-macos-Swift` | официальное зеркало | только `master` (`579cebbf`, 2025-07-29) |
| `overtake/TelegramSwift` | основной репозиторий проекта | `master`, `release` (`76ff8e42`, 2025-07-31), `appstore`, `7.0.1`, `arm`, `group-calls`, `long-preview` |

`master` в обоих репозиториях сейчас идентичен. Актуальные релизы лежат в ветке `release`
и `appstore` основного репозитория.

**Рекомендация:** базу форка взять из `overtake/TelegramSwift` — именно его Telegram
предписывает клонировать в своём же `INSTALL.md`, и там лежат релизные ветки.
`TelegramOrg/Telegram-macos-Swift` использовать как зеркало для сверки: `master`
в обоих репозиториях идентичен, но в зеркале есть только `master`, а в основном
репозитории — ещё и `release` / `appstore` / `7.0.1` / `arm`.
Ядро — свой форк `overtake/Telegram-iOS` (пин `a24bbe45f9861f736a79916a50898512f751e0dc`).

### 6.3 Что заменить (INSTALL.md, раздел «If you want to develop a fork»)

| Что | Где | Текущее значение |
|---|---|---|
| Bundle ID | `packages/ApiCredentials/Sources/ApiCredentials/Config.swift:12-14` | `ru.keepcoder.Telegram` |
| Team ID | там же, `:17-19` | `6N38VWS5BX` |
| API ID / API hash | там же, `:4-10` | встроенный `apiId`/`apiHash` апстрима — использовать нельзя, нужны свои (значения в апстриме заменены на плейсхолдеры) |
| App Group | `ApiCredentials/Config.swift` (`ApiEnvironment.group`) | нужен новый App Group в Apple Developer Portal |
| SFEED_URL / APPCENTER_SECRET | `configurations/{Stable,Beta,Alpha,AppStore}.xcconfig` | `https://osx.telegram.org/updates/versions.xml` и секрет App Center — заменить или отключить Sparkle |

Остальные вхождения `ru.keepcoder` искать по `Configurations`, `*.entitlements`, `Info.plist`.

### 6.4 Подпись, entitlements, иконки, сборка

- Entitlements: `Telegram-Mac/Telegram-Mac.entitlements`, `Telegram-Mac/Telegram-Sandbox.entitlements`,
  `TelegramShare/TelegramShare.entitlements`, `FocusIntents/FocusIntents.entitlements` —
  во всех заменить Team ID / App Group / Keychain-группу.
- `FocusIntents` — отдельная цель с bundle id `teamId + "." + bundleId + ".FocusIntents"`.
- Иконки: `Telegram-Mac/Assets.xcassets` + набор `TelegramApplicationIcons`
  (используется `DockIconRowItem.swift` / `DockControl.swift`) — при замене поправить enum.
- Сборка: `scripts/configure_frameworks.sh` + `scripts/rebuild` (переключить `"no"` -> `"yes"`).
  Homebrew-зависимости: `cmake ninja openssl@1.1 zlib autoconf libtool automake yasm pkg-config`.
- Workspace: `Telegram-Mac.xcworkspace`; конфигурации `configurations/{Alpha,AppStore,Beta,Stable}.xcconfig`
  + `Telegram-Mac/common.xcconfig`.

### 6.5 Главные риски

1. **Два репозитория под сопровождением.** `Telegram-macos-Swift` (UI) и `Telegram-iOS`
   (ядро, форк `overtake/Telegram-iOS`) обновляются независимо. Фичи уровня ядра
   (typing, presence, upload-progress, стиль стикеров, zoom ленты) тянут за собой merge
   с обоими.
2. **Ядро `telegram-ios` — самая хрупкая точка.** `Telegram-iOS` обновляется ежедневно,
   любой патч в `AccountStateManager` / `ApplyMaxReadIndexInteractively` конфликтует при
   каждом rebase. Митигация: патчи минимальные, в отдельных файлах.
3. **Точки конфликтов в Swift-слое:** `ChatRowItem.swift` (3978 строк),
   `ChatController.swift` (~10 000 строк), `AccountContext.swift` (986 строк).
   Наши изменения — в отдельные пакеты (`packages/Gergram*`), а не в размазанные правки.
4. **`engine.*` — непубличный API** ядра, ломается при обновлении ядра.
5. **Нет тестовой инфраструктуры.** Unit-тестов для `Telegram-Mac/` нет — каждая фича
   проверяется вручную, что добавляет к оценке 15-20 %.
6. **Юридический аспект — в пользу форка.** Swift-клиент распространяется под **GPL-2.0**,
   а не как proprietary-код (proprietary был старый Objective-C клиент, репозиторий
   `TelegramOrg/old-Telegram-macos-old`). GPL-2.0 прямо разрешает форк, модификацию и
   публичную раздачу — при соблюдении условий, которые Telegram перечислил сам
   в README, раздел «Forking»:
   1. **получить собственный API ID** (это же требование `core.telegram.org/api/obtaining_api_id`);
   2. **не называть форк «Telegram»** либо явно обозначить его как неофициальный;
   3. **не использовать стандартный логотип** (белый бумажный самолётик в синем круге);
   4. **соблюдать рекомендации по безопасности** `core.telegram.org/mtproto/security_guidelines`;
   5. **публиковать исходный код** — этого требует сама GPL.

   Практически: наш форк держим тот же GPL-2.0, публикуем исходники, берём свои API-ключи
   и меняем название и иконку. Никаких юридических блокеров для форка нет.
7. **Двухфакторная аутентификация / сессии.** При переходе на свой bundle id потребуется
   перелогинирование и тестирование авторизации.
