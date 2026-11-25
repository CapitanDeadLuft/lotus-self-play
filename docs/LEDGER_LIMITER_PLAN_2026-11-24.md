# План замера не-гейтовых лимитеров LH: `ledger/noFlag` (2026-11-24)

**Статус:** план и инструментарий **подготовлены**, независимый аудит — **READY FOR RUN**
(PASS 11 / PARTIAL 4 / FAIL 0; девиации исправлены в ревизии 24.11). Измерительный прогон
**не выполнялся** и сейчас **заблокирован build-дрифтом клиента** (§0).
Живые скрипты, Dota и acceptance-артефакты не менялись. Зонд — read-only, только счётчики.

**Основание:** `docs/ACCEPTANCE_2026-11-23.md §10.6` — при MATCHED-прогоне и `LH@5 < 6`
следующий шаг не правка `canLastHit`, а замер **не-гейтовых лимитеров**; второй лимитер —
покрытие предсказания смертей (`ledger/noFlag`), `docs/LAYER2_2026-11-23.md §5.2` и
`§6.3–6.4`. Первый (гейт) в зачётном прогоне fsl3 **по прокси** неактивен (0 % core-exposure,
`RUN_2026-11-23_fsl3.md §6`); прямого gate-счётчика тогда не было — H0 теперь измеряется
новым зондом (`gateE/seenE`) и обрабатывается правилом v1 (`INVALID-NON-GATE`/CAUTION).

**Зачётный контекст** (`archive/20261123_fsl3/RUN_2026-11-23_fsl3.md`): сессия
`2026-11-23 23:50:13`, Radiant, Treant, planner `role=4 lane=1`, **MATCHED** (partner-support
earthshaker role=4, 260 s в 0–300 / 420 s в 0–600), `LH@5 = 5` @334.6, `LH@10 = 7` @642.2,
0 свичей, `laneSettingBad=0`, exposure proxy `<1200` = 0 %. Цель `LH@5 ≥ 6` не достигнута.

**Что этот план НЕ делает:** не меняет `canLastHit`/`lane_rules.lua`, не внедряет Stage 2b/2c,
не переопределяет правило §10.2, не запускает Dota в рамках подготовки. Правка слоя ledger
или позиционирования — отдельный предрегистрированный этап после замера (§12).

---

## 0. Предусловие-блокер: смена билда Dota 6989 → 6993 (обнаружено 24.11)

`python src\check_build.py` (24.11.2026, ~21:26) сообщает **`!! BUILD CHANGED`**:

| | было (билд fsl3, 23.11) | сейчас (24.11) |
|---|---|---|
| ClientVersion | 6989 | **6993** |
| SourceRevision | 11264029 | **11269454** |
| PUO signature RVA | `0x1C191E0` | **`0x1C18C30`** (file `0x1c18030`, UNIQUE) |
| `dwLocalPlayerController` | `0x63E30A0` | без изменений (по dumper'у) |

`src/orders.lua` жёстко пинит `M.prepareUnitOrdersRVA = 0x1C191E0` (строка 57) и проверяет
сигнатуру при `M.init()` — на билде 6993 эта проверка **упадёт** (`setFatal`), т.е. **live-прогон
невозможен без обновления порта**. `check_build.py` при этом всегда выходит с кодом 0, поэтому
preflight (`preflight_ledger.ps1`) распознаёт строку `BUILD CHANGED` и жёстко останавливается.

**Что должно быть сделано ДО замера (отдельная maintenance-задача, вне scope этого плана):**
1) прогнать dumper (elevated, живая игра) и обновить offsets;
2) обновить `src/entity.lua` (`M.gamerulesRVA`), `src/api.lua` (gamerules line),
   `src/orders.lua` (`M.prepareUnitOrdersRVA` = `0x1C18C30`), `check_build.py` `KNOWN`
   (ClientVersion 6993, PUO RVA, entity list);
3) повторно зафиксировать хэши живых `scripts/` и `src/` (provenance), прогнать
   smoke/паритетные проверки порта (как после прошлых апдейтов клиента);
4) только после `OK: build matches the last known-good baseline` — шаг 0 run-book'а (§5).

**Следствие для статуса:** план и инструментарий готовы; **измерительный прогон заблокирован
до обновления порта под билд 6993**. Это не отменяет замер и не меняет его дизайн: `last_hit.lua`
(наш зонд) от смены RVA не зависит, но сам бот без обновлённых RVA не заработает. Побочный
эффект подготовки: `check_build.py` перезаписал `build_baseline.json` на текущий (6993) — это
штатное поведение инструмента, зафиксировано для purity-аудита.

---

## 1. Вопрос и гипотезы

**Вопрос.** Когда гейт неактивен (support-партнёр в линии), что именно режет LH: (а) крип не
попадает в кандидаты, потому что нет событий входящего урона (`noFlag` — «не созрел»), или
(б) крип/окно недоступны из-за позиционирования и таймингов (`in reach`/`window`), и в какой
пропорции эти причины дают отказы в окнах 0–300 и 0–600.

| Гипотеза | Проверяемое утверждение | Следствие |
|---|---|---|
| **H0 control** | гейт неактивен в 0–600: `gateE/seenE ≤ 0.05` | иначе прогон невалиден для «не-гейтовой» интерпретации (данные сохраняются, но вердикт `INVALID-NON-GATE`) |
| **H1 ledger** | `noFlag` доминирует: `noFlag_share ≥ 0.50` **или** покрытие событий `coverage_creep < 0.60` | Stage 2b: покрытие `ledger` (`LAYER2 §6.3`): расширить источники событий / смягчить порог зрелости |
| **H2 positioning/timing** | `noFlag_share < 0.35`, `coverage_creep ≥ 0.75`, `coverage_tick ≥ 0.85`, но `near_share < 0.50` (решающее правило — §6; конверсия/nowin — только диагностика, не критерий) | Stage 2c: позиционирование (`LAYER2 §6.4`) или тайминг окна |
| **H3 mixed** | метрики между порогами H1/H2, или 0–300 и 0–600 расходятся | нужен второй matched-прогон и/или раздельное A/B-внедрение |

**Ожидания по baseline (не критерий, а калибровка).** Исторический gate-free сеанс probe2
(22.11, смешанные союзные+вражеские крипы): `noFlag_share ≈ 0.40`, `evPos/chk ≈ 0.53`,
`cands/chk ≈ 0.07`, `chosen/cands ≈ 0.85`; ретро-прокси fsl3 (0–600): `in reach` 24/46 = 52 %,
`ours/in_reach` = 4/24 = 17 %, `addedHits>0` = 45 %. Оба намекают на H1/H3, но не различают
`noFlag` и тайминг — это и должен решить зонд.

---

## 2. Модель отказов `lastHit.plan` (live, CE33) и счётчики зонда

Конвейер решения (номера строк — live `scripts/self_play/last_hit.lua`, MD5
`CE33D41E8A477DE521C4CEB774B9AB79`):

| # | Стадия (код) | Условие | Счётчики `[ledg2]` | Что означает |
|---|---|---|---|---|
| 1 | `live(creep) and NPC.IsVisible and not blocked` (527–528) | видим, жив, не в blocked | `seenE/seenA` | база экспозиции (enemy/allied) |
| 2 | gate `denyable or (not allied and canLastHit)` (529–532) | враг проходит гейт; союзник — denyable | `gateE` (враг), `denyNo` (союзник) | H0: у support-партнёра `gateE ≈ 0` |
| 3 | state: не immune/invuln (533–534) | | `stateE/stateA` | Immune-крипы |
| 4 | range: `dist < max(cfg.searchRange, range+500)` (535) | ≤1300 у Treant | `farE/farA`, `__dist` | отсев по дистанции |
| 5 | maturity: `delay and minimum>0 and (health < minimum*2 or #events>0)` (540) | «созрел для удара» | `chkE/chkA`; `passE/passA`; **`noFlagE/noFlagA`**; `noDelayE`, `min0E` | **ядро замера**: noFlag = `delay and minimum>0 and #events==0 and health>=minimum*2` |
| 6 | events: `ledger()` (538) | события входящего урона | `evPosE/ev0E`, `evN1E/evN2E/evN4pE`, `srcAnimE/srcCycE/srcPredE` | покрытие ledger на крипа (creep-level) |
| 7 | build candidate: `window`/`towerPreparation`/`route`/`farmSafe` (551–594) | окно добивания + путь + безопасность | `candsE/candsA`, `norouteE`, `nowinE`, `unsafeE` | тайминг/маршрут/безопасность |
| 8 | choose: `timeline.choose` (601) | лучший кандидат | `chosenE/chosenA` | фактически выбранная цель |
| 9 | `execute` (606) | повторный gate-чек, движение/удар | **не инструментируется** | не меняем поведение |
| 10 | `hurt` (230–242): matched-событие по факту урона | | `hurtE/hurtEHero/hurtEMatch/hurtENo/hurtENodetect/hurtEMisattr` | обратная проверка recall ledger |
| — | агрегат | plan-вызовы в окне | `tickCall/tickChkE/tickEvE/tickPassE/tickCandsE/tickChosenE` | tick-level покрытие |

**Метрики** (анализатор `tools/ledger_probe_report.py`, окна 0–300, 300–600, 0–600;
основное — 0–600, вторичное — 0–300):

- `gate_share = gateE / seenE` — контроль H0;
- **`noFlag_share = noFlagE / (passE + noFlagE)`** — основная H1-метрика; чувствительность
  `noFlagE/chkE` (включает `noDelay`/`min0`, которых на lane-крипах практически нет);
- **`coverage_creep = evPosE / chkE`** — доля крипов, у которых ledger дал события;
- **`coverage_tick = tickEvE / tickChkE`** — доля plan-тиков, где хотя бы у одного
  вражеского кандидата есть события (устойчивее к числу крипов);
- `hurt_recall = hurtEMatch / (hurtE − hurtEHero)` — recall на фактических ударах по
  вражеским крипам в радиусе ≤2500 от нас (вторичная, консервативная);
- `near_share = d350E / chkE` — экспозиция вплотную (позиционная составляющая);
- `cand_rate = candsE / passE`, `conversion = chosenE / candsE`, `nowin_share`, `unsafe_share`;
- `noFlagCloseE/noFlagE` и `noFlagKillE/noFlagE` — насколько noFlag-крипы вообще «близки»
  и «почти убиваемы» (health < 4×minimum);
- источники событий (`anim`/`cyc`/`pred`) — диагностика канала ledger.

**Инварианты:** `chkE = passE + noFlagE + noDelayE + min0E`;
`evPosE + ev0E = chkE`; `d350E+d600E+d900E+d1300E ≤ chkE`; `chosenE ≤ candsE ≤ passE`.
Анализатор предупреждает (не падает), если инвариант нарушен.

**Read-only инварианты зонда** (проверяет аудит):
1. Единственная мутация ctx — собственное состояние `ctx.__ledg2`; `ctx.hits`, `ctx.role`,
   `ctx.mode`, `ctx.lastOrder` и прочие поля не пишутся.
2. `lastHit.plan`, `lastHit.execute`, `lastHit.hurt` возвращают ровно то же, что оригинал;
   вставки только считают и пишут лог. Никаких приказов/кастов/движений.
3. Роль-гейт `ctx.role >= 4`: при меньшей роли зонд — no-op (нулевой оверхед и ноль записей).
4. Никаких новых API-вызовов на крипа: `__dist` берётся из существующей проверки range.
   В `lastHit.hurt` (только для учтённых lane-creep hurt'ов) зонд повторно проверяет дешёвые
   read-only guards (`Entity.IsEntity`/`IsNPC`/`NPC.IsLaneCreep`), добавляет `Entity.IsSameTeam`
   для split enemy/allied, один `ctx.distance` на учтённый hurt (фильтр ≤2500) и до 3
   `NPC.GetUnitName` на окно для sample-строк. Приказов/кастов/движений нет.
5. Ошибка записи/`io.open` не пробрасывается в игровой код (nil-safe).

---

## 3. «Этот же состав»: что воспроизводим

Героев ботов **нельзя выбрать** (`REF_COMPOSITION_2026-11-23.md §4`: в `client.dll` есть
только `dota_bot_practice_select_hero` для героя человека; команд выбора героев ботов нет).
Поэтому «этот же состав» реализуется как **тот же класс условий**, а не буквальный ростер:

- Radiant, наш герой **Treant**;
- planner `role = 4`, `lane = 1` (как в зачётном прогоне; допускается role≥4 при MATCHED —
  фиксируется в отчёте, приоритет role=4/lane=1);
- **MATCHED** по `tools/comp_filter.py`: в нашей линии settled-партнёр-support (planner-роль
  ≥4) ≥60 c в окне 0–300, `gateE/seenE ≈ 0`; `MATCHED_SOLO` — допустимый вариант;
- ≥10–12 минут (до clock ≈ 700), чтобы окно 0–600 было полным;
- тот же `[fsl]`-зонд (состав/вердикт) и тот же `comp_filter` (ранний + полный).

Вероятность MATCHED при role≥4 по вечеру fsl3 — **1 из 5 (20 %)**; отсюда run-book с
ранними abort'ами (§6). Точный ростер и роли союзников записываются в `[fsl]`/`[ledg2]` и
отчёт; при другом (но matched) ростере результат остаётся валидным для замера лимитера, но
помечается как composition-class, не «identical roster».

---

## 4. Инструментарий

### 4.1 Файлы и хэши

| Файл | Роль | MD5 |
|---|---|---|
| `backup_scripts_20261116_023749\last_hit.lua.bak_20261120_213938` | pinned clean-база (== live на 24.11) | `CE33D41E8A477DE521C4CEB774B9AB79` |
| `patches\last_hit.lua.ledger_probe` | сгенерированный read-only probe-билд | `4372E014B57A18520F89F061CB286AD9` |
| `tools\make_ledger_probe.py` | детерминированный генератор (exact-once, luajit compile) | `8C9655C221A12BFBFCA593A17A919C82` |
| `tools\ledger_probe_install.ps1` | install/restore/verify probes, `-DryRun` | `2CFF4F41F655BC8FA9608261A1B1EA74` |
| `tools\ledger_probe_report.py` | анализатор `[ledg2]` + retro + предрегистрированный вердикт | `4D9E5B174CA40193B30A8F1B61DC8081` |
| `archive\20261123_fsl\bot_loop_run.lua.fsl_probe` | `[fsl]`-зонд (состав/clock/стоп) | `0994160F5254694B124CB07FEDF7846A` |
| `archive\20261123_fsl\bot_loop_run.lua.clean` | чистый раннер для restore | `60BE38ACE4DA9DEBDDD0B640D623F569` |
| `src\bot_loop_run.lua` (до install) | чистый раннер live | `60BE38ACE4DA9DEBDDD0B640D623F569` |
| live `scripts\self_play\last_hit.lua` (до install) | клиентский clean | `CE33D41E8A477DE521C4CEB774B9AB79` |

Provenance-дрейф: docs `ACCEPTANCE §1` пиннят `F52C068C…` (= CE33 + 8 инертных строк
`[denyexec]` под `rawget(_G,"__ROUTEDBG")`, только запись в host.log). Клиент перезаписал
live 23.11 09:16–11:18; фактическое состояние — CE33. **Для замера restore возвращает
именно CE33** (byte-identical pre-run), а не F52C; пере-фиксация реестра — отдельная задача
(`RUN_2026-11-23_fsl3.md §7 п.4`, `§10` next steps).

### 4.2 Зонд `[ledg2]`

- Лог: `D:\hake\lotus\probe_ledger.log`, маркер `[ledg2]`, префикс wall-time `HH:MM:SS`,
  одна агрегирующая строка не чаще 1/с match-clock + до 3 sample-строк `[ledg2 row]` /
  `[ledg2 hurt]` на окно.
- Полный контракт полей — `tools/make_ledger_probe.py` (docstring) и `§2` выше; ключи
  фиксированы и валидируются анализатором.
- `[ledg2] begin role=N` — маркер старта зонда (проверяется run-book'ом).
- Генератор: exact-once replace, `--check` компилирует билд
  `D:\hake\lotus\luajit\src\src\luajit.exe -e "loadfile(...)"`; два прогона дают один md5.
- EOL: билд пишется с LF (pinned-база — CRLF 711); для Lua это инертно, а `restore`
  возвращает CRLF-CE33 байт-в-байт. Зафиксировано в docstring генератора (девиация D1 аудита).
- `install` дополнительно пинит точный md5 probe-билда (`4372E014…`), а не только
  «≠ CE33 + маркер» (девиация D10).
- Старый `patches\last_hit.lua.probe2` (`064A9938…`) **не используется** (другая база и
  смешанные allied+enemy счётчики).

### 4.3 Установка/восстановление

`tools\ledger_probe_install.ps1 -Action install|restore|verify [-DryRun]`:

- `install`: отказ при запущенной Dota; проверка live CE33 и `src` 60BE38AC; backup live
  last_hit → `archive\20261124_ledger\last_hit.lua.before_install`; live ← probe-билд;
  `src\bot_loop_run.lua` ← `[fsl]`-зонд; ротация старого `probe_ledger.log` в архив; state
  `install_state.json`.
- `restore`: live ← backup; `src` ← clean-раннер; ротация probe-лога; проверки
  CE33/60BE38AC и отсутствия `[ledg2]`/`[fsl]` в живых файлах.
- `verify`: текущие хэши/наличие зондов/фазы state, exit code.
- `-DryRun`: только валидации и печать плана, **ноль записей** (используется в self-test).

### 4.4 Анализатор `tools/ledger_probe_report.py`

- Парсит `[ledg2]`, режет сессии по откату clock >30, агрегирует окна, считает метрики §2,
  валидирует инварианты и ключи, пишет provenance (пути/md5/размеры/lines/session/thresholds).
- `--retro` — только `self_play.log`: `[SelfPlay prediction]` addedHits, `[SelfPlay last hit]`
  allied/enemy/events, `[SelfPlay last hit stats]` died/in reach/ours/attempts, LH@5/LH@10.
- `--selftest` — синтетические строки и все ветки вердикта.
- `--comp-json` — вердикт `comp_filter.py` для `INVALID-COMPOSITION`.

### 4.5 Run-harness (`archive\20261124_ledger\`)

| Скрипт | Назначение |
|---|---|
| `preflight_ledger.ps1` | проверка build (src\check_build.py), отсутствие Dota/stop.txt, хэши pre-flight + CSV, опционально install (`-InstallProbes`) |
| `attempt_runner_ledger.ps1` | лотерея: launch elevated + inject host16.dll + UI-клики → pregame role≥4 → на clock≥210 **диагностический** early comp_filter (`--early 120`) → на clock≥310 **решающий** full comp_filter (0–300, MATCHED/MATCHED_SOLO) → на успехе запуск stop-watcher; ротация `probe_ledger.log` на каждый attempt; проверка, что probe/fsl не перезаписаны клиентом; guard при отсутствии probe-лога |
| `stop_watch_ledger.ps1` | ждёт `[fsl] clock ≥ 700`, пишет `stop.txt`, ждёт `=== BOT LOOP done ===`, убивает Dota |
| `finalize_ledger.ps1` | копии `host.log`/`self_play.log`/`probe_ledger.log` в архив, restore probes, post-run хэши, `comp_filter` + `ledger_probe_report`, `finalize_log.txt` |

Команды — §6. Скрипты подготовлены, но в рамках этой задачи только синтаксически проверены
(PowerShell AST); запуск — отдельное решение пользователя.

### 4.6 Приёмка инструментария (self-tests, 24.11)

Все проверки выполнены **без live-правок** (live `last_hit.lua` = CE33…, `src` = 60BE38AC…,
Dota не запускалась, `probe_ledger.log` отсутствует):

| Проверка | Результат |
|---|---|
| `python tools\make_ledger_probe.py --check` | PASS: 8/8 exact-once, markers OK, round-trip OK (вставки обратимы байт-в-байт), +197 строк, luajit `loadfile` exit 0 |
| генератор ×2 | идентичный md5 `4372E014…` (детерминизм) |
| `ledger_probe_install.ps1 -Action verify` / `-Expect clean` | exit 0; `-Expect installed` exit 1 (негативный контроль) |
| `install -DryRun` | exit 0, **zero writes**: live CE33 / src 60BE38AC до и после, state/backup/rotation отсутствуют |
| Lua runtime smoke (реальный билд, лог в %TEMP%) | begin/main/row/hurt форматы парсятся; 1.0 s окно; reset; role<4 no-op; `chkE` инвариант |
| `ledger_probe_report.py --selftest` | PASS 73 / FAIL 0, exit 0 (синтетика: окна, все ветви вердикта, malformed, JSON round-trip) |
| `--retro` на `fsl3/self_play.log.fsl3` | controls PASS 24/24: 127/68/54 %, 19=7+12, ev0=3, died=30/reach=17/ours=4/attempts=17; 224/100/45 %, 22=8+14, ev0=5, 46/24/4/22; LH@5=5, LH@10=7 |
| сверка контракта | `MAIN_FIELDS` генератора == `PROBE_FIELDS` анализатора (имена и порядок); smoke-лог: 0 malformed/unknown, инварианты OK |
| installer полный цикл | install→verify→restore в %TEMP%-песочнице (live не тронут): backup, rotation, state-фазы |
| PowerShell AST | 4/4 harness-скрипта PASS |
| purity | вне scope ничего не изменено; временных `probe_ledger.log` нет |

Артефакты приёмки: `archive\20261124_ledger\probe_tools_selftest.txt` (md5
`CDBD148325A7C5AC4FE03A4DF178379F`, RESULT: PASS), `probe_tools_selftest_driver.py`,
`analysis\Selftest*`, `analysis\retro_fsl3_ledger_proxies.txt|json`, `probe_build.diff.txt`
(266 строк diff, +203/−6; ревью Lead: семантика `lastHit.plan/execute/hurt` не меняется).

Известные small deviations (приняты, документированы в коде/отчёте):
1) `noFlagE` считается на plan-вызов, но отдельного `tickNoFlagE` нет (tick-семейство — только
   chk/ev/pass/cands/chosen); для H1 используется creep-level `noFlag_share`.
2) В `hurt` добавлен `Entity.IsSameTeam` на каждый учтённый hurt (нужно для split E/A) —
   read-only, редкий путь, ≤~25/с.
3) `chkA = passA + noFlagA` не утверждается (у allied нет noDelay/min0-счётчиков); инвариант
   проверяется только для enemy: `chkE = passE + noFlagE + noDelayE + min0E`.
4) `hurtE` включает наши собственные удары как `hurtEHero` (исключаются из знаменателя recall) —
   согласовано с формулой §2.
5) `install` требует live CE33 (не docs-F52C) — см. §4.1 provenance; backup CE33 не
   перезаписывается; `restore` предупреждает (не отказывает), если Dota запущена.
6) Sample-строки идут после agg-строки с тем же wall-префиксом; их `clock` — момент события.

Независимый аудит (24.11, отдельный исполнитель, свои парсеры): `verify_ledger_tools.txt`
(md5 `7A89C6870273A5D8C469D1527AFA1B2C`) — **PASS 11 / PARTIAL 4 / FAIL 0 (349 проверок) + ADDENDUM PASS 102 / FAIL 0;
вердикт READY FOR RUN**. Девиации D1–D11 исправлены в ревизии 2 (проверены addendum'ом): EOL-нормализация
задокументирована, инвентарь hurt-API уточнён, attempt_runner ждёт clock≥310 для full-гейта
и защищён guard'ом, installer пинит md5 probe, формулировки H2/артефактов/ссылок приведены
к правилу v1. Аудит live-состояние не изменил (live CE33, src 60BE38AC, Dota не запущена).

---

## 5. Run-book (последовательность)

Предусловия: Dota не запущена; `D:\hake\lotus\stop.txt` отсутствует; build = last known-good
(`src\check_build.py`); свободно ~30–60 мин; UAC-политика как в fsl3 (elevated launch/клики).

### Шаг 0. Pre-flight
1. `pwsh -NoProfile -File D:\hake\lotus\archive\20261124_ledger\preflight_ledger.ps1 -InstallProbes`
   — проверки, хэши, установка зондов, state. Preflight **обязан пройти build-gate**: строка
   `!! BUILD CHANGED` → скрипт падает с указанием обновить порт (§0); `OK: build matches…` → продолжаем.
2. Ожидаемый вывод: live last_hit = `4372E014B57A18520F89F061CB286AD9`, `src\bot_loop_run.lua` = `0994160F…`,
   в live-файле есть `ledg2Load`, в раннере — `[fsl]`; `install_state.json` phase=installed.

### Шаг 1. Лотерея матча
3. `pwsh -NoProfile -File D:\hake\lotus\archive\20261124_ledger\attempt_runner_ledger.ps1 -MaxAttempts 12`
   — на каждый attempt: abort role<4 (до horn); на clock≥210 — **диагностический** early
   comp_filter (`--early 120`, не решает); на clock≥310 — **решающий** full comp_filter
   (0–300) и abort при NOT-MATCHED; ротация лога зонда; на успехе `MATCHED_FOUND` + watcher.
4. Критерии принятия матча: MATCHED/MATCHED_SOLO по full comp_filter (на clock≥310); role≥4;
   hero=Treant; в `probe_ledger.log` есть `[ledg2] begin` к clock≈120. Критерий «первый
   `[fsl]` ≤120 c от старта сессии» и gate-share — **post-hoc** (ref-аудит/comp_filter),
   attempt не блокируют (девиация D8).

### Шаг 2. Прогон
5. Watcher сам останавливает bot loop на `clock ≥ 700` (stop.txt → `=== BOT LOOP done ===` →
   kill Dota). Если watcher упал: ручной стоп по тому же протоколу (fsl3 `stop_watch.ps1`,
   target 700). Признак валидности: ровно один `=== BOT LOOP ===`, 0 ошибок зонда, 0 крашей.

### Шаг 3. Восстановление и сбор
6. `pwsh -NoProfile -File D:\hake\lotus\archive\20261124_ledger\finalize_ledger.ps1 -Session "<session marker из attempt_log>"`
   — копии логов, restore зондов (CE33 / 60BE38AC), post-run хэши, comp_filter, отчёт
   анализатора; `finalize_log.txt` с хэшами restore.
7. Проверка чистоты: live last_hit = CE33, `src\bot_loop_run.lua` = 60BE38AC, в них нет
   `[ledg2]`/`[fsl]`; `scripts`/`src` — added/removed 0 (side effects — как в fsl3 §8).

### Шаг 4. Независимый аудит и отчёт
8. Ref-аудит: свой парсер пересчитывает вердикт comp_filter, LH@5/LH@10, окна и метрики
   `ledger_report`; сверка байт-в-байт с артефактами.
9. Purity-аудит: хэши до/после, restore, отсутствие мутаций ctx сверх `ctx.__ledg2`,
   0 приказов/кастов, append-only логи.
10. `archive\20261124_ledger\RUN_2026-11-24_ledger.md` — отчёт по шаблону §11.

### Стоп-условия и abort-политика

| Условие | Действие |
|---|---|
| role<4 pregame, hero≠Treant | abort до horn, попытка не считается (как fsl3) |
| NOT-MATCHED (full, clock≥310) | abort на clock≈310, лог зонда attempt'а — в архив, reroll (early на 210 — только диагностика) |
| live last_hit ≠ probe-md5 или нет `[fsl]` после launch | клиент перезаписал scripts → повторить install, перезапуск attempt |
| `[ledg2]` нет в 0–120 | зонд не загрузился → abort, restore/install, повтор |
| gate_share > 0.15 в 0–600 (post-hoc) | матч невалиден для не-гейтовой интерпретации → reroll |
| 12 attempts без MATCHED | зафиксировать лотерею, не выдавать LH-выводы; пере-план |
| краш/ошибки зонда/2+ `BOT LOOP` | прогон невалиден; restore, повтор |

---

## 6. Предрегистрированное правило решения v1

Окна: **primary 0–600**, вторичное 0–300. Все метрики — из `[ledg2]` за вычетом sample-строк.
Конвенция границ — правая граница включительно (как в анализаторе и retro-контроле):
`clock=300` попадает и в 0–300, и в 300–600; на 0–600 и на вердикт это не влияет, но в
отчёте стык окон фиксируется (девиация D5).

Порядок вычисления вердикта (реализован в `ledger_probe_report.py`; константы — в коде):

1. **Composition:** `--comp-json` отсутствует → `UNVERIFIED-COMPOSITION` (warning);
   verdict ∉ {`MATCHED`, `MATCHED_SOLO`} → **INVALID-COMPOSITION**.
2. **Gate control:** `gate_share > 0.15` в 0–600 → **INVALID-NON-GATE**;
   `0.05 < gate_share ≤ 0.15` → флаг `GATE-ACTIVE-CAUTION` (не отменяет вердикт).
3. **Sufficiency:** `chkE(0–600) < 100` или `tickChkE(0–600) < 30` → **INSUFFICIENT**
   (замер недоказателен; нужен более длинный/второй прогон).
4. **H1:** `noFlag_share ≥ 0.50` **или** `coverage_creep < 0.60` → **LEDGER-DOMINANT**
   → Stage 2b (покрытие ledger; `LAYER2 §6.3`).
5. **H2:** `noFlag_share < 0.35` **и** `coverage_creep ≥ 0.75` **и**
   `coverage_tick ≥ 0.85` **и** `near_share < 0.50` → **POSITIONING-DOMINANT**
   → Stage 2c (позиционирование; `LAYER2 §6.4`).
6. Иначе → **MIXED** (второй matched-прогон; при внедрении — разделять слои).
7. **Window stability:** если категория вердикта на 0–300 и 0–600 различается — пометить
   `UNSTABLE (2nd run needed)`, вердикт по 0–600 остаётся, но решение о правке откладывается
   до второго прогона.

**Что фальсифицирует H1:** `gate_share ≤ 0.05` и `noFlag_share < 0.35` при
`coverage_creep ≥ 0.75` на обоих окнах — тогда ledger не главный лимитер, смотреть H2.
**Что фальсифицирует H2:** низкий `near_share` объясняется тем, что noFlag не даёт боту
подойти к волне (self-sustaining loop) — тогда причина всё равно в ledger (H1), и это
фиксируется в отчёте как каузальная оговорка.

Вердикт — **диагностический**; он не запускает правку кода. Stage 2b/2c имеет собственные
критерии и A/B (предрегистрация — отдельным документом).

---

## 7. Baseline и ретро-данные

### 7.1 Ретро-прокси зачётного matched-прогона (fsl3, session 23:50:13; без ledger-зонда)

Из `archive/20261123_fsl3/self_play.log.fsl3` (воспроизводится
`ledger_probe_report.py --retro`):

| Окно | prediction lines | addedHits>0 | last-hit lines | enemy / allied | events==0 | died | in reach | ours | attempts | LH |
|---|---|---|---|---|---|---|---|---|---|---|
| 0–300 | 127 | 68 (54 %) | 19 | 12 / 7 | 3 | 30 | 17 | 4 | 17 | 5 @334.6 |
| 0–600 | 224 | 100 (45 %) | 22 | 14 / 8 | 5 | 46 | 24 | 4 | 22 | 7 @642.2 |

Интерпретация: в 0–600 46 вражеских крипов умерли рядом, 24 — в reach (52 %), а `ours` = 4
(17 % от in-reach). То есть основная потеря — **после** того, как крип оказался в reach;
это согласуется и с `noFlag` (крип «не созрел»), и с таймингом окна — различает только зонд.

### 7.2 Исторический gate-free probe2 (22.11, `archive/20261122_layer2_ledger/probe.log`, сеанс 22:15–22:2x)

Агрегат 0–600 (смешанные allied+enemy, старый probe2, gate=0):

| seen | chk | gate | denyNo | pass | noFlag (`hpHiEv0`) | evPos | ev0 | cands | chosen | nowin | noroute |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 9238 | 3749 | 0 | 5243 | 2258 | 1491 | 2005 | 1744 | 274 | 234 | 1979 | 90 |

Производные: `noFlag_share = 1491/(2258+1491) = 0.40`; `evPos/chk = 0.53`;
`cands/chk = 0.07`; `chosen/cands = 0.85`. `[hurtcov]`: total 15631, hero 49, match 1999,
no 13583 (recall ≈13 % — но без фильтра ≤2500, поэтому новый зонд считает recall только
по ближним ударам; старое число — нижняя граница, не сравнение 1:1).

Ограничения baseline: mixed allied+enemy; другая база/билд (`064A9938…` на F52C); нет
разделения enemy/allied; нет tick-уровня. Используется только как порядок величин.

### 7.3 Эталон

`S26` (matched, nyx support до 6:24): `LH@5 = 5`, `LH@10 = 12`; `S3` = 4/6; `S1` = 6/10.
Наш LH@10 = 7 отстаёт от S26 сильнее, чем LH@5 (5 vs 5): отставание накапливается во времени —
совместимо с систематическим голодом кандидатов (ledger/позиционирование), а не с разовым
гейтом. Эталонных `[ledg2]`-счётчиков нет; сравнение только по LH.

---

## 8. Чистота, provenance, аудит

- **Живые скрипты:** install/restore строго через `tools\ledger_probe_install.ps1`;
  restore обязан вернуть live last_hit `CE33…` и `src\bot_loop_run.lua` `60BE38AC…`;
  проверка отсутствия `[ledg2]`/`[fsl]` в живых файлах.
- **Probe-артефакт** `patches\last_hit.lua.ledger_probe` — остаётся в репозитории как
  воспроизводимый билд (генерируется детерминированно), но не устанавливается вне прогона.
- **Acceptance-правило §10.2 не меняется:** `canLastHit` эталонный; LH@5≥6 — только на
  MATCHED. Этот прогон — диагностический: LH@5/LH@10 фиксируются для контекста, но не
  являются acceptance-замером Stage 2b/2c. Зонд не участвует в LH-метрике (read-only).
- **Pre-existing drift** (`Self Play.lua C6777A6D…` vs docs `DA513CE3…`, last_hit `CE33…` vs
  docs `F52C…`) фиксируется в pre-flight и отчёте; пере-фиксация в ACCEPTANCE §1 — отдельная
  задача (не блокирует замер, т.к. restore возвращает фактическое pre-run состояние).
- **Аудит (после прогона):** ref-аудит (независимый парсер: comp verdict, LH@5/10, окна,
  метрики, сверка байт-в-байт) + purity-аудит (read-only инварианты, хэши, 0 приказов,
  restore). **Аудит инструментария до прогона выполнен 24.11:** `verify_ledger_tools.txt` —
  PASS 11 / PARTIAL 4 / FAIL 0 (349 проверок), вердикт **READY FOR RUN**; девиации D1–D11
  исправлены, блокирующих замечаний нет.

---

## 9. Ограничения и риски

1. **Один matched-матч** и случайный ростер; support-партнёр может уйти из линии в середине —
   `gate_share` вырастет; предусмотрен post-hoc флаг `INVALID-NON-GATE`/`CAUTION` и разбивка
   окон, но причинность «noFlag → LH» остаётся корреляционной.
2. **Разделение noFlag/тайминга:** `window()` отказ (`nowin`) — это уже «крип был кандидатом,
   но окно не сложилось»; noFlag — «кандидатом не стал». Позиционная составляющая
   (`near_share`) измеряется, но причинный порядок «noFlag не даёт подойти» vs «стоим далеко»
   полностью не разделяется; это фиксируется как ограничение.
3. **Recли ledger:** `hurt_recall` измеряет совпадение событий с фактическим уроном только
   для ближних lane-крипов; события вражеских героев/абилок имеют свою специфику.
4. **Оверхед зонда:** счётчики + один `ctx.distance` на hurt; при просадке `[perf]`/крашах —
   abort и повтор; probe-код в pcall не оборачивается (только nil-safe io), но все вставки —
   «if __l2 then», без новых вызовов на крипа.
5. **Клиент перезаписывает `scripts/`** после рестарта: проверка live-md5 перед каждым
   attempt; при перезаписи — install и перезапуск.
6. **Окна:** 0–300 vs 0–600 могут расходиться (H3/UNSTABLE) — тогда второй прогон обязателен.
7. **Полночный баг `comp_filter`** (окно по wall-date): при переходе через полночь окно
   0–600 может обрезаться; метрики зонда считаются по match-clock (не по wall), а вердикт
   композиции при необходимости пересчитывается вручную (прецедент fsl3 §3.2). В отчёте
   фиксируется время старта/остановки.
8. **Точный ростер невоспроизводим** (REF_COMPOSITION §4): «этот же состав» = same
   composition class (MATCHED), а не identical roster; это явное ограничение замера.
9. **Один запуск = один шанс на редкий матч:** 12 attempts × ~6–7 мин + 12 мин прогон ≈ 60–90 мин.
10. **Инструментарий не является acceptance-критерием:** отчёт замера не заменяет
    приёмочный прогон после будущих правок.
11. **Смена билда клиента (блокер, §0):** на 24.11 build 6993, PUO RVA сменился; до обновления
    `src/orders.lua`/`entity.lua`/`api.lua` и dumper'а бот не запустится. После обновления
    порта обязательны pre-flight хэшей и smoke-проверки; `last_hit.lua`-зонд от RVA не зависит,
    но чистота прогона должна быть пере-зафиксирована.

---

## 10. Артефакты и формат отчёта

`archive\20261124_ledger\`:

- `pre_flight_ledger.txt`, `pre_flight_src_hashes.csv`, `pre_flight_scripts_hashes.csv`;
- `install_state.json`, `probe_tools_selftest.txt`;
- `attempt_log.txt`, `probe_ledger_attempt<N>.log` (abort'ы), `probe_ledger.log` (winner);
- `host.log.ledger`, `self_play.log.ledger`, `probe_ledger.log.ledger`;
- `stop_watch.txt`, `finalize_log.txt`, `post_run_*.csv`;
- `comp_filter_ledger_raw.txt` (+ `.json`), `ledger_report.txt|json`, `retro_ledger_run.txt`
  (+ console-логи `*_console.txt`; имена соответствуют `finalize_ledger.ps1`, девиация D7);
- `RUN_2026-11-24_ledger.md` — итог; `verify_ref_ledger.txt`, `verify_purity_ledger.txt`.

Отчёт (`RUN_2026-11-24_ledger.md`) повторяет структуру fsl3: §1 процедура/таймлайн, §1.1
ростер/роли, §2 хэши/чистота, §3 вердикт композиции, §4 метрики `[ledg2]` (таблицы по окнам),
§4.1 hur/coverage, §5 вердикт правила v1 + стабильность окон, §6 сравнение с baseline/эталоном,
§7 ограничения, §8 аудиты, §9 артефакты, §10 следующий шаг (Stage 2b/2c/mixed).

---

## 11. Дерево решений после замера

| Вердикт v1 | Следующий шаг (отдельная задача) |
|---|---|
| **LEDGER-DOMINANT** | `Stage 2b` (`LAYER2 §6.3`): расширить источники событий входящих ударов (атаки союзных крипов/башни через `LaneGroupsManager`/поллинг `NPC.IsAttacking`), либо смягчить порог зрелости для role>3 при `creepPressure>0` (`health < minimum*3`). Предрегистрация + A/B. |
| **POSITIONING-DOMINANT** | `Stage 2c` (`LAYER2 §6.4`): `positioning.holdSpot`/`helpers.laneAnchor` (`Self Play.lua:922–967`); менять после замера `myD`/`near_share`. |
| **MIXED** | Второй matched-прогон; при подтверждении — разделять слои (ledger сначала, т.к. он «ворота кандидатов», затем позиционирование). |
| **INVALID-COMPOSITION / INVALID-NON-GATE** | Повторить замер на другом matched-матче (лотерея); ничего не чинить. |
| **INSUFFICIENT / UNSTABLE** | Удлинить прогон (clock≥800) или второй matched-матч. |

**Не делать сейчас:** правку `canLastHit`, `lane_rules.lua`, `last_hit.lua`, `Self Play.lua`
и любые изменения `src/` — до результатов замера и отдельной предрегистрации.

---

## 12. Что не входит в эту задачу

- Live-прогон матча и UI-автоматизация (только подготовленный harness; запуск — по решению
  пользователя).
- **Обновление порта под билд 6993** (`src/entity.lua`, `api.lua`, `orders.lua`,
  `check_build.py`, dumper) — отдельная maintenance-задача-блокер (§0); без неё замер не
  запускается.
- Правки `comp_filter.py`/`layer2_fsl.py` (полночный баг) и пере-фиксация хэшей в
  `ACCEPTANCE §1` — отдельные задачи (см. `RUN_2026-11-23_fsl3.md §10` п.3).
- Изменение `canLastHit`/слоя 2 — отклонено (§10 LAYER2) и не пересматривается.