# Настройка форка: что нужно получить и подставить

После импорта апстрима в дереве остались **плейсхолдеры** вместо кредов Telegram.
Это сделано намеренно: форк не должен использовать и распространять чужие
Firebase-проект, API-ключи и инфраструктуру обновлений.

Ключевое свойство: **в коде и в git нет ни одного секрета**. Все реальные значения
живут только в `Local.xcconfig` — файле, который в `.gitignore` и физически не может
попасть в репозиторий (сканер блокирует такую попытку на этапе коммита).

## 1. Единственный файл, который нужно заполнить

```bash
cp Local.xcconfig.example Local.xcconfig
```

`Local.xcconfig` подключается опционально (`#include?`) в `Telegram-Mac/common.xcconfig`
и в `configurations/{Alpha,Beta,Stable}.xcconfig`, поэтому в чистом клоне сборка
работает и без него.

| Ключ | Что вписать | Откуда |
|---|---|---|
| `API_ID` | целое число | `core.telegram.org/api/obtaining_api_id` |
| `API_HASH` | строка | там же, выдаётся вместе с `API_ID` |
| `BUNDLE_ID` | свой идентификатор приложения | например `ru.geranton93.gergram` |
| `TEAM_ID` | Apple Developer Team ID | Apple Developer Portal |
| `APPCENTER_SECRET` | можно оставить плейсхолдер | краш-репорты отключены |
| `SFEED_URL` | свой канал обновлений | по умолчанию плейсхолдер на `updates.geranton93.dev` |

Значения попадают в приложение через `Info.plist` → `Bundle.main.infoDictionary`,
и читаются в `packages/ApiCredentials/Sources/ApiCredentials/Config.swift`
через `Configuration.credential(...)`. Если ключ не заполнен, в коде остаётся
заглушка, а не значение.

> `apiId`/`apiHash` из апстрима использовать **нельзя**: они принадлежат Telegram,
> опубликованы во всех их клиентах и жёстко ограничены по частоте запросов.

## 2. Идентификаторы подписи (обязательно, иначе не установится)

App Group и идентификаторы целей зашиты в entitlements и pbxproj — их надо заменить
вручную:

| Файл | Что заменить |
|---|---|
| `Telegram-Mac/Telegram-Mac.entitlements` | `6N38VWS5BX.ru.keepcoder.Telegram` → `<TEAM_ID>.<BUNDLE_ID>` |
| `Telegram-Mac/Telegram-Sandbox.entitlements` | то же, вхождения App Group |
| `TelegramShare/TelegramShare.entitlements` | `<TEAM_ID>.<BUNDLE_ID>.TelegramShare` |
| `FocusIntents/FocusIntents.entitlements` | `<TEAM_ID>.<BUNDLE_ID>[.FocusIntents]` |
| `Telegram.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` (4 вхождения) |
| `Telegram-Mac/LocalAuth.swift:78` | хардкод `6N38VWS5BX` — суффикс группы keychain |
| `Telegram-Mac/CallBridge.mm:460` | путь Group Container в логе |

App Group (`<TEAM_ID>.<BUNDLE_ID>`) должен существовать в Apple Developer Portal —
иначе `ApiEnvironment.containerURL` вернёт `nil` и часть данных не переживёт
переустановку.

## 3. Сборка

```bash
brew install cmake ninja openssl@1.1 zlib autoconf libtool automake yasm pkg-config
# в scripts/rebuild заменить "no" на "yes"
sh scripts/configure_frameworks.sh
open Telegram-Mac.xcworkspace
```

Дальше — Xcode, выбрать схему, задать Signing Team и собрать.

## 4. Защита от утечки ключей

`scripts/secret-scan.sh` проверяет три вещи и запускается автоматически
(`core.hooksPath = scripts/hooks`):

| Режим | Что проверяет | Когда вызывается |
|---|---|---|
| `staged` | значения в проиндексированных файлах + попытка закоммитить игнорируемый файл | `pre-commit` |
| `tree` | значения во всех отслеживаемых файлах | `pre-push` |
| `history` | значения в любом коммите истории | `pre-push` |

```bash
scripts/secret-scan.sh all
```

Проверено вручную: подсаженный ключ в отслеживаемом файле блокируется, файл
`Local.xcconfig` в индексе блокируется, чистое дерево и чистая история проходят.

## 5. Ожидаемое поведение до заполнения `Local.xcconfig`

| Симптом | Причина |
|---|---|
| Не проходит авторизация по номеру телефона | не заполнены `API_ID`/`API_HASH` |
| Нет push-уведомлений | Firebase-конфиг с плейсхолдерами |
| Keychain/App Group ошибки | не заменены `TEAM_ID` и entitlements |
| Клиент предлагает обновление с чужого домена | `SFEED_URL` ведёт на плейсхолдер |
