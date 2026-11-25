# freeSupportLane — condition-matched прогон на чистых скриптах (2026-11-23)

Цель: прогнать матч с составом, где support-союзник стоит в нашей линии и есть
сайд-линия только с ядром, чтобы оригинальный `lane_choice.freeSupportLane`
исполнил свич; зафиксировать `[SelfPlay lane]` и LH до/после. **Свич сработал**
(clock 157.9, 3→1, «lion already supports our lane; top has a core with no support»).

## 1. Чистота скриптов

Оригиналы не менялись, md5 до и после прогона совпадают:

| Файл | md5 |
|---|---|
| `Self Play.lua` | `DA513CE34C524EB7FB2AA5EE7A07EAC2` |
| `self_play/lane_choice.lua` | `A14EA5C86F11575E576C0E821744D3B5` |
| `self_play/planner.lua` | `C30C751F728444BF66DEA879EC685699` |
| `self_play/lane_rules.lua` | `BEC5932A1C125C9A4E9C6541355D0CE1` |
| `self_play/catalog.lua` | `8C13948E29BE1054A6A45BBBD4B7AD86` |
| `self_play/last_hit.lua` | `F52C068C1CE6B3EB5589673A6FBD1F10` (чистый, без probe2) |

- Раннер `src/bot_loop_run.lua`: авто-режим `roleWidget:Set(0)` / `laneWidget:Set(0)`
  (строки 56/82), на прогон добавлен **временный read-only зонд `[fsl]`**
  (обёртка `lane_choice.update` без изменения результата; ростер + реплика
  `choice.counts`/`freeSupportLane` на собственном settle-состоянии + LH из
  `Player.GetTeamPlayer(ctx.player)` — те же счётчики, что `[SelfPlay score]`,
  Self Play.lua:1989). Версия с зондом: md5 `0994160F5254694B124CB07FEDF7846A`
  (архив `bot_loop_run.lua.fsl_probe`). Ошибок зонда за прогон: **0**.
- После прогона раннер восстановлен из `bot_loop_run.lua.clean`:
  md5 **`60BE38ACE4DA9DEBDDD0B640D623F569`** (чистый, как до прогона).
- Инжект `host16.dll` `60C50197AC1F7E60C2135AE33A7C6711`, ровно один
  `=== BOT LOOP ===` на инжект; виджеты на загрузке `Position value=0` /
  `Lane value=0` (host.log 02:31:29).

## 2. Матч

- Сессия Self Play: **2026-11-23 02:31:30**; game start `gs=149.233`
  (`[clock] anchor` 02:32:42). Radiant, Treant Protector, одиночная против
  ботов (Стандартные боты, ЛЁГКИЕ, СИЛЫ СВЕТА — проверено кропом).
- Ростер (planner.assignRoles): **Treant=4\*, Lion=5, Viper=1, Skeleton King=3,
  Sven=2**. `ctx.role=4`, `ctx.lane=1` (offlane top), `laneSetting=0`.
- Отбор состава: 3 запуска. №1 (02:23) — planner дал Treant role=3 → гейт
  `role<4` (lane_choice.lua:91) закрыт, reroll. №2 (02:25) — клик СИЛЫ СВЕТА не
  прошёл, команда СЛУЧАЙНО, матч стартовал сам в фоне → kill, reroll.
  №3 (02:31) — role=4, состав ниже.
- Лейнинг к clock 30: Treant+SK(3) top, Lion(5)+Viper(1) bottom (Viper затем
  mid), Sven(2) mid. Остановка `stop.txt` на clock ≈688 (02:44:14), последний
  `[fsl lh]` clock=686.3. Крашей нет.

## 3. Свичи линии (оба — оригинальный lane_choice)

**Свич 1 — crowded-ветка (early), clock 97.1 (1:37), 1→3.**
Treant+SK(3) в top (`own=2`), в bottom 1 союзник → ветка
`current == standard and own >= 2` (lane_choice.lua:107–112).

```
[1:36] [SelfPlay lane] top -> bottom: our lane is crowded: 2 allies here, 1 there
[1:38] [SelfPlay lane] switch 1 -> 3 (allies there 1, here 2)
```

**Свич 2 — freeSupportLane, clock 157.9 (2:38), 3→1.** После свича 1 Treant
оказался в bottom с Lion(5) (`supports[3]=1`), top — SK(3) соло
(`supports[1]=0, cores[1]=1`) → условие lane_choice.lua:53–62 выполнено,
ветка :102–104, коммит :127–134.

```
[2:37] [SelfPlay lane] bottom -> top: lion already supports our lane; top has a core with no support
[2:38] [SelfPlay lane] switch 3 -> 1 (allies there 1, here 1)
[2:41] [SelfPlay lane] switch 3 -> 1 (allies there 1, here 1)   (повтор laneStatus в 4-с окне, Self Play.lua:2112)
```

Зонд на границе (counts/sup/core по лейнам 1/2/3, `free` — вердикт реплики):

```
02:35:13 [fsl] clock=150.9 role=4 lane=3 … lion r=5 lane=3 set=1 … skeleton_king r=3 lane=1 set=1 … counts=1/1/1 sup=0/0/1 core=1/1/0 supNames=-/lion free=1
02:35:20 [fsl SWITCH] clock=157.9 lane=3->1 reason=lion already supports our lane; top has a core with no support | LH=0 denies=1 (prevLH=0 @157.6)
02:35:23 [fsl] clock=161.0 role=4 lane=1 … counts=1/1/1 sup=0/0/1 core=1/1/0 … free=nil
```

Тайминг согласуется с оригиналом: cooldown 60 с после свича 1
(97.1+60=157.1, lane_choice.lua:5/126) + confirm 6 с (lane_choice.lua:4/126).

Финал `[fsl gate]`: `calls=5683 eligible=3859 lowRole=0 laneSettingBad=0
clockOut=1824 switches=2` — гейт role>=4/laneSetting==0/30≤clock<600 пройден
3859 раз, блокировок по роли/виджету не было.

## 4. LH до/после freeSupportLane-свича

`[SelfPlay score]` (оригинал, 60-с шаг) + `[fsl lh]` (10-с шаг):

| clock | мин | lane | LH | denies | xp | laneGold |
|---|---|---|---|---|---|---|
| 61.3 | 1:01 | 1 | 0 | 0 | 191 | 0 |
| 120.9 | 2:00 | 3 | 0 | 1 | 449 | 0 |
| **157.9** | **2:38 свич** | **3→1** | **0** | **1** | — | — |
| 183.2 | 3:03 | 1 | 0 | 1 | 648 | 0 |
| 308.0 | 5:08 | 1 | 0 | 3 | 1161 | 0 |
| 492.9 | 8:12 | 1 | 0 | 4 | 1896 | 48 |
| 555.3 | 9:15 | 1 | **1** | 4 | 2128 | 132 |
| 616.5 | 10:16 | 1 | **3** | 4 | 2457 | 231 |
| 678.0 | 11:18 | 1 | **5** | 4 | 2943 | 331 |

- **До свича (0–2:38): LH 0, denies 1.** На границе: `[fsl lh]` 150.9 = 0/1,
  161.0 = 0/1; `[fsl SWITCH]` LH=0 denies=1.
- **После: LH 0 до 8:12, затем 1 (9:15) → 3 (10:16) → 5 (11:18); denies 4.**
  Рост начался в gate-free окнах (SK >1200 от крипов / роум), тот же механизм,
  что в S1/S26 (REF_COMPOSITION_2026-11-23.md §2).
- Решения `[SelfPlay last hit]`: **13 строк, 12 goodguys / 1 badguys**; первое
  решение по вражескому крипу — `[9:46] … badguys_ranged … inRange=true`
  (совпадает с началом роста LH). Смещение в денаи сохраняется (слой 2,
  ACCEPTANCE_2026-11-23.md §3.3).

## 5. Сравнение с эталоном и выводы

| | наш прогон | S26 | S1 |
|---|---|---|---|
| свич freeSupportLane | 2:38 (lion) | 6:24 (nyx_assassin) | 1:37 (grimstroke) |
| причина | «lion already supports our lane; top has a core with no support» | «nyx_assassin already supports our lane; bottom has a core with no support» | «grimstroke already supports our lane; bottom has a core with no support» |
| LH на момент свича | 0 | 5 (5:09) | 1 (1:12) |
| LH после | 5 @11:18 | 12 @10:00 | 6 @3:12 |

1. **Оригинальный `lane_choice` на чистых скриптах работает точно как в
   эталоне**: то же условие `freeSupportLane`, тот же формат причины, те же
   confirm/cooldown; `laneSetting=0` не блокирует логику (`laneSettingBad=0`),
   role=4 от planner проходит гейт (`lowRole=0`). Свич 1→3→1 полностью
   управляется оригиналом (crowded → freeSupportLane).
2. **Разрыв LH (5 против 12 к 10 мин) — не lane_choice**: после свича Treant
   стоит с SK(3), `lane_rules.canLastHit` (lane_rules.lua:16–21) блокирует ЛХ
   при ядре в 1200 от крипов; 12 из 13 решений — денаи. Это известный слой 2
   (ACCEPTANCE §6.3), XP @10:16 = 2457 против 7955 у S26 — тот же слой.
3. Состав с support-партнёром воспроизведён перебором (3 запуска); условие
   возникло после crowded-свича, который сам привёл Treant в линию Lion.

## 6. Артефакты

- `archive/20261123_fsl/host.log.fsl` — host-лог всех 3 запусков (зонд `[fsl]`).
- `archive/20261123_fsl/self_play.log.fsl` — лог скрипта (сессия 02:31:30).
- `archive/20261123_fsl/bot_loop_run.lua.fsl_probe` (`0994160F…`) и
  `bot_loop_run.lua.clean` (`60BE38AC…`, восстановлен в `src/`).
- Скриншоты UI: `shots/fsl_*.png`, `shots/fsl_r2_*`, `shots/fsl_r3_*`.
- Зонд `[fsl]` удалён из раннера (хэш восстановлен); оригинальные скрипты не
  тронуты (хэши §1).
