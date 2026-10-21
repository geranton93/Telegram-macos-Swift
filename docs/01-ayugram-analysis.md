# AyuGram Desktop — функциональный анализ

Источник: `github.com/AyuGram/AyuGramDesktop`, ветка `dev`, коммит `0f2a31b` (2026-10-20).
Анализ выполнен по исходному коду, не по описаниям.

## 1. Что это

Форк официального **Telegram Desktop** (tdesktop, Qt/C++) с изолированным слоем AyuGram-логики.
Автор и держатель кода: Radolyn (см. заголовки исходников, `Copyright @Radolyn, 2026`).

AyuGram не является отдельным клиентом: это патч-Set поверх tdesktop, который протаскивает
свою логику через 200 файлов апстрима.

### Метрики кодовой базы

| Метрика | Значение |
|---|---|
| Файлов в изолированной папке `Telegram/SourceFiles/ayu/` | 147 |
| Строк C++/ObjC++ в `ayu/` | 68 599 |
| Файлов апстримного tdesktop, содержащих правки AyuGram | 200 |
| Флагов настроек в `ayu_settings.h` | 115 (`rpl::variable`) |
| Подсистемы в `ayu/features/` | filters, forward, message_shot, streamer_mode, translator |
| Последний коммит на момент анализа | 2026-10-20 (проект активно поддерживается) |

### Структура слоя AyuGram

```
Telegram/SourceFiles/ayu/
├── ayu_settings.h/.cpp        — 115 флагов, 3 группы настроек, JSON-сериализация
├── ayu_state.h/.cpp           — состояние, применение флагов, «залоченные» настройки
├── ayu_worker.h/.cpp          — фоновая обработка
├── ayu_infra.h/.cpp           — инфраструктурные хелперы
├── ayu_url_handlers.h/.cpp    — собственный URL-scheme (tg://user?id=)
├── ayu_lang.h/.cpp            — локализация
├── data/
│   ├── ayu_database.h/.cpp    — SQLite: сообщения, правки, фильтры
│   ├── entities.h             — модели DeletedMessage, EditedMessage, RegexFilter
│   └── messages_storage.h/.cpp— хранение удалённых/изменённых сообщений в памяти и на диске
├── features/
│   ├── filters/               — regex-фильтры сообщений + кэш + UI
│   ├── forward/               — AyuForward, AyuSync (rich-репосты, синхронизация)
│   ├── message_shot/          — Message Shot (рендер переписки в картинку)
│   ├── streamer_mode/         — скрытие окна от screen capture (mac/win/linux)
│   └── translator/            — перевод + провайдеры + html_parser + implementations/
└── ui/                        — настройки AyuGram, стили, userpic, логотип
```

## 2. Три группы настроек

### 2.1 `AyuSettings` — глобальные (115 флагов)

Одна структура на всё приложение. Ключевые блоки:

**Хранение и приватность**
- `saveDeletedMessages` — сохранять удалённые сообщения локально
- `saveMessagesHistory` — сохранять историю сообщений
- `saveForBots` — сохранять и для ботов
- `semiTransparentDeletedMessages` — показывать удалённые сообщения полупрозрачными
- `hideFromBlocked` — скрывать сообщения от заблокированных
- `filtersEnabled`, `filtersEnabledInChats` — regex-фильтры
- `hidePremiumStatuses` — скрывать Premium-статусы

**Приватность интерфейса**
- `disableAds` — отключить рекламу (sponsored messages)
- `disableStories` — отключить stories
- `disableCustomBackgrounds` — отключить кастомные фоны
- `hideNotificationCounters`, `hideNotificationBadge` — скрыть счётчики/бейдж
- `hideAllChatsFolder` — скрыть папку «Все чаты»
- `collapseSimilarChannels`, `hideSimilarChannels` — свернуть/скрыть «похожие каналы»
- `showOnlyAddedEmojisAndStickers` — только добавленные эмодзи/стикеры
- `hideFastShare` — скрыть быстрый доступ к контактам

**Внешний вид**
- `messageBubbleRadius` — радиус скругления пузырей
- `avatarCorners` — скругление аватаров
- `singleCornerRadius` — единый радиус скругления
- `wideMultiplier` — «широкие» сообщения (коэффициент ширины)
- `monoFont` — моноширинный шрифт
- `simpleQuotesAndReplies` — убрать цветные ответы/цитаты
- `removeMessageTail` — убрать «хвосты» сообщений
- `materialSwitches` — Material-стиль переключателей
- `replaceBottomInfoWithIcons` — нижняя инфо-панель сообщения иконками
- `deletedMark`, `editedMark` — свои маркеры «удалено»/«изменено»
- `showMessageSeconds` — показывать секунды в времени сообщений
- `adaptiveCoverColor` — адаптивный цвет обложки
- `showChannelReactions`, `showGroupReactions`, `showPrivateChatReactions` — реакции по типу чата
- `unlimitedRecentStickers` — безлимитные недавние стикеры
- `channelBottomButton` — нижняя кнопка канала (Hidden / MuteUnmute / DiscussWithFallback)

**Поведение**
- `localPremium` — локальный Premium
- `disableOpenLinkWarning` — не предупреждать об открытии ссылок
- `disableNotificationsDelay` — отключить задержку уведомлений
- `spoofWebviewAsAndroid` — выдавать WebView за Android
- `increaseWebviewHeight`, `increaseWebviewWidth` — увеличить размер WebView
- `improveLinkPreviews` — улучшенные превью ссылок
- `quickAdminShortcuts` — быстрые админ-шорткаты
- `disableGreetingSticker` — отключить приветственный стикер
- `crashReporting` — отправка краш-репортов

**Тюнинг UI-элементов**
- Панель ввода: `showAttachButtonInMessageField`, `showCommandsButtonInMessageField`,
  `showEmojiButtonInMessageField`, `showMicrophoneButtonInMessageField`,
  `showAutoDeleteButtonInMessageField`, `showGiftButtonInMessageField`,
  `showAiEditorButtonInMessageField`, `showAttachPopup`, `showEmojiPopup`
- Drawer/меню: `showMyProfileInDrawer`, `showBotsInDrawer`, `showNewGroupInDrawer`,
  `showNewChannelInDrawer`, `showContactsInDrawer`, `showCallsInDrawer`,
  `showSavedMessagesInDrawer`, `showLReadToggleInDrawer`, `showSReadToggleInDrawer`,
  `showNightModeToggleInDrawer`, `showGhostToggleInDrawer`, `showStreamerToggleInDrawer`
- Tray: `showGhostToggleInTray`, `showStreamerToggleInTray`
- Контекстное меню (7 переключателей, значение `Hidden / Visible / VisibleWithModifier`):
  `showReactionsPanelInContextMenu`, `showViewsPanelInContextMenu`,
  `showHideMessageInContextMenu`, `showUserMessagesInContextMenu`,
  `showMessageDetailsInContextMenu`, `showRepeatMessageInContextMenu`,
  `showAddFilterInContextMenu`

**Подтверждения и прочее**
- `stickerConfirmation`, `gifConfirmation`, `voiceConfirmation`, `roundConfirmation` —
  подтверждение отправки медиа (в т.ч. «кружков»)
- `filterZalgo` — фильтр Zalgo-текста
- `showPeerId` — показ ID пира: `Hidden / TelegramApi / BotApi`
- `translationProvider` — `Telegram / Google / Yandex / Native`
- `appIcon` — выбор иконки приложения
- `showMessageShot` — показывать пункт Message Shot

**Прочее**
- `useGlobalGhostMode` — глобальный режим Ghost Mode
- `streamerMode` — скрывать окно от записи экрана
- `shadowBanIds` — набор ID, для которых клиент «-shadow ban»-ится (см. `AyuSettings::isShadowBanned`)

### 2.2 `GhostModeAccountSettings` — per-account, per-session

Самая ценная механика AyuGram. Настройки привязаны к конкретному аккаунту (`AyuSettings::ghost(session)`),
и часть из них может быть «залочена» (`*Locked`) — принудительно включена и не отключаемая пользователем
(например, при входе через определённый сценарий).

| Флаг | Поведение |
|---|---|
| `sendReadMessages` | Не отправлять прочтения сообщений |
| `sendReadStories` | Не отправлять прочтения stories |
| `sendOnlinePackets` | Не отправлять online-пакеты |
| `sendUploadProgress` | Не отправлять прогресс загрузки |
| `sendOfflinePacketAfterOnline` | Отправлять offline-пакет сразу после появления online |
| `markReadAfterAction` | Отмечать прочитанным только после явного действия |
| `useScheduledMessages` | Отправлять через отложенные сообщения при активном Ghost Mode |
| `sendWithoutSound` | `Never / InGhostMode / Always` — отправка без звука |
| `suggestGhostModeBeforeViewingStory` | Предлагать Ghost Mode перед просмотром stories |
| `ghostModeActive` | Флаг активности режима |
| `*Locked` (5 шт.) | Принудительное состояние, не меняется пользователем |

Составная логика в `ayu_settings.h:100`:
```cpp
[[nodiscard]] bool isUseScheduledMessages() const { return isGhostModeActive() && useScheduledMessages(); }
```

### 2.3 `MessageShotSettings` — экспорт переписки

- `showBackground`, `showDate`, `showReactions`, `showHeaderDecorations`,
  `showColorfulReplies`, `revealSpoilers` — что включать в снимок
- `embeddedThemeType` + `embeddedThemeAccentColor` — встроенная тема
- `cloudThemeId / AccessHash / DocumentId / Title / AccountId` — облачная тема из профиля

## 3. Локальное хранилище

Два уровня:

1. **JSON** — настройки (`ayu_settings.cpp`, `to_json/from_json` через `nlohmann::json`).
2. **SQLite** — `ayu/data/ayu_database.h` (движок `sqlite_orm`), 8 таблиц:

| Таблица | Что хранит |
|---|---|
| `SchemaVersion` | версия схемы (миграции) |
| `DeletedMessage` | удалённые сообщения: peer, message_id, дата, текст, entities, медиа |
| `EditedMessage` | ревизии отредактированных сообщений (old_text / new_text) |
| `DeletedDialog` | метаданные по диалогам с удалёнными сообщениями |
| `RegexFilter` | пользовательские фильтры |
| `RegexFilterGlobalExclusion` | глобальные исключения фильтров |
| `SpyMessageRead` | таблица-заглушка, **не заполняется** |
| `SpyMessageContentsRead` | таблица-заглушка, **не заполняется** |

API:
   - `addDeletedMessage` / `getDeletedMessages` (с поиском!) / `hasDeletedMessages` /
     `removeDeletedMessage` / `clearDeletedMessages`
   - `addEditedMessage` / `getEditedMessages` / `hasRevisions` — история правок
   - `addRegexFilter` / `getAllRegexFilters` / `getByDialogId` / `getShared` /
     `updateRegexFilter` / `deleteFilter` — regex-фильтры (общие и per-dialog)
   - `addRegexExclusion` / `getAllFiltersExclusions` — исключения фильтров
   - `moveCurrentDatabase` — миграция БД

Плюс оперативный кэш в памяти: `ayu/data/messages_storage.h/.cpp`.

## 4. Ключевые механики

### Ghost Mode
Глобальный переключатель + per-account настройки. Перехватывает отправку пакетов «я здесь»:
прочтения, typing, online, прогресс загрузки. Реализовано через `ayu_state` — слой,
который фильтрует исходящие вызовы tdesktop и подменяет их поведение.

### Scheduled Messages в Ghost Mode
Отправка сообщения откладывается, чтобы собеседник не увидел мгновенного «прочтения»:
фактически сообщение ставится в очередь отложенных и отправляется позже — получатель
получает уведомление с задержкой, как будто автор был офлайн.

### Streamer Mode
Кроссплатформенная реализация с платформенными бэкендами:
`features/streamer_mode/platform/{mac,win,linux}`.

macOS-реализация (`platform/mac/streamer_mode_mac.mm`) предельно проста:
```objc
void SetWindowCaptureExcluded(not_null<QWidget*> widget, bool excluded) {
    const auto view = reinterpret_cast<NSView*>(widget->winId());
    view.window.sharingType = excluded ? NSWindowSharingNone : NSWindowSharingReadOnly;
}
```
То есть механика — это `NSWindow.sharingType = .none`. В Swift-клиенте это делается одной строкой.

### Message Shot
`features/message_shot/` — рендер переписки в изображение с применением настроек темы
(встроенной или облачной), опциями фона/даты/реакций/декораций/цветных ответов/спойлеров.

### AyuForward / AyuSync
`features/forward/ayu_forward.cpp`, `ayu_forward_rich.cpp`, `ayu_sync.cpp`.

**AyuForward** — «умная» пересылка: сообщения разбиваются на чанки по признаку
`isAyuForwardNeeded(item)` (сообщение удалено / стоит запрет пересылки / у медиа есть TTL).
Такие чанки уходят полной пересылкой (`forwardMessages(..., true, ...)`), обычные —
синхронной пересылкой. Если запрет пересылки стоит на самом собеседнике
(`isFullAyuForwardNeeded`), требуется полная пересылка вместо пересылки с текстом.

**AyuSync** — это **не** синхронизация настроек между устройствами, а набор
синхронных (блокирующих) обёрток над отправкой: `sendMessageSync`, `forwardMessagesSync`.
Кросс-девайсной синхронизации настроек в AyuGram Desktop **нет вообще** — все настройки
лежат локально в JSON, per-account. Если такая синхронизация нужна, её придётся
проектировать с нуля.

### Translator
`features/translator/` — встроенный перевод с 4 провайдерами (Telegram / Google / Yandex / Native),
собственный `html_parser` для разбора ответов и папка `implementations/` с сетевыми клиентами.

### Filters
`features/filters/` — regex-фильтры сообщений: движок, кэш (`filters_cache_controller`),
UI (`filters_controller`), утилиты. Движок — ICU-регулярные выражения Qt
(`QRegularExpression`), не PCRE и не RE2. Фильтры бывают глобальные, per-dialog и общие
(shared), с глобальными исключениями. Дополнительно — `filterZalgo` для отдельного
санитайзера (применяется в 4 местах рендера).

### Точки перехвата Ghost Mode в tdesktop

| Что | Файл:строка | Механика |
|---|---|---|
| Read receipts | `apiwrap.cpp:1457-1476`, `:1503-1513` | Перед формированием пакета прочтения проверяется `AyuSettings::ghost(&session())`; если выключено — пакет **не формируется вовсе**. Механизм `passthrough` позволяет системному коду принудительно отметить прочтение в обход ghost |
| Typing / presence | `api/api_updates.cpp:1002` | Отдельного MTProto-метода «typing» в tdesktop нет — клиент шлёт `updatePresence` со `status=typing`. Флаг `sendOnlinePackets` гасит именно его |
| Upload progress | `api/api_send_progress.cpp:120` | Гасится `uploadProgressC` |
| Stories | `api/api_stories.cpp` | Отдельный флаг `sendReadStories` |
| Mark read after action | `ayu/utils/telegram_helpers.cpp:450-480` | Прочтение откладывается до активного действия |
| Отложенная отправка | `ayu/utils/telegram_helpers.cpp:1577-1591` (`applyGhostScheduling`) | См. ниже |

### Формула задержки в Scheduled Messages (Ghost Mode)

```cpp
if (ghost.isUseScheduledMessages() && !options.scheduled) {
    const auto delay = Core::App().settings().proxy().isEnabled()
        ? (delaySeconds * 6 + 4) / 5   // ceil(delaySeconds * 1.2)
        : delaySeconds;
    options.scheduled = base::unixtime::now() + delay;
}
```

Базовая задержка — `delaySeconds`; при включённом **прокси** умножается на 1.2 с округлением
вверх (компенсация задержки прокси-канала). Если пользователь сам выбрал время отправки,
AyuGram его не перезаписывает. Ephemeral-сообщения (самоуничтожение) пропускаются,
чтобы не ломать TTL-механику. Точки вызова в `apiwrap.cpp`: `:4257` (17 секунд),
`:4510`, `:4762`, `:5370`, `:5657` (альбомы).

### Перевод: провайдеры и инфраструктура

| Провайдер | Как работает |
|---|---|
| Telegram / Native | штатный MTProto-вызов `MTPmessages_TranslateText` |
| Google | прямой HTTP POST `https://translate-pa.googleapis.com/v1/translateHtml`, случайный desktop User-Agent |
| Yandex | POST `https://translate.yandex.net/api/v1/tr.json/translate`, `application/x-www-form-urlencoded` |

Инфраструктура: `TranslateManager` с LRU-кэшем на 500 записей (ключи — по тексту
и по `(peerId, msgId)`), базовый класс `MultiThreadTranslator` с лимитом параллелизма,
3 ретраями и backoff от 1000 мс.

## 5. Взаимодействие с апстримом

AyuGram меняет **200 файлов** tdesktop. Распределение по каталогам:

| Каталог tdesktop | Файлов | Что именно меняется |
|---|---|---|
| `history/` | 45 | список сообщений: удалённые, правки, хвосты, реакции, превью |
| `data/` | 23 | модели сообщений: `PeerMessage`, `MessageFull`, реакции, просмотры |
| `ui/` | 18 | виджеты: пузыри, аватары, панель ввода, стикеры |
| `info/` | 13 | профиль/инфо-разделы: ID пира, автор стикерпака |
| `window/` | 12 | окна: скругления, заголовок, применение Streamer Mode |
| `core/` | 12 | поведение приложения, настройки, URL-обработчики, краш-репорты |
| `settings/` | 11 | регистрация секции AyuGram в настройках |
| `boxes/` | 10 | инфо-панели пиров |
| `api/` | 10 | **перехват сетевого слоя** — главное место Ghost Mode |
| `dialogs/` | 8 | диалоги |
| `chat_helpers/` | 8 | хелперы чатов |
| `platform/` | 7 | per-OS интеграция |
| `media/` | 4 | медиаплеер, превью |

### 5.1 Ключевые точки врезки (api/ и core/)

| Файл | Зачем |
|---|---|
| `api/api_sending.cpp` | отправка сообщений: отложенные в Ghost Mode, отправка без звука |
| `api/api_send_progress.cpp` | прогресс загрузки — Ghost Mode `sendUploadProgress` |
| `api/api_unread_things.cpp` | прочтения — Ghost Mode `sendReadMessages` |
| `api/api_updates.cpp` | входящие апдейты: удалённые и изменённые сообщения |
| `api/api_editing.cpp` | правки сообщений — история правок |
| `api/api_views.cpp`, `api/api_who_reacted.cpp` | реакции и просмотры |
| `core/application.cpp` | поведение приложения, presence/online |
| `core/core_settings.cpp` | интеграция с системой настроек tdesktop |
| `core/local_url_handlers.cpp` | собственный URL-scheme |
| `core/deep_links/deep_links_settings.cpp` | deep links |
| `core/crash_reports.cpp` | crash reporting |

### 5.2 macOS-специфичные врезки

| Файл tdesktop | Что делается | Аналог в Swift-клиенте |
|---|---|---|
| `platform/mac/global_menu_mac.mm` | пункты AyuGram в глобальном меню (drawer) | `SharedAccountContext.statusItem` / меню приложения |
| `platform/mac/tray_mac.mm` | переключатели Ghost Mode и Streamer Mode в трее | `NSStatusItem` в `SharedAccountContext.swift:229` |
| `platform/mac/main_window_mac.mm` | применение Streamer Mode к окну, иконка приложения | `NSWindow.sharingType = .none` |
| `platform/mac/window_title_mac.mm` | заголовок окна | `ChatTitleBarView.swift` |
| `platform/mac/specific_mac_p.mm` | mac-специфика (Taptic Engine и т.п.) | Swift-эквиваленты |

**Практический вывод:** портирование на Swift-клиент — это **не перенос 200 патчей**,
а реализация ~115 фич заново. Ключевые врезки AyuGram в `api/` (прочтения, отправка,
прогресс) в Swift-клиенте лежат в других местах, часть из них — в ядре
(см. `02-macos-swift-analysis.md`).

## 5.3 Состояние кодовой базы AyuGram (на 2026-10-20)

- **Отсутствует заголовочный файл `ayu/ayu_ui_settings.h`** — он подключается шестью
  файлами (`ayu_infra.cpp`, `ayu_settings.cpp`, `ayu_userpic.cpp`, `font_selector.cpp`,
  `settings_appearance.cpp`, `info_peer_gifts_common.cpp`), но отсутствует в дереве
  и в истории git. Нужные символы: `AyuUiSettings::setMonoFont`, `setWideMultiplier`,
  `setMaterialSwitches`, `setAvatarCorners`, `getMonoFont`, `getAvatarCorners`,
  `kMaxAvatarCorners`. **Сборка AyuGram в текущем виде не проходит** — при копировании
  кода в наш форк этот класс нужно написать с нуля.
- **Мёртвые строки, портированные из Android-версии и не задействованные в Desktop:**
  Peek Online, Upload Speed Boost, AyuGram Push Service, WAL Mode, Save Read Date,
  Save Last Seen Date, Kill App, Hide Next Views. Соответствующие таблицы `Spy*` в БД
  существуют, но пусты.
- **Streamer Mode на Linux — заглушка** (пустое тело функции). Реальные реализации:
  macOS (`NSWindowSharingNone`) и Windows (`SetWindowDisplayAffinity`).
- **Taptic Engine и Force Click** — в Desktop-версии отсутствуют (в отличие от Android).
  Force Click реализован как обычный клик с превью (`ayu/ui/components/message_preview.cpp`).

## 6. Что в AyuGram дублирует апстрим Telegram Desktop

По коду и документации следующие фичи по сути повторяют возможности tdesktop,
а не добавляют новые:

- Material-стиль переключателей (tdesktop имеет свои настройки оформления)
- «Jump to beginning» (в апстриме есть кнопка возврата к последнему непрочитанному)
- Скрытие папки «Все чаты» (в апстриме это делается настройкой фильтров чатов)
- Отключение рекламы (в апстриме есть «Hide sponsored messages»)
- Тёмная/светлая тема
- Уведомления и звуки — базовые настройки есть в апстриме

Полезно держать в голове при планировании: часть флагов AyuGram — это не «новые фичи»,
а переключатели поверх уже существующих механизмов.
