# Скиллы для проекта форка Telegram macOS — что применять

## 1. Метод

Каталог скиллов в системном промпте урезан до одной буквы на плагинные скиллы, поэтому
анализ шёл по **фактическим манифестам** на диске, а не по каталогу:

```bash
find ~/.minimax -name SKILL.md   # → 198 файлов
```

| Источник | Количество | Расположение |
|---|---|---|
| Плагинные (официальный кэш) | 142 | `~/.minimax/v2/plugin-cache/official/<hash>/skills/` |
| Встроенные | 45 | `~/.minimax/.builtin-skills/` |
| Пользовательские | 11 | `~/.minimax/skills/` |

Каждый прочитан по описанию в frontmatter; 9 ключевых — целиком, ещё один (`skill-creator`) —
по первым 70 строкам из 191.

## 2. Важная находка: часть каталога физически отсутствует

~35 скиллов из каталога **не имеют локального содержимого** и не могут быть загружены:
`verus-spec`, `verus-review`, `verus-verify`, `verus-local-e2e`, `verus-done-checklist`,
`verus-secrets-hygiene`, `verus-security-scan`, `verus-plan-change`, `verus-orient`,
`verus-trace-flow`, `verus-ship-change`, `verus-generated-files`, `verus-governed-queries`,
`verus-migration-order`, `verus-frontend-engineering`, `tracing-upstream-lineage`,
`tracing-downstream-lineage`, `annotating-task-lineage`, `checking-freshness`,
`profiling-tables`, `warehouse-init`, `setup`, `hook-development`, `writing-hookify-rules`,
`command-development`, `mcp-integration`, `mavis-doctor`, `minimax-code-product`,
`a11y-debugging`, `codex-team`, `claude-md-improver`, `ast-grep-structural-search`.

Проверено: в `~/.minimax` (включая `.builtin-skills`, `plugin-cache`, `skill-hub.json`) их нет;
в `skill-hub.json` каталог содержит только 11 записей — установленных пользовательских скиллов.

Практические следствия:
- **`verus-*` (17 шт.) недоступны** — нельзя строить план на spec-governance из этого набора.
  Ближайшие доступные замены: `writing-plans` + `domain-modeling` + `code-review` + `verification-before-completion`.
- **`ast-grep-structural-search` недоступен, но сам бинарник `ast-grep` установлен**
  (`/opt/homebrew/bin/ast-grep`). Поиск всех точек врезки по Swift/ObjC делаем им напрямую.
- `mavis-doctor`, `minimax-code-product` — только для диагностики самой MCode, не для проекта.

---

## 3. Tier A — применить сразу (фундамент проекта)

### 3.1 `engineering-workflow` — рабочий цикл по умолчанию

Единственный скилл в наборе, который описывает **весь цикл работы** и при этом не привязан
к веб-стеку: контракт репозитория → маршрутизация → план пропорционально задаче →
инкрементальная реализация → **валидация на затронутой поверхности** → **проход code review** →
честная выдача.

Для нашего проекта это точное попадание:
- «валидация на затронутой поверхности» = сборка Xcode + ручной сценарий (тестов в клиенте нет);
- шаг 6 требует code-review прохода по диффу — обязателен, потому что в форке легко задеть
  апстримный код;
- шаг 7 запрещает заявлять «собралось/протестировано» без фактического прогона — ровно наш риск.

### 3.2 `codebase-design` — архитектурный словарь

Даёт точный язык для ключевого архитектурного решения форка: **где проходит seam**.

| Термин скилла | Как применяется к нам |
|---|---|
| **seam** | точка перехвата в клиенте Telegram: `AccountContext.swift:539` (premium), `ChatInputView.swift:904` (typing), `AccountContext.swift:1363` + `ChatController.swift:2637` (read receipts) |
| **deep module** | `packages/GergramSettings` — маленький интерфейс наружу, вся логика флагов внутри |
| **shallow module** | анти-паттерн: если каждая фича правит свой файл апстрима напрямую — это 200 патчей AyuGram, которых мы избегаем |
| **one adapter means a hypothetical seam** | не вводить абстракцию «PremiumProvider», если реализация одна: Local Premium = переопределение `isPremium`, и точка |
| **the interface is the test surface** | тестировать надо через публичный интерфейс модуля, а не через внутренности |
| **locality** | каждая фича живёт в своём файле пакета `Gergram*` → merge с апстримом без конфликтов |

Есть приложения `DEEPENING.md` (углубление кластера зависимостей) и `DESIGN-IT-TWICE.md`
(параллельные субагенты проектируют интерфейс несколькими способами — применимо,
когда будем выбирать форму настроек и API локального хранилища).

### 3.3 `domain-modeling` — CONTEXT.md и ADR

У нас уже есть терминологическая проблема, которую видно по фичам AyuGram:
«прочитано локально» vs «прочитано на сервере», «Ghost Mode» vs «ghost-настройки аккаунта»,
«Local Premium» vs «серверный Premium», «AyuForward» vs «защищённая пересылка».

`domain-modeling` прямо требует: оспаривать размытые термины, канонизировать их и
фиксировать в `CONTEXT.md`; ADR предлагать только когда решение одновременно
**трудно обратимо**, **неочевидно без контекста** и **результат реального компромисса**.

Под это criteria идеально подходят ровно три наших решения:
1. **Local Premium по умолчанию** — трудно обратимо (риск бана аккаунта), неочевидно,
   компромисс между «полезно» и «безопасно»;
2. **Стратегия: Swift-only или форк ядра** — компромисс «стоимость merge» против
   «полнота Ghost Mode»;
3. **Где хранить настройки и удалённые сообщения** — UserDefaults против Postbox/своей БД.

### 3.4 `init` — AGENTS.md в корне форка

Генерирует корневой `AGENTS.md` по спецификации agents.md — файл, который читает
**любой** агент (и наш будущий) перед работой в репозитории.

Сам скилл содержит guardrail: если в рабочей области нет значимого git-репозитория
с реальным кодом — не.bootstrap-ить. То есть **AGENTS.md создаём после того, как
код форка окажется в репозитории**, а не сейчас. Содержимое должно зафиксировать:

- команды сборки (`scripts/configure_frameworks.sh`, `scripts/rebuild`, Xcode workspace);
- карту точек расширения (таблицу из `docs/02-macos-swift-analysis.md`, §3.10);
- правило «наши правки — в `packages/Gergram*`, не трогаем апстримные файлы без нужды»;
- персональный GitHub: `geranton93` только, `GH_TOKEN=$(gh auth token --user geranton93)`;
- GPL-2.0: не использовать имя «Telegram» и стандартный логотип;
- «никаких комментариев в коде»;
- проверка = сборка + ручной сценарий.

Скилл `writing-for-agents` (плагинный) — приложение к `init`: как именно писать
AGENTS.md, чтобы модель её правильно исполняла.

### 3.5 `skill-creator` — проектный скилл (самое высокое плечо)

По критерию из самого скилла: «только для текущего проекта → project skill
(`<repo>/.minimax/skills/`)».

**Это главный артефакт, который стоит создать.** Мы уже добыли то, что иначе
пришлось бы researches заново на каждой фиче:

- карту «фича → файл:строка → что перехватить»;
- рецепт регистрации новой настройки (Codable-структура → ключ → UI-раздел → `FastSettings`);
- рецепт добавления пункта в контекстное меню / панель ввода;
- правило «не трогай апстримные файлы, если можно обойтись»;
- команды валидации;
- типовые грабли: `core.sshCommand`, `GH_TOKEN`, отсутствие тестов, конфликты в
  `ChatRowItem.swift` / `ChatController.swift`.

Наш скилл должен снимать вопрос «где это править?» за секунды, а не за час поиска.
Проверка качества — по процедуре `skill-creator`: сначала короткий eval-прогон на
реальном промпте, потом правка.

### 3.6 `using-git-worktrees` — изоляция фич

Для 124 фич и параллельной работы по фазам — базовый инструмент. Два его guardrail'а
для нас критичны:

- **проверка, что мы не внутри сабмодуля** — у нас будет `submodules/telegram-ios`,
  а `GIT_DIR != GIT_COMMON` верно и для сабмодулей; без проверки мы режем не то;
- **`.worktrees/` обязан быть в `.gitignore` до создания** — иначе содержимое воркtree
  коммитится в репозиторий.

Шаг 3 «проверить чистую базу» у нас означает **успешную сборку**, а не тесты.

### 3.7 `writing-plans` + `executing-plans`

У нас уже есть фазы 0–5 с оценками. `writing-plans` превращает их в исполнимые планы
с точными файлами и шагами, `executing-plans` — в пошаговое исполнение с чекпоинтами
и остановками на развилках. Для проекта такого масштаба (100+ человеко-дней) это
единственный способ не потерять управляемость.

### 3.8 `to-tickets` (+ `to-spec`, `wayfinder`, `setup-matt-pocock-skills`)

Прямой путь от нашего `docs/03-feature-list.md` (124 фичи) к трекеру:

- `to-spec` — превратить перечень фич в спецификацию;
- `to-tickets` — разбить на **tracer-bullet вертикальные срезы** с явными блокирующими
  связями («Blocked by»), с публикацией в GitHub issues. Для нас — репозиторий
  `geranton93/gergram-macos`, то есть ровно тот аккаунт, который требуется;
- ключевая для нас механика **expand–contract** из этого скилла: наш слой настроек
  — это wide refactor по определению (один тип рассыпан по десяткам мест).
  Правильная последовательность: сначала **expand** (добавить новую форму рядом со
  старой, ничего не ломая), потом миграция вызовов батчами, потом **contract** —
  удаление старой формы. Ровно то, что нужно, чтобы не ломать merge с апстримом;
- `setup-matt-pocock-skills` — конфигурация трекера и словаря лейблов, запускать до
  первого прогона `to-tickets`;
- `wayfinder` — навигация по незнакомому репозиторию, полезно при первом заходе в код.

### 3.9 `code-review` (встроенный) — ревью диффов

Точная дисциплина: «репортуй только конкретные дефекты», «не репортуй пре-существующие
дефекты как регрессии изменения», «проверяй по текущему коду и вызывающим сторонам»,
«review-only, если не просили фиксы». Для форка критично правило про **comparison base**:
ревьюи�� дифф против нашей базовой ветки, а не против HEAD апстрима.

### 3.10 `verification-before-completion` — дисциплина доказательств

У клиента нет unit-тестов, поэтому «собралось» и «работает» — это разные утверждения.
Этот скилл заставляет приводить доказательства перед тем, как заявить результат. Прямо
лечит главный риск нашего проекта (тихо сломанное поведение в форке).

### 3.11 `create-agent` — выделенный агент под форк

По правилам скилла: создавать только после явного одобрения владельца; имя — по
ответственности, а не по seniority; `agent.md` = системный промпт с четырьмя блоками
(scope / how you work / stop when); **правила проекта не инлайнить в тело агента, а
ссылаться на один документ** — то есть на наш `AGENTS.md` и `docs/`.

Проектный агент `telegram-macos-fork` (ответственность, не «senior»):
- Own: `packages/Gergram*`, `docs/`, интеграционные точки в `Telegram-Mac/`;
- Don't own: ядро `submodules/telegram-ios` (отдельный агент), апстримные файлы без нужды;
- Stop when: сборка проходит, тикет закрыт, PR открыт в `geranton93/gergram-macos`.

---

## 4. Tier B — по фазам проекта

| Фаза | Скиллы | Зачем именно здесь |
|---|---|---|
| **0. Фундамент** | `init`, `writing-for-agents`, `domain-modeling`, `using-git-worktrees`, `engineering-workflow` | AGENTS.md, CONTEXT.md, ADR, изоляция веток, рабочий цикл |
| **1. Ghost Mode** | `systematic-debugging`, `codex-cli-runtime`, `codex-prompt-engineering`, `codex-result-handling`, `diagnosing-bugs` | отладка перехвата прочтений/online/typing; чтение чужого ObjC/Swift ядра лучше отдать Codex |
| **2. Анти-Recall** | `domain-modeling` (ADR по хранилищу), `prototype`, `test-scenarios`, `research` | выбор модели хранения удалённых сообщений; ручные сценарии вместо тестов |
| **3. Интерфейс (50 фич)** | `dispatching-parallel-agents`, `subagent-driven-development`, `dynamic-workflow`, `to-tickets` | 50 независимых тумблеров идеально распараллеливаются по воркtree'ам |
| **4. Расширенные** | `prototype`, `github-search`, `deep-research`, `research` | Message Shot и фильтры требуют прототипа; prior-art форков ищем через GitHub |
| **5. Ядро** | `codex-cli-runtime`, `resolving-merge-conflicts`, `finishing-a-development-branch`, `systematic-debugging` | патчи ядра и циклы merge с `overtake/Telegram-iOS` |
| **Весь проект** | `mavis` (агенты/сессии/память), `release-notes`, `triage`, `handoff`, `powercontext-project-context` | управление долгой кампанией, передача контекста между сессиями |

Пояснения по ключевым:

- **`dispatching-parallel-agents` / `subagent-driven-development`** — не «распараллелить любую
  задачу», а гонять независимые задачи в отдельных воркtree'ах. У нас таких задач десятки
  (тумблеры панели ввода, контекстных меню, внешнего вида) — они не пересекаются по файлам.
- **`dynamic-workflow`** — DSL для многоагентного конвейера с панелью ревью. Полезно,
  когда реализация 124 фич пойдёт пачками по 8–12 тикетов: узлы = тикеты, зависимости = блокеры.
- **`codex-cli-runtime`** — отдельный рантайм для задач, где нужен другой проход по коду
  (например, аудит патча ядра). `codex-prompt-engineering` / `codex-result-handling` —
  как формулировать задание и разбирать результат.
- **`test-scenarios`** — в клиенте нет тестов, поэтому единственная реальная проверка —
  сценарий вручную. Скилл даёт формат именно для этого.
- **`github-search`** — поиск чужих форков мак-клиента с уже решёнными задачами
  (ghost mode, anti-recall). Часть наших фич может быть решена в чужом форке.
- **`resolving-merge-conflicts`** — наш ежемесячный риск: merge с апстримом.
- **`triage`** — разбор входящих issue по `ready-for-agent` (лейбл, который сам `to-tickets`
  и ставит).

---

## 5. Tier C — условно

| Скилл | Когда включать |
|---|---|
| `brainstorming` (пользовательский), `grilling`, `grill-me` | открытые решения: значения по умолчанию, поведение Ghost в разных режимах, именование фич |
| `grill-with-docs` | те же решения, но с опорой на наши документы |
| `writing-plans` → `executing-plans` → `finishing-a-development-branch` | вход и выход из каждой ветки |
| `skill-refiner` | когда наш проектный скилл потребует правок по факту использования |
| `find-skills` / `finding-skills` | если понадобится специализация, которой нет в наборе |
| `setup-matt-pocock-skills` | конфигурация трекера перед первым `to-tickets` |
| `research`, `deep-research` | внешние факты: документация MTProto, GPL-требования, поведение серверных фич |
| `prototype` | Message Shot, фильтры, UI сложных фич — прототип перед продакшеном |
| `mavis` | долгие кампании: роутинг задач между агентами, память проекта |
| `release-notes` | релиз форка |
| `diagram-design` | схема слоёв форка и карта точек расширения |
| `visual-page` | визуальный дашборд по 124 фичам со статусами (для демонстрации прогресса) |
| `docx` / `pdf` / `pptx` / `xlsx` | только если PRD или отчёт нужны в офисном формате для стейкхолдеров |
| `plugin-creator` / `plugin-settings` | собрать наш проектный скилл + агента в локальный плагин проекта |
| `reverse-engineer-anything` | если придётся разбирать поведение, которого нет в исходниках (редко) |
| `peer-review` | независимая проверка архитектурного решения коллегами-агентами |
| `claude-md-improver` | полировка AGENTS.md, если найдём лучший формат (файл в каталоге недоступен — скилл не подтянется) |

---

## 6. Tier D — не применять

| Группа | Скиллы | Почему не подходит |
|---|---|---|
| **Веб/React** | `frontend-design`, `frontend-dev`, `fullstack-dev`, `fullstack-pro`, `vercel-react-best-practices`, `core-web-vitals`, `performance-optimization`, `tailwind`-подобные, `seo-audit`, `analytics` | проект — нативный macOS-клиент на Swift, веб-стека нет. `engineering-workflow` покрывает нужную часть их логики |
| **Анимации/GSAP** | `gsap-core`, `gsap-react`, `gsap-scrolltrigger`, `gsap-timeline`, `gsap-frameworks`, `gsap-plugins`, `gsap-performance`, `gsap-utils`, `gsap-skills:*` | веб-анимация, к нативному AppKit/UIKit отношения не имеет |
| **SwiftUI** | `swiftui-pro` | **конфликт по существу**: скилл требует SwiftUI и прямо предписывает избегать UIKit, а клиент написан на UIKit (`TGUIKit` — форк UIKit под macOS). Применять только его ссылки по accessibility/HIG вручную, как справочные |
| **Другие языки** | `python-performance-optimization`, `rust-best-practices`, `verus-python-engineering`, `verus-go-engineering`, `verus-database-engineering` | в проекте нет Python/Rust/Go |
| **Data Science** | `scientific-research-workflows:*` (9), `statistical-*`, `hypothesis-generation`, `experimental-design`, `scholar-evaluation`, `uncertainty-and-units`, `profiling-tables` | не про разработку ПО |
| **Медиа-генерация** | `minimax-h3-skills:*` (8), `brand-promo-video-generator`, `music-video-subtitle-generator`, `paper-collage-explainer-generator`, `handdrawn-live-video-generator`, `3d-animation-short-generator`, `co-op-game-intro-generator`, `minimalist-product-ad-generator`, `playground` | генерация видео/изображений, не связана с форком |
| **AI/LLM** | `llm-call`, `llm-council`, `ai-engineering`, `senior-ai-systems-engineer`, `transformers-js`, `trl-training`, `hf-*` (8), `finetuning` | нет LLM-составляющей в проекте |
| **Feishu/Lark** | `lark-tools` и производные (~20) | нет работы с Lark |
| **Веб-деплой** | `deploy-website`, `edit-deployed-website`, `miniapp-creator` | публикация сайтов, не macOS-приложений |
| **Заметки/Office** | `obsidian-*`, `json-canvas`, `humanizer`, `x-link-reader`, `treg`, `nowledge-mem` | не связаны с задачей |
| **PM/стартап** | `startup-canvas`, `lean-canvas`, `business-model`, `monetization-strategy`, `pricing-strategy`, `pestle-analysis`, `porters-five-forces`, `swot-analysis`, `customer-research`, `copywriting`, `marketing-*`, `competitor-profiling`, `job-stories`, `interview-script`, `value-proposition` | внутренний форк, не продукт на рынок |
| **Спец-инструменты** | `command-development`, `hook-development`, `writing-hookify-rules`, `mcp-integration`, `setup`, `warehouse-init` | не задействованы; кроме того `command-development`, `hook-development`, `writing-hookify-rules`, `mcp-integration`, `setup`, `warehouse-init` отсутствуют локально |

---

## 7. Что создать прямо сейчас (артефакты)

| Артефакт | Скилл-инструмент | Где | Когда |
|---|---|---|---|
| `AGENTS.md` | `init` + `writing-for-agents` | корень форка | после появления кода форка в репозитории |
| `CONTEXT.md` + `docs/adr/` | `domain-modeling` | корень + `docs/adr/` | сейчас — термины уже есть в перечне фич |
| Проектный скилл `gergram-feature` | `skill-creator` | `.minimax/skills/gergram-feature/` | сейчас — карта точек уже добыта |
| Агент `telegram-macos-fork` | `create-agent` | `~/.minimax/agents/` | после одобрения владельца |
| План по фазам | `writing-plans` | `docs/plans/` | перед стартом Фазы 0 |
| Тикеты по 124 фичам | `to-tickets` (+ `setup-matt-pocock-skills`) | GitHub issues `geranton93/gergram-macos` | после плана |
| ADR о стратегии ядра | `domain-modeling` | `docs/adr/` | до начала Фазы 1.5 |

## 8. Итоговая рекомендация

**Опорный стек (держать загруженным постоянно):**
`engineering-workflow` · `codebase-design` · `domain-modeling` · `code-review` ·
`verification-before-completion` · `using-git-worktrees` · `to-tickets`

**Подключать по событию:**
`init` · `writing-plans`/`executing-plans` · `skill-creator` · `create-agent` ·
`dispatching-parallel-agents` · `dynamic-workflow` · `codex-cli-runtime` ·
`systematic-debugging` · `resolving-merge-conflicts` · `test-scenarios` ·
`github-search` · `prototype` · `mavis`

**Не подключать:** ~120 скиллов из веба, мобильного веба, data science, генерации медиа,
AI/LLM, Lark, стартап-PM и нерелевантных языков — см. §6.

**Отдельно:** 35 скиллов из каталога физически отсутствуют и не могут быть загружены —
при планировании нельзя на них опираться. `ast-grep` доступен как бинарник напрямую.
