# Настройка форка: что нужно получить и подставить

После импорта апстрима в дереве остались **плейсхолдеры** вместо кредов Telegram.
Это сделано намеренно: форк не должен использовать и распространять чужие
Firebase-проект, API-ключи и инфраструктуру обновлений. Без заполнения полей
клиент собирается, но не авторизуется и не принимает push.

## 1. Обязательно для запуска

| Что | Где | Как получить |
|---|---|---|
| `apiId` (Int32) | `packages/ApiCredentials/Sources/ApiCredentials/Config.swift` | `core.telegram.org/api/obtaining_api_id` — регистрация приложения |
| `apiHash` (String) | там же | там же, выдаётся вместе с `apiId` |
| `teamId` (String) | там же | Apple Developer Portal → Team ID |
| `bundleId` (String) | там же | свой, например `ru.geranton93.gergram` |
| Firebase-проект | `Telegram-Mac/GoogleService-Info.plist` | Firebase Console → iOS-приложение с тем же bundle id → скачать `GoogleService-Info.plist` |
| App Center secret | `configurations/{Alpha,Beta,Stable}.xcconfig` | можно оставить плейсхолдер и отключить краш-репорты |
| `SFEED_URL` | там же | свой канал обновлений; по умолчанию плейсхолдер на `updates.geranton93.dev` |

> Значения `apiId`/`apiHash` из апстрима использовать **нельзя**: они принадлежат
> Telegram, публикуются во всех их клиентах и жёстко ограничены по частоте запросов.

## 2. Обязательно для установки (иначе не соберётся на устройстве)

Идентификаторы апстрима нужно заменить в этих местах — они зашиты в подпись и
App Group:

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

## 4. Проверка безопасности перед пушем

```bash
scripts/secret-scan.sh all
```

Сканер запускается автоматически: `core.hooksPath = scripts/hooks`, хук `pre-push`
блокирует пуш при обнаружении значений, похожих на ключи (Google API key, AWS,
GitHub/Slack/GlLab токены, приватные PEM-ключи, `apiHash`, `APPCENTER_SECRET`).
Причины: см. `docs/00-constraints.md` и `NOTICE.md`.

## 5. Ожидаемое поведение до заполнения полей

| Симптом | Причина |
|---|---|
| Не проходит авторизация по номеру телефона | не заполнены `apiId`/`apiHash` |
| Нет push-уведомлений | Firebase-конфиг с плейсхолдерами |
| Keychain/App Group ошибки | не заменены `teamId` и entitlements |
| Клиент предлагает обновление с чужого домена | `SFEED_URL` ведёт на плейсхолдер |
