# NOTICE

**gergram-macos** is an **unofficial** fork of the Telegram for macOS client
(Telegram-macos-Swift, originally the community Swift rewrite `overtake/TelegramSwift`).

This project is **not affiliated with, endorsed by, or sponsored by** Telegram Messenger Inc.

## Upstream

| Component | Source | License |
|---|---|---|
| Telegram for macOS (Swift) | `TelegramOrg/Telegram-macos-Swift` (mirror) / `overtake/TelegramSwift` (root project) | GPL-2.0 |
| Core (`telegram-ios`) | `overtake/Telegram-iOS` | GPL-2.0 |
| All upstream copyright notices | preserved in source files and in `LICENSE` | — |

The full upstream license is preserved verbatim in [`LICENSE`](LICENSE).
All upstream copyright and attribution headers in the imported sources are left intact.

## Fork conditions

This fork follows the conditions published by the upstream project for forks:

- it uses **its own API ID** (not the upstream one);
- it is **not named "Telegram"** and this notice makes its unofficial status explicit;
- it does **not use the standard Telegram logo** — the product ships under the *gergram*
  name and identity;
- it follows the Telegram security guidelines for MTProto implementations;
- its source code is **published** under the same GPL-2.0 license.

## This fork

Project-specific code lives in `packages/Gergram*` and is documented in
[`PROJECT.md`](PROJECT.md), [`AGENTS.md`](AGENTS.md) and [`docs/`](docs/).

The feature set targets the functionality of AyuGram Desktop, analysed in
[`docs/01-ayugram-analysis.md`](docs/01-ayugram-analysis.md), mapped onto this
codebase in [`docs/02-macos-swift-analysis.md`](docs/02-macos-swift-analysis.md)
and enumerated in [`docs/03-feature-list.md`](docs/03-feature-list.md).
