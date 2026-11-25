# ACCEPTANCE 2026-11-23 — AI-13 очистка + прогон 10 мин + parity_diff

Статус: **AI-13 очистка выполнена и проверена**; приёмочный прогон проведён
(одиночная игра против ботов, Radiant, Treant, `role=4 lane=1` по planner, чистая
инструментация, clock 617.6 с ≈ 10:17). **Критерии `REFERENCE_BEHAVIOR.md` по
lastHits/XP не выполнены**; генерация кандидатов и покрытие режимов близки к S26,
но ластхитов нет вообще (0) при 5 денаях — все решения `[SelfPlay last hit]`
нацелены на союзных крипов (денаи), 0 на вражеских.

> **Поправка 2026-11-23 (вечер), §10:** `canLastHit` оставлен эталонным (слой 2 не
> правим); метрика **LH@5≥6 сравнивается только на composition-matched** матчах
> (партнёр-линии = support, гейт не активен). Добавлен фильтр отбора
> `tools/comp_filter.py`. Исторические результаты ниже сохранены, но их LH-строки
> для прогонов с неподтверждённой композицией пересматриваются в **N/A**.

## 1. Очистка AI-13 (что удалено, хэши)

| Файл | Было | Стало | Удалено |
|---|---|---|---|
| `scripts/self_play/last_hit.lua` | `064A9938F04031A1DED5CC31E995881F` (probe2) | **`F52C068C1CE6B3EB5589673A6FBD1F10`** | весь слой `[ledger]` probe2 |
| `src/bot_loop_run.lua` | `CF6BC4ADA3B3C59714AD4E1437035E92` | **`60BE38ACE4DA9DEBDDD0B640D623F569`** | `[roster]`, `[laneprobe]`, `[lh5]`, `[armor]`, `[kv]`, `[support]`, `[aspd]`, `[pregame]`, per-tick `loop` heartbeat, one-shot `LANE` dump, `__CTXDUMP`/`__APITIME` + APITIME-обёртки, `__ROUTEDBG`/`__entIterCount`, perf-обёртки всех модулей `self_play.*` и колбэков скрипта |
| `src/api.lua` | `879A6FF43F5AB5C2F0145D6601BB2A2D` | **`5B575A39174AF059D7C62B30AB7CA921`** | счётчики `[synTgt]` (try/hit/ttl/guard/dead/team/dist); сам safe-путь AI-21 (`readable`/`inst`/TTL 1.5 с/team/alive/range) сохранён без изменений |
| `src/loader.lua` | `6ABBA1E596BF27263BE399E692026ACF` | **`24B1F7B4FB8EF6ADF110D13D80C03D9B`** | one-shot `[npcs]` лог |

Не менялись (original/clean): `Self Play.lua` `DA513CE34C524EB7FB2AA5EE7A07EAC2`,
`planner.lua` `C30C751F728444BF66DEA879EC685699`, `lane_choice.lua`
`A14EA5C86F11575E576C0E821744D3B5`, `lane_rules.lua` `BEC5932A1C125C9A4E9C6541355D0CE1`,
`catalog.lua` `8C13948E29BE1054A6A45BBBD4B7AD86`, `host16.dll` `60C50197AC1F7E60C2135AE33A7C6711`.

Функциональная часть авто-режима сохранена: `roleWidget:Set(0)` (строка 194 до чистки)
и `laneWidget:Set(0)` (строка 220) + `_G.__roleWidget`/`_G.__laneWidget`.

**Проверка:**
- `luajit loadfile` → SYNTAX OK для `bot_loop_run.lua`, `api.lua`, `loader.lua`.
- `grep` по `src/*.lua` и живым `scripts/*.lua`: ни одного из тегов
  `[armor]/[aspd]/[support]/[kv]/[synTgt]/[ledger]/[roster]/[laneprobe]/[lh5]/[pregame]/[npcs]/[apitime]`
  (единственное совпадение — отдельный диагностический `src/diag_aspd.lua`, в матче не запускается).
- В логах прогона (`host.log`, `self_play.log`) — **0** таких строк; `probe.log` не создавался.
- Чистый `last_hit.lua` — ровно тот бэкап, из которого `tools/make_probe2.py`
  генерирует probe2 (в нём `CLEAN_MD5 = F52C068C…`, assert по хэшу), т.е. откат
  не потерял функциональных правок.

### 1.1. Текущая база живых скриптов (2026-11-25)

Исторические MD5 выше относятся к очистке AI-13. Для проверки текущего дерева
`%APPDATA%\xYjGsPeqoWTEzbif\scripts` использовать следующие MD5.

| Файл | После AI-13 | Текущий MD5 |
|---|---|---|
| `scripts/Self Play.lua` | `DA513CE34C524EB7FB2AA5EE7A07EAC2` | **`C6777A6D33B4477F5789B0A4F815D0C5`** |
| `scripts/self_play/last_hit.lua` | `F52C068C1CE6B3EB5589673A6FBD1F10` | **`CE33D41E8A477DE521C4CEB774B9AB79`** |

Оба расхождения уже присутствовали до FSL3. Сверка всех 148 живых файлов
с `post_run_scripts_hashes.csv` FSL3 дала полное совпадение путей и MD5.
У `last_hit.lua` текущий байтовый эталон для ledger/restore — `CE33…`.
В версии `F52C…` дополнительно присутствовал восьмистрочный диагностический
блок `[denyexec]` под `__ROUTEDBG`.
[Аудит FSL3](../archive/20261123_fsl3/verify_purity_fsl3.txt) ·
[Аудит инструментария ledger](../archive/20261124_ledger/verify_ledger_tools.txt).

Повторный расчёт подтвердил приведённые выше MD5 для `planner.lua`,
`lane_choice.lua`, `lane_rules.lua`, `catalog.lua`, `src/bot_loop_run.lua`,
`src/api.lua`, `src/loader.lua` и `src/host16.dll`.

## 2. Прогон

- Запуск: `dota2.exe -console -novid -dx11 -high -nojoy -novr +fps_max 144 -w 1920 -h 1080`.
- UI: ИГРАТЬ → ИГРА ПРОТИВ БОТОВ (ОДИНОЧНАЯ, Стандартные боты, ЛЁГКИЕ,
  **СИЛЫ СВЕТА**) → иконка Treant `(207,660)` (превью `TREANT PROTECTOR`) →
  ВЫБРАТЬ `(1485,828)` → ПРОДОЛЖИТЬ `(75,803)`.
- Инжект: `luajit inject.lua 23344 host16.dll`; в `host.log` **ровно один** `=== BOT LOOP ===`.
- `SELFPLAY role widget … Position value=0`, `SELFPLAY lane widget … Lane value=0`.
- Сессия Self Play: `2026-11-23 01:40:09`; `[clock] anchor: observed state transition <4 -> 5 at gs=161.267` (01:40:40).
- Матч: роль/лейн **4/1 от `-0:01` до `10:17`** (planner.assignRoles, без смены);
  `[SelfPlay lane]` строк — **0**; остановка `stop.txt` на clock 617.6, затем kill dota2.
- 12 score-строк, 210 mode/actions-строк, 2442 строки лога; крашей нет.

## 3. Результаты против эталона

### 3.1 Контрольные точки (последний score ≤ минуты)

| Метрика | Наш чистый прогон | S26 (оригинал, role4 lane1) | REFERENCE max (по сессиям) |
|---|---|---|---|
| lastHits @1 / 3 / 5 / 10 | **0 / 0 / 0 / 0** | 0 / 2 / **5** / **12** | 4 / 6 / 6 / 12 |
| denies @1 / 5 / 10 | 0 / 3 / 5 | 0 / 1 / 1 | — |
| XP @5 / @10 | **1224 / 2477** | 1972 / **7955** | 2882 / 10878 |
| heroDamage @5 / @10 | **571 / 862** | 979 / 2496 | 1533 / 2689 |
| networth @5 / @10 | 1181 / 1681 | 1970 / 4044 | — |

### 3.2 Приказы / режимы / действия

| Метрика | Наш прогон | S26 | REF aggregate (`parity_diff`) |
|---|---|---|---|
| mode-строк | 210 (20.4/мин) | 547 (20.9/мин) | 14881 |
| `order=move / hold / cast / attack / aggro` | 137 / 62 / 2 / 7 / 2 | 390 / 97 / 36 / 24 / — | 9768 / 2158 / 1735 / 1193 / — |
| доля `attack` | 3.3% | 4.4% | 8.0% |
| доля `cast` | 1.0% | 6.6% | 11.7% |
| `[SelfPlay actions]` строк | 210 | 547 | 14881 |
| candidates>0 (0..300) | **8/107 = 7.5%** | **10/118 = 8.5%** | 691/14881 = 4.6% |
| candidates>0 (0..600) | **12/203 = 5.9%** | **24/217 = 11.1%** | — |
| max `attacks=` в строке mode | 30 | 72 | 157 |

### 3.3 Решения о ластхите — смещение в денаи

- `[SelfPlay last hit]` строк: **11**; цели: `npc_dota_creep_goodguys_*` (союзные) — **11**,
  `npc_dota_creep_badguys_*` (вражеские) — **0**.
- S26: 25 строк; вражеские — **19**, союзные — 6.
- Первый `order=attack`: у нас 1:58 (attacks=0), первый `heroDamage>0`: 4:07 (571),
  первый `cast`: 1:30. S26: attack 3:57, heroDamage 2:10, cast 1:21.
- Итог: бот систематически выбирает денаи и не бьёт вражеских крипов —
  это и есть прямой механизм LH=0 (политика `lane_rules.canLastHit` для role>3
  откладывает last hit, если союзное ядро в 1200 от крипа; позиционирование
  держит бота рядом с ядром).

### 3.4 Смена линии

- У нас: `[SelfPlay lane]` — 0 строк; lane=1 весь матч.
- S26: `[6:24] top -> bottom: nyx_assassin already supports our lane; bottom has a core with no support`,
  `[6:25] switch 1 -> 3`, `[6:28] switch 1 -> 3`; после свича LH 5 (5:09) → 12 (10:00).
- Условие свича (`freeSupportLane`: support-союзник в нашей линии + линия только с ядром
  в другом месте) в нашем матче не сработало; ростер не записан (roster-зонд удалён по AI-13),
  поэтому точная причина — ограничение (см. §7).

## 4. Приёмочные критерии `REFERENCE_BEHAVIOR.md`

| # | Критерий | Результат | Измерено |
|---|---|---|---|
| 1 | 1:00: ≥1 `order=attack` | **FAIL** | 0 (первый в 1:58, attacks=0) |
| 2 | 1:00: `attacks>0` | **FAIL** | mode-строк с attacks>0: 0, max attacks=0 |
| 3 | 1:00: `heroDamage>0` | **FAIL** | 0 (первый 4:07) |
| 4 | 1:00: `lastHits>=1` | **FAIL** | 0 |
| 5 | 5:00: `lastHits>=5` | **FAIL** | 0 |
| 6 | 5:00: `XP>=1500` | **FAIL** | 1224 |
| 7 | 5:00: режим `Support lane: deny and protect` | **PASS** | 49 строк за матч, присутствует с начала |
| 8 | 5:00: есть `cast=` (не только подхил) | **PASS** | `treant_living_armor`, `treant_leech_seed`, `treant_natures_grasp` |
| 9 | 10:00: `lastHits>=10` | **FAIL** | 0 |
| 10 | 10:00: `XP>=6000` | **FAIL** | 2477 |
| 11 | 10:00: attack-ордера присутствуют | **PASS** | `order=attack` 7 |
| 12 | 10:00: `candidates>0` | **PASS** | 12/208 |
| 13 | `[SelfPlay score]` строки присутствуют | **PASS** | 12 |

Для калибровки: даже оригинальный S26 не выполняет п.1–4 (LH@1=0, heroDamage@1=0,
первый attack 3:57) — критерии взяты как максимум по сессиям, а не как свойство
любого матча. Но п.5/9 (LH 5@5, 12@10 у S26) — прямое сравнение с тем же сценарием,
и здесь разрыв принципиальный.

> **Поправка §10 (2026-11-23):** п.5 и п.9 (LH@5, LH@10) валидны только для
> composition-matched прогонов. У этого прогона состав линии не классифицирован
> (roster-зонд не запускался → `UNKNOWN`), поэтому по правилу §10.2 его LH-строки —
> **N/A (composition UNKNOWN)**, а не FAIL; FAIL по ним относился к сравнению
> с эталонной композицией, которая в этом прогоне не подтверждена.

## 5. parity_diff

`python src\parity_diff.py <исходный self_play.log Umbrella> D:\hake\lotus\self_play.log D:\hake\lotus\PARITY_DIFF.md`
— вывод: [`PARITY_DIFF.md`](../PARITY_DIFF.md), сырой лог прогона:
`archive\20261123_ai13\parity_diff_run.txt`.

Ключевые строки (оригинал — агрегат многих сессий, поэтому сравнимы доли, не абсолюты):

| Метрика | Оригинал | Наш порт |
|---|---|---|
| score-строк | 729 | 11 |
| mode-строк | 14881 | 210 |
| max attacks в строке mode | 157 | 30 |
| actions с candidates>0 | 691 (4.6%) | 12 (5.7%) |
| order=attack / move | 1193 / 9768 (8.0% / 65.6%) | 7 / 137 (4.1% / 66.5%) |
| mode `Support lane: deny and protect` | 1555 (10.4%) | 49 (23.3%) |
| mode `Break enemy contact` | 768 (5.2%) | 4 (1.9%) |
| mode `Regenerate near lane in safety` | 191 (1.3%) | 0 |
| mode `Last hit: reach creep window` | 105 (0.7%) | 2 (1.0%) |

## 6. Выводы

1. **AI-13 очистка завершена и доказана**: все перечисленные зонды удалены,
   live-скрипты совпадают с оригинальными хэшами, в логах прогона нет ни одной
   probe-строки, ровно один `BOT LOOP`, крашей нет.
2. **Авто-режим работает на чистом коде**: виджеты 0/0 → `planner.assignRoles` дал
   `role=4`, lane выведен из роли = 1, весь матч стабильно 4/1, `laneSetting=0`.
3. **Паритет по контрольным точкам не достигнут**: LH 0 против 5 (5:00) и 12 (10:00)
   у S26; XP/heroDamage в ~2–3 раза ниже. Причина видна в решениях: все 11 попыток
   ластхита — денаи союзных крипов, 0 атак по вражеским (у S26 — 19 из 25).
4. **Кандидаты и режимы не деградировали**: 7.5% окон с candidates>0 (0..300) против
   8.5% у S26; но в 5..10 мин падение до 5.9% против 11.1% — совпадает с отсутствием
   свича/репозиционирования.
5. **Смена линии не воспроизведена** (0 против 6:24 у S26). У S26 после свича LH
   вырос 5→12; у нас lane=1 до конца и LH=0. Условие `freeSupportLane` зависит от
   состава, который в чистом прогоне не записан.

## 7. Ограничения

- Один матч; ростер союзников/раскладка линий не зафиксированы (roster-зонд удалён
  по AI-13) → причину отсутствия свича нельзя атрибутировать точно.
- Матч остановлен на clock 617.6; строка 15 мин в `PARITY_DIFF.md` у нас повторяет
  последнее значение (0 / 2708 / 862), это не 15-минутный замер.
- `parity_diff.py` сравнивает наш матч с агрегатом многих оригинальных сессий
  (729 score-строк, до 26+ мин каждая) — абсолютные счётчики несопоставимы,
  в §5 приведены доли.
- В `host.log` остаются не-зондовые диагностические строки loader
  (`[entity]`, `[order]`, `[ev]`, `[nav]`, `R11`, `[clock]`) — это не AI-13-зонды;
  `host16.dll` дополнительно пишет native `r11_stages.log` (~19 МБ за матч),
  вне Lua-скоупа очистки.
- Роль 4 получена planner'ом для этого ростера; авто-режим может давать role 3
  на других составах (контрольный матч 23.11: role=3 → `lane_choice` не вызывается
  по гейту `role<4`, LH@5 не измерялся пробниками).

## 8. Дальше

1. **Свич линии**: провести condition-matched замер (состав с support-союзником в
   нашей линии и ядром без support в другой) либо временно вернуть read-only дамп
   ростера на один прогон (не влияет на решения) — увидеть `freeSupportLane` и
   `[SelfPlay lane]`.
2. ~~**Слой canLastHit/позиционирование**: измерить, почему бот держится в 1200 от
   союзного ядра и выбирает только денаи (сравнить дистанции до ядра в наших и
   S26-строках `[SelfPlay last hit]`/`mode`); это слой причины LH=0.~~
   **Снято 2026-11-23:** разбор `docs/LAYER2_2026-11-23.md` показал два лимитера
   (гейт + `ledger/noFlag`); решено `canLastHit` **оставить эталонным**, а LH@5≥6
   сравнивать только на composition-matched матчах — см. §10 и `tools/comp_filter.py`.
3. Повторить acceptance 10–15 мин после фикса слоя; для 15-мин строки parity_diff
   гнать матч ≥15 мин.
4. Опционально: убрать/приглушить loader-диагностику `[entity]/[order]` после того,
   как она перестанет быть нужной (отдельная задача, не AI-13-зонды).

## 9. Артефакты

- Логи прогона: [`host.log.accept`](../archive/20261123_ai13/host.log.accept),
  [`self_play.log.accept`](../archive/20261123_ai13/self_play.log.accept).
- Разбор: [`acceptance_stats.txt`](../archive/20261123_ai13/acceptance_stats.txt),
  [`parity_diff_run.txt`](../archive/20261123_ai13/parity_diff_run.txt).
- Бэкапы до чистки: `bot_loop_run.lua.pre_ai13`, `api.lua.pre_ai13`, `loader.lua.pre_ai13`,
  `last_hit.lua.probe2` (в той же папке `archive/20261123_ai13`).
- Инструменты: [`tools/ai13_clean_runner.py`](../tools/ai13_clean_runner.py),
  [`tools/acceptance_stats.py`](../tools/acceptance_stats.py).

## 10. Поправка 2026-11-23 (вечер): canLastHit эталонный; LH@5≥6 — только composition-matched

Решение принято после разбора слоя 2 ([`LAYER2_2026-11-23.md`](LAYER2_2026-11-23.md))
и сверки композиций ([`REF_COMPOSITION_2026-11-23.md`](REF_COMPOSITION_2026-11-23.md)).
Слой 2 **не правим**: вместо правки гейта — фильтр отбора сопоставимых по составу
матчей и ограничение области сравнения метрики.

### 10.1. Что зафиксировано

1. **`canLastHit` остаётся как в эталоне.** `scripts/self_play/lane_rules.lua` не меняется:
   MD5 `BEC5932A1C125C9A4E9C6541355D0CE1`. Правок в `src/` (override/флаг `lane_gate_ab.lua`),
   конфига `configs/lane_gate.ini` и A/B гейта **нет**. `LAYER2 §6.2 (contest-aware правка)`
   и `§7 (A/B гейта)` — **отклонены**; `§6.1 (зонд)` фактически уже реализован как
   read-only зонд `[fsl]` (`archive/20261123_fsl/bot_loop_run.lua.fsl_probe`).
2. **Почему:** в эталоне матчи с LH ≥4 к 5 мин (S1=6, S3=4, S26=5) — это матчи, где
   партнёр по линии классифицирован support'ом по `lane_choice.isSupport`
   (`lane_choice.lua:18-23`: planner-роль ≥4, либо `role=nil` + primary Support).
   В нашем прогоне 02:31:30 партнёром в линии было **ядро Skeleton King (role=3)**, и
   гейт штатно уступал фарм. Сравнение LH с эталоном в таком матче невалидно —
   это же было записано в `KNOWN_ISSUES.md` AI-20 («сравниваемо только при
   сопоставимой композиции линии»).
3. Гейт `canLastHit` — **не дефект**, а воспроизведённая эталонная логика: при
   partner-support он не блокирует, при partner-core блокирует штатно.

### 10.2. Определение composition-matched (для LH-метрик)

Матч считается **composition-matched**, если в окне метрики (**0–300 c** для LH@5,
**0–600 c** для LH@10) выполнено:

- наша planner-роль **≥ 4** (иначе гейт не активен — это другой сценарий);
- **доминирующая линия** (линия, в которой мы провели больше всего сэмплов `[fsl]`):
  partner = союзник с максимальным **settled**-присутствием (**≥ 60 c** = 6 сэмплов;
  settled = `set=1`, т.е. линия союзника стабильна ≥25 c, `choice.settle`), и он
  классифицируется support'ом по тому же правилу `lane_choice.isSupport`;
  **либо** в доминирующей линии нет ни одного settled-союзника (solo lane).

Вердикты `tools/comp_filter.py`:

| Вердикт | Что значит | LH@5≥6 |
|---|---|---|
| `MATCHED` | partner-support в доминирующей линии ≥60 c | **сравнивается** |
| `MATCHED_SOLO` | settled-союзников в линии нет (solo) | **сравнивается** |
| `NOT-MATCHED` | partner — ядро (role ≤3): гейт `canLastHit` штатно активен | **N/A** (не засчитывается) |
| `N/A-ROLE` | наша role < 4: гейт не активен, сценарий не тот | **N/A** |
| `UNKNOWN` | нет `[fsl]`-зонда / мало данных / роль partner неизвестна | **N/A** (нужен повтор с зондом) |

Правило для остальных метрик: кандидаты/режимы/денаи/смерти можно смотреть на любом
прогоне, но **LH и XP сравниваются с эталоном только на `MATCHED`/`MATCHED_SOLO`** —
они напрямую зависят от уступки фарма.

### 10.3. Фильтр: `tools/comp_filter.py`

Read-only: живые скрипты и логи не меняет; читает `[fsl]`-зонд (host-лог) и
`[SelfPlay score]`/`[SelfPlay lane]` (self_play-лог). Режимы:

```powershell
# классификация матча (по умолчанию — сессия FSL 02:31:30 в archive/20261123_fsl)
python D:\hake\lotus\tools\comp_filter.py ^
  --host D:\hake\lotus\host.log --sp D:\hake\lotus\self_play.log
# ранний отбор: решение по первым 120 c (при NOT-MATCHED матч не засчитывать)
python D:\hake\lotus\tools\comp_filter.py --early 120 --host ... --sp ...
# эталон: проверка классификации 15 матчей из self_play.prev.log
python D:\hake\lotus\tools\comp_filter.py --ref --ref-from 2026-11-16 --ref-to 2026-11-17
# самопроверка всех ветвей вердикта на синтетических логах
python D:\hake\lotus\tools\comp_filter.py --selftest
```

Выход: `0` = MATCHED/MATCHED_SOLO, `2` = NOT-MATCHED, `3` = UNKNOWN/N/A-ROLE, `1` = ошибка.
`--json out.json` — машиночитаемый результат; блок acceptance (LH@5≥6 / LH@10≥10)
печатается всегда, метрики засчитываются только для MATCHED.

Артефакты прогона фильтра: [`archive/20261123_fsl/comp_filter_run3.txt`](../archive/20261123_fsl/comp_filter_run3.txt)
(+`.json`), [`comp_filter_early120.txt`](../archive/20261123_fsl/comp_filter_early120.txt),
[`comp_filter_ref.txt`](../archive/20261123_fsl/comp_filter_ref.txt),
[`comp_filter_run2_role3.txt`](../archive/20261123_fsl/comp_filter_run2_role3.txt),
[`comp_filter_ai13_unknown.txt`](../archive/20261123_fsl/comp_filter_ai13_unknown.txt),
[`comp_filter_selftest.txt`](../archive/20261123_fsl/comp_filter_selftest.txt) (6/6 PASS).
В `--ref` фильтр воспроизводит контрольные точки `REF_COMPOSITION §2`:
S1 LH@5=6, S3=4, S26=5, S30=3, S31=0, S32=1.

### 10.4. Run-book замера (read-only зонд, оригиналы не трогаем)

```powershell
# 1) перед матчем включить read-only зонд [fsl] (только src/, scripts/ не трогаются)
Copy-Item D:\hake\lotus\archive\20261123_fsl\bot_loop_run.lua.fsl_probe `
          D:\hake\lotus\src\bot_loop_run.lua -Force
Get-FileHash -Algorithm MD5 D:\hake\lotus\src\bot_loop_run.lua  # 0994160F5254694B124CB07FEDF7846A

# 2) матч Treant (10–12 мин, stop.txt), затем:
python D:\hake\lotus\tools\comp_filter.py --host D:\hake\lotus\host.log `
       --sp D:\hake\lotus\self_play.log
# ранний вариант — через 2–3 мин: --early 120 (при NOT-MATCHED не тратить матч)

# 3) восстановить чистый runner и проверить хэш
Copy-Item D:\hake\lotus\archive\20261123_fsl\bot_loop_run.lua.clean `
          D:\hake\lotus\src\bot_loop_run.lua -Force
Get-FileHash -Algorithm MD5 D:\hake\lotus\src\bot_loop_run.lua  # 60BE38ACE4DA9DEBDDD0B640D623F569
```

Зонд пишет в host-лог только `[fsl]`/`[fsl lh]`/`[fsl gate]`/`[fsl SWITCH]`-строки;
оригинальные `scripts/self_play/*.lua` не изменяются. Сессия выбирается по
`self_play.log`, прогон — по разрыву wall-времени >45 c; при нескольких прогонах
уточняйте `--session "YYYY-MM-DD HH:MM:SS"`.

### 10.5. Ретроспектива: как классифицируются уже сделанные прогоны

| Прогон | Доминирующая линия 0–300 c | Вердикт | LH@5 (score ≥300) | LH@10 |
|---|---|---|---|---|
| FSL 2026-11-23 02:31:30 (Treant 4/1) | lane1: **SK role=3 core 200 c**, viper role=1 50 c; lion support — всего 10 c в нашей линии (240 c settled он провёл в lane3) | **NOT-MATCHED** | 0 @ 5:08.0 | 3 @ 10:16.5 |
| AI-13 accept 2026-11-23 01:40:09 | `[fsl]`-зонда нет | **UNKNOWN** | 0 @ 5:08.2 → N/A | 0 @ 10:17.6 → N/A |
| 2026-11-23 02:23:22 (контрольный) | наша role=3 | **N/A-ROLE** | короткая сессия | — |
| эталон S26 (01:04:57) | nyx support, evidence 6:24 | MATCHED* | **5** @ 5:09.9 | **12** @ 10:10.0 |
| эталон S3 (04:23:34) | sand_king support, evidence 1:01 | MATCHED* | **4** @ 5:13.0 | 6 @ 10:13.1 |
| эталон S1 (03:12:52) | grimstroke support, evidence 1:37 | MATCHED* | **6** @ 5:12.3 | 10 @ 10:12.4 |

`*` — в эталоне нет roster-зонда: `MATCHED` выводится по причине свича
(`<hero> already supports our lane`), это нижняя оценка; у нас класс считается
по settled-присутствию из `[fsl]`.

**Следствия:**
- FSL-прогон (LH=5 к 11:18) — **не опровергает и не подтверждает** разрыв с S26:
  он `NOT-MATCHED`, поэтому LH-сравнение недействительно. Это согласуется с решением
  не трогать слой 2.
- AI-13 accept-прогон по правилу §10.2 получает **N/A** по LH@5/LH@10 (в §4
  поправка зафиксирована); остальные его метрики (кандидаты, режимы, parity_diff)
  остаются в силе.

### 10.6. Эталонные baseline для LH-сравнения

- Composition-matched, lane1: **S26 = 5 LH@5** (12 @10:10), **S3 = 4**, **S1 = 6**.
  Нюанс S1: 6 набраны в основном после свича 1:37 в lane3 с ядром
  (`REF_COMPOSITION §2`) — как «lane1-support» baseline корректнее S26=5 / S3=4.
- `--ref` показывает, что в matched-подмножестве эталона LH@5 разбросан 0–6: matched
  снимает конф-фактор гейта, но **сам по себе не гарантирует LH≥6** — второй лимитер
  (`ledger/noFlag`, `LAYER2 §5`) остаётся. Поэтому цель **LH@5 ≥ 6** предъявляется
  только на MATCHED, а при её недостижении следующий шаг — измерять не-гейтовые
  лимитеры (§6.3–6.4 LAYER2), а не менять `canLastHit`.

### 10.7. Ограничения

1. Фильтр только классифицирует: поведение бота не меняется (read-only зонд).
2. Координат крипов в логах нет, поэтому «прокси гейта» (ядро <1200 к нашему герою)
   в отчёте фильтра — диагностика, а не точное условие `d(core, creep) < 1200`.
3. Любой будущий acceptance обязан запускаться с `[fsl]`-зондом (§10.4), иначе
   вердикт `UNKNOWN` и LH@5 не засчитывается.
4. Эталон: полный ростер не восстановим (только имя partner-support из причины свича).
5. Классификация чувствительна к смене линии: если в окне была не одна линия,
   фильтр печатает `lanes`/`dominant_lane` и считает partner по доминирующей линии;
   такие прогоны лучше перепроверить вручную (или повторить матч).
