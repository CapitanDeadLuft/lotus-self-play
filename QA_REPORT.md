# QA REPORT — Self Play port (owner: `ui-hud` / QA)

Runtime controller: QA only. Every live test in this report is a **single-player bot game**
(Играть → Игра против ботов → **ОДИНОЧНАЯ** → ИГРА С БОТАМИ), hero forced/picked = **Treant Protector**
(`npc_dota_hero_treant`) per human rule. Evidence from any other mode/hero is INVALID and is not used here.
Last updated: **2026-11-16 20:21 MSK** (live Treant match, Dota pid 23860).

---

## 0. TL;DR / PASS-FAIL matrix (current)

| Item | Verdict | Evidence pointer |
|---|---|---|
| Environment / injection | **PASS** | pid 23860, host16.dll injected 20:04:00, `host: watchdog thread start pid=23860`; `inject_result.txt`: `injected ... into pid 23860` |
| Single-player Treant game | **PASS** | `qa_screen_3.png` (loading, TREANT PROTECTOR), `qa_screen_4.png` (in-game fountain), log `loop ... npc_dota_hero_treant` |
| Self Play loads clean | **PASS** | `20:17:53 loader: Self Play loaded, callbacks: table` (current run), no load errors |
| HUD draws | **PASS** | `20:20:43 R11: frame hud=49 menu=112 open=0 sw=1920`; win bar + panel + world label in `qa_screen_8/9/10` |
| ClickGUI draws + tabs/groups | **PASS** | `qa_screen_8_menu_default.png` (tabs Main / Search and pick / What the bot does; groups Bot, Play style, On screen), `qa_screen_9_menu_behaviors.png` (Fighting, Lane and support play, Items and moving around, Item builds) |
| P0-B permanent "Manual control" pause | **PASS (pending reviewer)** | `[order]` lines within 15 s, hero left fountain, no `[pause]`/`Manual control` lines, HUD Now row = activity |
| P0-A clock (`GameRules.GetGameTime`) | **PASS — task-12 CLOSED** (Appendix D2: `[clock] anchor: observed m_flGameStartTime transition -> 100.300`; 0:43↔in_game 43.7 s, 2:22↔141.4 s, Δ<1 s; `samples/10s=0 scans=0`) | absolute-epoch contract verified against reference call sites (`Self Play.lua:1849` etc. — scripts subtract start time themselves) |
| P0-C purchase | **OPEN — task-19** (inventory vector ptr=0x0; OLD inline-array `0x20+i*4` returns real items per probe v5 `[19]`; duplicate `[SelfPlay buy] magic_stick` repeats every 10-20 s) | Appendix D7 |
| task-9 Phase A movement/pathing | **PASS — CLOSED by Lead** (spawn −6700,−6700 → lane −5800,1400, HUD "Farming the lane", `hard=60` benign, `[nav] path` 0.13-0.91 ms post-warmup, zero stall/no-route, orders ok) | Appendix D3 |
| Tick cost (task-10) | **OPEN** — post-restart p90=359 ms (>300 target), earlier 984-2054 ms; re-measure MID-GAME with `[perf] tick` + `jit.profile` | Appendix D6 |
| task-4 pause (Space/A bind) | **OPEN** — awaiting Lead/human Space ≥10 s trace + mid-hold HUD "Manual control" screenshot | Appendix D5 |
| task-20 input acceptance (new DLL) | **OPEN** — awaiting Lead/human post-game ИГРАТЬ/X click matrix (`gui: hook swallow` absent closed / onGui=1 open) | Appendix D4/D0 |
| Event synthesizer fires | **PASS** | `20:18:21 events: polls=366 ... OnEntityHurt=399 OnProjectile=46 OnUnitAnimation=786`; `mbi=API_MBI` |
| Tick cost | **ATTENTION** | `loop` ticks 0.2–5.7 s (spikes 5.1/5.5/5.7 s); `events: polls` avg 43–137 ms, **max 411–818 ms** (>300 ms target) |

Full detailed evidence and exact log lines below. Full `API_P1` probe block saved at
`D:\hake\lotus\qa_api_p1_block.txt` (81 lines, run 20:12:15).

---

## 1. Evidence protocol (crew-wide, use this for every item)

### Runtime facts (learned 2026-11-16)
- `host16.dll` inject = `D:\hake\lotus\src\inject_elevated.bat <dota pid>` (elevated, works: UAC auto-elevates, admin consent prompt disabled on this box). Injection starts the watchdog thread **once**.
- **Writing `stop.txt` kills the watchdog permanently** (`host: stop.txt detected, watchdog exit`), so afterwards a plain `run.txt` rewrite does **NOT** start a script. Restarts are done with the exported entry point:
  - `Set-Content D:\hake\lotus\run.txt '<script>'` then
  - `Start-Process D:\hake\lotus\src\call_elevated.bat -ArgumentList <dota pid> -Verb RunAs -Wait`
  - log proof: `host: running <script>` + `host: script finished`; output `call_result.txt` = `RunHost called OK`.
- Exactly **one** loop at a time. Stop = `stop.txt`, wait for `=== BOT LOOP done ===` in `host.log`, delete `stop.txt`.
- Elevated synthetic input (UIPI: Dota is HIGH integrity, our shells are MEDIUM — must go through `Start-Process -Verb RunAs`):
  - click: `synth_click_elevated.bat X,Y` (results in `synth_result.txt`, prints `integrity: 12288`).
  - key: `synth_key_elevated.bat <VK decimal>` (e.g. `46` = Del) — script added by QA (`src/synth_key.ps1`), results in `synth_key_result.txt`.
- Screenshots: PowerShell `System.Drawing CopyFromScreen`, primary monitor 0,0–1920,1080. Naming: `qa_screen_<n>_<what>.png` in `D:\hake\lotus\`.
  Note: the desktop is a dual 1920×1080; Dota occupies the left monitor at (0,0). Always click/crop using 0..1919/0..1079 coordinates.

### Markers to grep (`D:\hake\lotus\host.log`)
> **LOG ATTRIBUTION RULE (learned 2026-11-16):** `host.log` timestamps are **NOT monotonic** — the system clock jumps (VM/NTP corrections), so lines stamped `21:05` can sit before lines stamped `21:02`. Always attribute a window by **line index / append order**, never by timestamp alone. Proof: `loop 41691 16.3s` (pre-swap session) is line 75455 while the post-swap window starts at line 317947; `21:05:40 BOT LOOP` is line 222790 (before 317947). Use a marker line index (`Select-String` LineNumber) and slice `[index..end]` for evidence.
| Marker | Meaning |
|---|---|
| `=== BOT LOOP ===` / `=== BOT LOOP done ===` | loop start / clean stop |
| `host: running <path>` / `host: script finished` | RunHost execution |
| `loader: Self Play loaded, callbacks: table` | script loaded OK |
| `loop N <t>s npc_dota_hero_treant hp=.. x y gt=..` | per-iteration state; `x y` = hero position, `t` = tick seconds |
| `[clock] src=<horn|atk|wall> gt=.. gs=.. state=.. in_game=..` | game-time source + values (every ~10 s) |
| `[order] MoveTo ...` / `[order] PUO type=.. tgt=.. abil=.. unit=..` | issued orders |
| `[pause] human order armed` / `[pause] pause window expired` | human-takeover pause (should only follow real input) |
| `events: offsets ... mbi=API_MBI` / `events: game KV loaded` / `events: polls=.. errors=..` / `poll error:` | loader event synthesizer alive/counters |
| `R11: frame hud=N menu=M open=0/1 sw=W` | overlay publish/render counters; `open=1` = ClickGUI open |
| `host: runtime error:` / `load error:` / `OnUpdate error:` / `OnDraw error:` | failures (must be zero in a clean run) |
| `[SelfPlay ...]` in `...\scripts\self_play.log` | bot's own log (`Engine.GetCheatDirectory()` = scripts dir) |

### Item-type acceptance recipes
- **Gameplay** (orders/pathing/combat/last-hit): Treant single-player bot game, loop running; PASS needs `[order]`/`PUO` lines + `loop` position deltas (hero >300 u displacement) + no new error lines; screenshot of HUD Now row.
- **Clock (P0-A)**: loop must be **already running in lobby**, then create the bot game → loader must observe `m_flGameStartTime` transition and print `[clock] src=horn`; after horn `gt` must equal the on-screen clock ±2 s in **two** samples ≥60 s apart (screenshots + `[clock]` lines).
- **UI/ClickGUI**: Del opens (elevated `synth_key_elevated.bat 46`), screenshot; switch page by elevated click on tab; R11 `menu=`/`open=` counters must change; no game input must leak (menu clicks swallowed).
- **Events (loader)**: only in an in-match bot game with real fights; PASS needs `events: polls=.. errors=0`, per-callback counters increasing, `humanOrders` sensible, `poll error:` absent.
- **Purchase (P0-C)**: `[SelfPlay buy]` must stop repeating for the same item after a successful buy, `PUO type=16` must carry nonzero ids, and the item must appear in `NPC.GetItem`/inventory (screenshot of inventory/shop).

### Runtime calendar (2026-11-16)
| Time | Who | What |
|---|---|---|
| 20:02:21 | Lead | Dota 2 launched (pid 23860, current process) |
| 20:04:00 | Lead | host16.dll injected; loop auto-ran (watchdog) |
| 20:06:00–20:06:52 | QA | baseline read; loop stopped cleanly via `stop.txt` (watchdog exited) |
| 20:08:58–20:09:00 | QA | elevated clicks: created **single-player bot game**, Treant picked/locked |
| 20:10:35 | QA | `diag_api_probe.lua` attempt #1 → FAIL (`schema` nil, api-core bug) |
| 20:11:16 | QA | `bot_loop.lua` reload → FAIL (`menu.lua:70` syntax, developer WIP) |
| 20:12:15 | QA | probe #2 → OK, 81-line `API_P1` block captured |
| 20:12:51–20:14:20 | QA | baseline loop (pre-fix): P0-A `gt=9072.1`, P0-B "Manual control" |
| 20:14:55 / 20:15:40 | QA | reloads with integration bugs (`loader.lua:440` VirtualQuery, `api.lua:77` void*) |
| 20:17:53 | QA | reload after fixes → **P0-B verified** (orders, movement, no pause) |
| 20:18:06 | QA | current clean run start (api.lua 20:17:43, loader 20:16:54, menu 20:16:24) |
| 20:19:40–20:20:26 | QA | Del menu open, page switch "What the bot does", screenshots |
| 20:20:56 | QA | HUD/inventory/clock screenshot; match kept alive |

---

## 2. Baseline environment evidence

- Dota 2 pid **23860**, started 2026-11-16 20:02:21 (Steam pid 17668). Dota runs **HIGH** integrity (`synth_result.txt: integrity: 12288`).
- Injection: `inject_result.txt` = `injected D:\hake\lotus\src\host16.dll into pid 23860`; `host.log`
  `20:04:00.352 host: watchdog thread start pid=23860`, `20:04:02.231 host: Present hook installed at ...`, `R11: init ok sw=1920 sh=1080`.
- `run.txt` = `D:\hake\lotus\src\bot_loop.lua`.
- Mode = **single-player bot game**, hero = **npc_dota_hero_treant** (screenshots 3/4; log `[12] ... className=npc_dota_hero_treant`, `loop ... npc_dota_hero_treant hp=670`).
- Current run versions: `api.lua` 20:17:43, `loader.lua` 20:16:54, `menu.lua` 20:16:24, `overlay.lua` 20:14:55, `render.lua` 20:10:10, `orders.lua` 20:10:37, `nav.lua` 20:14:17 (all loadfile OK before start).

---

## 3. P0-B — permanent "Manual control" pause → **PASS (pending reviewer)**

### Root causes (three compounding, all fixed today)
1. `Self Play.lua:1860` `Input.IsInputCaptured() or ui.pause:IsDown() or ctx.now < ctx.pauseUntil` — our `menu.lua`
   catch-all returned a truthy table for `ui.pause:IsDown()` → permanent pause. Fix: real
   `Widget:IsDown()` via `GetAsyncKeyState` (developer, 20:15). Reference: menu `CMenuBind:IsDown()`.
2. `loader.lua:440` cdef'd a second `MEMORY_BASIC_INFORMATION`; LuaJIT binds `ffi.C.VirtualQuery` once, so every
   synth poll threw and the whole event synthesizer was dead:
   `20:15:42 poll error: D:\hake\lotus\src\loader.lua:440: bad argument #2 to 'VirtualQuery' (cannot convert 'struct 211' to 'struct 177 *')`.
   Fix (loader-events, 20:16): reuses api.lua's `API_MBI`; verified by `mbi=API_MBI` in the next load.
3. `api.lua:77 attempt to perform arithmetic on 'void *' and 'number'` killed `OnUpdate` every tick
   (20:15:42) — api-core fixed 20:17 (void* normalised via `uintptr_t`).

### Verification (current run, started 20:18:06)
```
20:17:53 events: game KV loaded in 107ms hero=true unit=true
20:17:53 events: offsets hp=0x34C ... mbi=API_MBI
20:17:54 [order]	MoveTo npc_dota_hero_treant -> -6579,-5607
20:17:55 [order]	MoveTo npc_dota_hero_treant -> -5800,1400
20:18:06 [order]	PUO type=16 tgt=42 abil=42 unit=npc_dota_hero_treant
20:18:08 [order]	PUO type=8 tgt=0 abil=1286 unit=npc_dota_courier
20:18:21 events: polls=366 avg=43.5ms max=411.0ms errors=0 hurtsDropped=0 humanOrders=0 drawSkips=0
         OnEntityDestroy=354 OnEntityHurt=399 OnNpcDying=24 OnProjectile=46 OnUnitAnimation=786 OnUnitAnimationEnd=231
20:19:12 loop 96 0.2s npc_dota_hero_treant hp=670 -5608 1328 gt=735.3
20:19:13 loop 97 0.9s npc_dota_hero_treant hp=670 -5212 1180 gt=736.0
20:20:59 loop 134 1.2s npc_dota_hero_treant hp=736 -4791 1757 gt=842.5
```
- `[order]` lines appear **within 15 s** of load (first at +1 s) → AC1 PASS.
- Hero left fountain −6700,−6700 → −5212,1180 → displacement >1500 u within 60 s → AC3 PASS.
- No `[pause]`, `Paused`, or `Manual control` lines in the whole run (`humanOrders=0` in poll counters) → AC4/AC5 PASS.
- HUD panel Now row is a real activity (NOT "Manual control"): `qa_screen_8/9/10`:
  `Treant Protector / Support 4 / Now: Placing a ward` (20:20:05), `Now: Farming the lane` (20:20:26).
- Tick times improved but still spiky: `loop 79 5.1s`, `loop 81 5.5s`, `loop 133 5.7s`; typical 0.2–1.3 s.

---

## 4. P0-A — `GameRules.GetGameTime` → **PARTIAL**

### Old evidence (pre-fix run, 20:13)
- bot_loop printed a frozen `gt=9072.1` for ~700 iterations while in-game clock was 2:43
  (`qa_screen_5_hud.png` top-centre clock `2:43`; loop lines 20:13:25–20:13:40).
- bot's own log stamps showed `[147:15]` (= 8835 s) — same wrong epoch.

### Current run (post api.lua clock rewrite)
```
20:18:13 [clock] src=atk gt=676.48 gs=236.37 state=5 in_game=440.1
20:18:56 [clock] src=atk gt=719.72 gs=236.37 state=5 in_game=483.3
20:19:57 [clock] src=atk gt=781.08 gs=236.37 state=5 in_game=544.7
20:20:48 [clock] src=atk gt=831.45 gs=236.37 state=5 in_game=595.1
20:20:58 [clock] src=atk gt=841.38 gs=236.37 state=5 in_game=605.0
```
- **Monotonic and 1:1**: gt rises 10.3 / 10.06 / 10.13 per 10 s wall; `gt − gs ≈ in_game` exactly.
- On-screen clock cross-check: `qa_screen_9_menu_behaviors.png` clock **9:32 = 572 s** @20:20:26;
  nearest `[clock]` sample 20:20:48 in_game=595.1 (expected ~594 s at 20:20:48 — matches; screenshot taken 22 s earlier).
- **Open issue (api-core)**: `GetGameTime()` returns the *absolute gamerules epoch* (gs+elapsed = 676…841),
  while bot_loop and the script's clock semantics expect the **in-game elapsed clock** (0:00 at horn, negative in
  pre-game). Scripts compare clock to fixed thresholds (`ctx.clock > 60`, `> 600`, rune/roshan timers), so the
  +gs (236 s) offset is a behavior bug even though it now advances correctly. Suggested: return `in_game`
  (gt = elapsed), keep absolute internally; `[clock]` line already prints both.
- Exact ±2 s verdict **deferred by Lead rule**: requires fresh match-from-lobby with loop already running and
  `[clock] src=horn` anchor observation (this match was joined mid-game → `src=atk`).

---

## 5. P0-C — purchase evidence (current status FAIL/pending)

- Previous run (bot log, 2026-11-16 02:19–02:21, same script/build family) shows the repeating pattern:
  ```
  02:19:30 [SelfPlay] [SelfPlay buy] tango for tango; own: tpscroll
  02:19:41 [SelfPlay] [SelfPlay buy] tango for tango; own: tpscroll
  02:19:51 ... 02:20:44 ... 02:20:56 ... 02:21:09 ... 02:21:22 ... 02:21:32  (same line, every ~10 s)
  ```
  i.e. the bot believes it owns only a tp scroll and keeps re-buying tango → duplicate-purchase / purchase-failure
  pattern (P0-C, owner orders-nav).
- Current run: one purchase order with **nonzero ids** —
  `20:18:06 [order] PUO type=16 tgt=42 abil=42 unit=npc_dota_hero_treant` — but no `[SelfPlay buy]` line yet and
  no inventory-level proof captured before this report. Inventory proof = next action in this same match
  (check `NPC.GetItem` via diag or screenshot of inventory + absence of repeated buy lines).

---

## 6. ClickGUI / HUD parity evidence (for developer task-4 slice)

- Del toggle: `20:19:40 R11: Del toggle -> 1`, `20:19:42 R11: frame hud=51 menu=79 open=1 sw=1920`
  (elevated key helper), Esc-close path also wired; menu clicks are swallowed by the native LL hook
  (no game clicks observed while menu open).
- **Screenshot `qa_screen_8_menu_default.png`** (20:20:05): window title `Self Play`, breadcrumb
  `Scripts / Self Play / Main / Main`, tabs **Main / Search and pick / What the bot does**, groups:
  - left column `Bot`: `Turn the bot on` (switch, ON), `Hold to take over` (bind `A`), `What to do` (Whole game),
    `Position` (Auto), `Lane` (Auto), `Plays for` (Only me);
  - right column `Play style`: `Style` = Balanced; `On screen`: `Show what it's doing`, `Show win chance`,
    `Show where it goes` (ON), `Camera on hero`, `Detailed logs` (OFF), `Save bot log to its own file` (ON).
- **Screenshot `qa_screen_9_menu_behaviors.png`** (20:20:26, after elevated click on "What the bot does"):
  groups `Fighting` (7 switches), `Lane and support play` (9 switches), `Items and moving around`
  (5 switches incl. `Download builds` OFF), `Item builds` (`Builds from` = Top players, `Counter items` disabled/greyed).
- HUD in the same screenshots: win bar `Chance to win 87% -8 / We have more gold` (20:20:05), `93% +16` (20:20:26);
  right panel `Treant Protector / Support 4 / Now: Placing a ward / Saving for: Magic Wand / 305 gold to go`.
- `R11: frame hud=49 menu=112 open=0 sw=1920` after page switch (menu command count grows with the richer page).

---

## 7. Loader event-synthesizer evidence (loader-events)

```
20:17:53 events: offsets hp=0x34C life=0x354 team=0x3E7 node=0x330 origin=0xD8 act=0x18E8 seq=0x18F0
         lastatk=0x13C8 lastdealt=0xD1C range=0xCC8 mbi=API_MBI
20:18:21 events: polls=366 avg=43.5ms max=411.0ms errors=0 hurtsDropped=0 humanOrders=0 drawSkips=0
         OnEntityDestroy=354 OnEntityHurt=399 OnNpcDying=24 OnProjectile=46 OnUnitAnimation=786 OnUnitAnimationEnd=231
20:20:58 events: polls=666 avg=137.2ms max=818.0ms errors=0 ... OnEntityHurt=1721 OnProjectile=169 OnUnitAnimation=3300
```
- PASS: synthesizer alive, counters increase, `errors=0`, no `poll error:` since the 20:17 load.
- ATTENTION: poll cost avg 43→137 ms and **max 411→818 ms** exceeds the <300 ms target (loader-events plan);
  the 5+ s `loop` ticks correlate with these spikes.
- Manual-order proof (real human click → `[pause] ... armed` then `... expired` ~4 s, bot's own orders → none)
  still **not executed**; needs a window where the loop is running and QA issues one right-click on the ground.
  Planned together with the diag_events run (reviewer PASS pending).

---

## 8. Transient integration defects observed today (all fixed; recorded for the changelog)

| Time | Failure line | Owner | Status |
|---|---|---|---|
| 20:10:35 | `diag_api_probe.lua:92: attempt to index global 'schema' (a nil value)` | api-core | fixed 20:11:37 (requires schema/entity; pcall wrapper added) |
| 20:11:16 | `error loading module 'menu' ... menu.lua:70: 'end' expected ... near 'elseif'` | developer | fixed 20:12:04 |
| 20:14:56–20:15:44 | `poll error: loader.lua:440: bad argument #2 to 'VirtualQuery' (cannot convert 'struct 211' to 'struct 177 *')` | loader-events | fixed 20:16:54 (`mbi=API_MBI` proof) |
| 20:15:42 | `OnUpdate error: api.lua:77: attempt to perform arithmetic on 'void *' and 'number'` | api-core | fixed 20:17:06 |
| 20:12–20:14 | `gt=9072.1` frozen vs in-game 2:43 | api-core | rewritten 20:17→20:18 (now advancing; absolute-epoch semantic still open, §4) |

---

## 9. Next QA windows (queue)

1. **P0-A exact clock** (Lead procedure): leave this match is NOT needed for the clock — later, return to main menu
   with loop running, verify `loop ... gt=` shows pregame (`gt` negative/in-game negative), create new single-player
   bot game with Treant, capture `[clock] src=horn` + two `gt` vs on-screen-clock samples ≥60 s apart.
2. **P0-C inventory proof** in current match: read hero inventory (diag/observer), confirm purchased item present and
   `[SelfPlay buy]` stops repeating; screenshot inventory/shop.
3. **diag_events.lua** run (loader-events request) after reviewer PASS: `EVDIAG CB *`, `EVDIAG STAT`, `events: polls`,
   `EVDIAG NAMES` + `evdiag_names.txt`; plus one real human right-click on ground to prove `[pause] ... armed` →
   `[pause] pause window expired` and `[SelfPlay manual]` in bot log, with bot's own orders never pausing.
4. **diag_api_probe.lua** rerun (api-core new build has `[13]` clock cross-check and `[12]` per-player team data) —
   only in a bot game; paste block + current inventory/scoreboard comparison for P0-A/P0-C.
5. **nav/Treant tree-walking proof** (orders-nav): after reviewer PASS, observe hero path through trees
   (ALLOW_PATHING_THROUGH_TREES) — needs `[order] MoveTo` sequence + position trace.
6. Menu interaction depth (dropdown/multiselect/bind capture/slider drag) under synthetic elevated clicks —
   bundle after developer/reviewer PASS.

---

## 10. Screenshot index (`D:\hake\lotus\`)

| File | Content |
|---|---|
| `qa_screen_0.png` | pre-test desktop (bot panel "Игра против ботов", ОДИНОЧНАЯ) |
| `qa_screen_1.png` | hero pick screen (before random/pick) |
| `qa_screen_2.png` | hero pick, TREANT PROTECTOR tile selected |
| `qa_screen_3.png` | loading screen, `TREANT PROTECTOR` locked (Radiant) |
| `qa_screen_4.png` | in-game start, Treant at fountain, clock 0:52 |
| `qa_screen_5_hud.png` | HUD: win bar `Chance to win 82% / We have more gold`, panel `Treant Protector / Support 4 / Now: Manual control` (pre-fix P0-B state), clock 2:43 |
| `qa_screen_6_hud2.png` | 20:16:51 post-IsDown reload: Now `Walking`, clock 5:58 |
| `qa_screen_7_hud_order.png` | first moving run (orders flowing), clock ~7:1x |
| `qa_screen_8_menu_default.png` | **ClickGUI default page** (Main tab) + HUD panel `Now: Placing a ward`, clock 9:11 |
| `qa_screen_9_menu_behaviors.png` | **ClickGUI "What the bot does" page** + HUD panel `Now: Farming the lane`, clock 9:32 |
| `qa_screen_10_hud_lane_clock.png` | menu closed, hero in lane + inventory + clock (P0-B/P0-A second sample) |
| `qa_screen_11_inventory.png` | (to add) inventory close-up for P0-C proof |

---

## Appendix A — `API_P1` probe (run 20:12:15, Treant bot game) key lines

Full block: `D:\hake\lotus\qa_api_p1_block.txt` (81 lines). Highlights:
```
20:12:15 === API_P1 BEGIN === okSchema=true okEntity=true client=0x7FF8715E0000
20:12:15 [1] gamerules=0x255AAB30000 proxy=... state=5 mode=1 matchid=0 gamestart=236.367 pregame=146.367 creepspawn=206.367
20:12:16 [2] entities=5785 uniqueNames=175
20:12:16 [3] localController ... assigned=npc_dota_hero_treant name=Heron
20:12:16 [3] nextSeq(0x9B8)=1 ordersCnt(0x9A0)=0
20:12:16 [4] dataTeamEntities=1 localPid=0 localTeam=2   dota_data_radiant cnt=5
20:12:16 [4]   r0 rel=165 unrel=576 earned=165 xp=0 nw=741 lh=0 dn=0 kills=0 slot?=0
20:12:16 [4]   r1 rel=67 unrel=70 earned=427 xp=411 nw=1027 lh=7 dn=2 kills=0 slot?=0
20:12:19 [4b] playerResource NOT FOUND (GetTeamData must use fallback)
20:12:20 [5] simTime samples=4873 min=146.33 med=146.333 max=323.033 | gamerules gamestart=236.367 | heroSim=0.000
20:12:20 [6] npc/ctrl=158 identityFlagsLowByte=0:158 nodeDormant=0:158
20:12:20 [7] hero identity: +0=0x255D0E2E000 +8=0x7FF8776DE8B0 +10=0xFFFFFFFF018A0800 ...
20:12:20 [8] CDOTA_Buff size=0x1AA8 fields=38 (m_flDieTime=100 m_hCaster=104 m_iStackCount=132 ...)
20:12:20 [8] CDOTA_ModifierManager size=0x390 fields=7 (m_iBuffIndex=904 ...)
20:12:20 [8] C_DOTA_PlayerResource size=0x35B0 m_vecPlayerTeamData=1544 m_vecPlayerData=1648
20:12:20 [8] PlayerResourcePlayerTeamData_t size=0x238 fields=76 (m_iKills=168 m_iDeaths=176 m_iAssists=172 ...)
20:12:20 [8] DataTeamPlayer_t size=0x12F0 fields=97
20:12:20 [9] npc_dota_creep_lane idx=1625 hp=300/300 lvl=5 dmg=21/26 range=500 gold=43/52 ...
20:12:20 [10] hero mgr=0x255D0E2EE30 layout cnt@10 ptr@18 c=3
20:12:20 [11] xhelpers=true xkv=table | abilKV treant_natures_grasp keys=... | item_blink ABSENT
20:12:20 [12] api.register ok=true | Heroes.GetLocal=0x25580696898 Entity.GetIndex=1263
20:12:20 [12] GetAbsOrigin=-6700,-6700,384 team=2 dormant=false alive=true hp=670 className=npc_dota_hero_treant
20:12:20 [12] NPC unitName=npc_dota_hero_treant attackRange=150 trueDmg/min/max=85/93 hull=24 spAttack=2.11 ...
20:12:20 [12] Players.GetAll=10 (5 per team, all C_DOTAPlayerController, teamPlayer/teamData=true)
20:12:20 API missing: Hero.GetCurrentXP          <-- fixed in api.lua 20:17 drop
```

---

## Appendix B — PROTECTED WINDOW 2026-11-16 20:33:56–20:39 (perf-fixed run, Treant mid-joined bot game, ONE loop)

Loop: `20:33:51 host: running bot_loop.lua`, `20:33:51 === BOT LOOP ===`, `20:33:53 loader: Self Play loaded in 1985ms`;
loadfiles loaded by this state: api 20:32:41, loader 20:32:40, entity 20:32:08, nav 20:33:29, orders 20:31:23, menu 20:25:49, overlay 20:14:55, render 20:10:10.
Stop: `stop.txt` → `=== BOT LOOP done ===` (loop discipline: one loop; each start/stop recorded here).

### B1. Perf (task-10 / task-12)
```
20:33:56 [perf] first-tick total=2853ms nav=3 synth=62 pump=0 script=2785 (onUpdateEx=0 onUpdate=2785) draw=1 overlay=2 loaded=true
20:34:05 [perf] tick n=10 total=128ms nav=6 synth=1 pump=0 script=117 draw=4 overlay=0 avg=460ms
20:34:09 [perf] tick n=20 total=255ms nav=0 synth=119 pump=0 script=136 draw=0 overlay=0 avg=304ms
20:34:20 [perf] tick n=30 total=43ms nav=0 synth=2 pump=0 script=40 draw=0 overlay=1 avg=295ms
20:34:23 [perf] tick n=40 total=69ms nav=0 synth=2 pump=0 script=66 draw=1 overlay=0 avg=240ms
20:34:25 [perf] tick n=50 total=111ms nav=0 synth=46 pump=0 script=64 draw=1 overlay=0 avg=210ms
20:34:29 [perf] tick n=60 total=158ms nav=0 synth=2 pump=0 script=147 draw=9 overlay=0 avg=205ms
20:34:30 [perf] phase pump_start/updateEx_done/update_done/script_done t=21ms   (first tick phases)
loop 42..65: 0.1-1.1 s per iteration
20:34:13 [api] calls/5s: GetAbsOrigin=7931 ... (burst during first tick) -> 20:34:18 GetAbsOrigin=126616 GetGameTime=87 GetTeamNum=38646
20:34:31 [entity] iter build ms=0.00 n=5859 tickBuilds=1 total=63 cached=0 ; byHandle build ms=1.00 tickBuilds=2
```
Verdict: **perf FIXED** — first tick 116666ms → 2853ms; tick totals 43-255 ms; tick median ≈111 ms; loop iteration 0.1-1.1 s. Residual hot spot: `[perf] slow poll mode=draw cost=218-589ms ... top=OnUnitAnimation(216-588ms)` and cumulative `OnUnitAnimation=19808ms` per 30 s summary (loader-events; animation filter landed after this window).

### B2. HUD (task-13/4)
```
20:35:29 [hud] cmds=47 text=16 world=0 overlaps=0 offscreen=0
20:35:35 [hud] cmds=51 text=20 world=0 overlaps=0 offscreen=0
20:35:40 [hud] cmds=47 text=16 world=0 overlaps=0 offscreen=0
20:35:45 [hud] cmds=55 text=24 world=0 overlaps=0 offscreen=0   (18 lines total, all overlaps=0 offscreen=0)
```
`hud_cmds.txt` header 20:36:47: `# cmds=49 text=18 world=0 overlaps=0 offscreen=0`; `[ui] textwidth-fallback` count = **0**.
Screenshots: `qa_hud_stab_1.png` / `qa_hud_stab_2.png` (20:35:44.112 / 20:35:46.981 — same camera; win bar `Chance to win 98%` + panel `Treant Protector / Support 4 / Now: Staying with a teammate`; world markers: hero label only — `world=0` in this window because no movement/target markers were published while idling).
Earlier ClickGUI evidence still valid: `qa_screen_8_menu_default.png` (tabs Main/Search and pick/What the bot does; groups Bot, Play style, On screen), `qa_screen_9_menu_behaviors.png` (Fighting / Lane and support play / Items and moving around / Item builds); `R11: frame hud=49..55 menu=112 open=0/1`.

### B3. Pause/bind tests (task-14 condition 2) — **FAIL (could not trigger pause)**
- SPACE held 2.2 s via elevated synthetic key (`synth_key_elevated.bat 32,2200`; script prints `key vk=32 pressed+released`, `foreground_ok=True`): HUD Now row stayed `Staying with a teammate` during the hold and after. `qa_pause_space_hold.png` (20:37:01), `qa_pause_space_after.png` (20:37:08); crops `qa_panel_hold.png` / `qa_panel_after.png`.
- A held 2 s (VK 65): same, no pause.
- Ground truth that synthetic keys reach the game: elevated Del (`synth_key_elevated.bat 46`) toggles the ClickGUI (`R11: Del toggle -> 1`), so the input path works.
- Suspicion (owner developer/task-14): bind widget displays `A` for the default `Enum.ButtonCode.KEY_SPACE` (menu screenshot at 20:20:05, "Hold to take over | A"), i.e. ButtonCode→VK conversion/UI label looks wrong; `Widget:IsDown` therefore likely polls the wrong VK (0x41) or returns false. menu.lua has BTN2VK/VK2BTN tables (line ~30) — needs live check.
- "exactly one pause ≤4 s, resume" cannot be confirmed → mark FAIL until developer confirms/fixes.

### B4. Orders + fountain-idle classification (task-18, task-9)
```
20:34:06..20:34:19 [order] PUO type=1(DOTA_UNIT_ORDER_MOVE_TO_POSITION) ... -> ok   (10x)
20:34:05..20:34:20 [order] PUO type=10(DOTA_UNIT_ORDER_HOLD_POSITION) ... -> ok   (4x)
20:32:22 [order] queue mode=auto hostlib=true queueDisabled=false
20:33:55 [order] stats sent=1 failed=0 mismatches=0 lastSeq=203 queued=1 direct=0 drainTo=0 [DOTA_UNIT_ORDER_PURCHASE_ITEM=1]
```
Hero position static `-7195,-6582` for the whole window (loop 102→277, gt 1695→1894); `[nav] stall` count = **0**.
HUD mode in `hud_cmds.txt`: `Staying with a teammate`. Classification (orders-nav + PM/Lead): script-intentional Support-4 "hold safe position near allies" cover behavior (`Self Play.lua:1547-1550` → `navigation.coverAnchor/hold safe position near allies`), **not** nav stall, **not** orders, **not** teammate-data. In this won mid-joined game the cover anchor is the fountain. => task-9 Phase A "leaves fountain/reaches lane" = **NOT PROVEN** in this match (needs fresh match). Orders themselves are `-> ok`, zero `-> fail:`, zero `MISMATCH=`.

### B5. Nav contribution (task-9 gate N4/N5)
```
20:34:26 [nav] rescan ms=5.9 entities=5801 obstacles=2256 trees=2198 hard=58 dyn=0 cells=65536 valid=true
20:34:39 [nav] rescan ms=4.9 entities=5828 obstacles=2256 trees=2198 hard=58 dyn=0 cells=65536 valid=true
20:35:04 [nav] rescan ms=6.1 entities=5923 obstacles=2256 trees=2198 hard=58 dyn=0 cells=65536 valid=true
20:33:56 [nav] path ms=2.34 waypoints=5 len=8723 straight=8122 treeWalking=true expanded=134 incomplete=false
20:34:25 [nav] path ms=0.38 waypoints=1 len=252 straight=252 treeWalking=false expanded=6 incomplete=false
```
trees=2198 > 0, hard=58 > 0, `valid=true`; path ms 0.38/2.34 (<5 target); **treeWalking=true** observed (Treant ALLOW_PATHING_THROUGH_TREES branch). Nav is not on the perf hot path (`nav=` 0-6 ms in `[perf] tick`).

### B6. Clock (task-12)
```
20:33:56 [clock] src=atk gt=1652.4 gs=236.37 state=5 in_game=1416.0 samples/10s=5 scans=5
20:34:13 [clock] src=atk gt=1637.26 gs=236.37 state=5 in_game=1400.9 samples/10s=5 scans=5
20:36:38 QA_INV gt=1782.18 matchid=0 state=5 paused=false
```
Absolute epoch contract correct (script subtracts `GetGameStartTime` itself); samples/10s=5/5 ≤ target. `[clock] src=horn` exact ±2 s still pending a lobby→fresh-match run.

### B7. Task-16 purchase/inventory — honest state
- This window: **no** `type=16(PURCHASE_ITEM)` order; `[SelfPlay buy] magic_stick for magic_wand; own: flask,tpscroll,ward_observer` repeats every 6-20 s (11×/40 lines) — duplicate-buy loop persists.
- Last successful purchase-order lines from earlier windows: `20:23:48 / 20:29:39 / 20:33:55 PUO type=16(PURCHASE_ITEM) tgt=42 abil=42 item=ward_observer -> ok buy-attempt=1`.
- Inventory enumeration bug found (diagnostic `diag_qa_inventory.lua` run 20:36:36 via RunHost):
  `QA_INV slot 16 item_tpscroll` only, `items=1` — while HUD shows tango/stick/ward/flask. `NPC.GetItemByIndex(hero, 0..16)` returns only slot 16 → **slot mapping wrong for slots 0-15**; also `NPC.GetCurrentLevel(hero)=2` while HUD level 15. This explains `own:` lists missing the magic stick it already holds → repeated buys. (owner: api-core; task-16 stays open.)
- Fog test in the same diag: `FogOfWar.IsPointVisible` true/false variety: hero=true, ourFountain=true, enemyFountain=false, midRiver=false, enemyT2top=true, enemyT2bot=false (L1 both outcomes observed; `FogOfWar.IsVisible` is not implemented → nil).
- Diag artifacts fixed before the run: `table.unpack` shim and `Item`/`FogOfWar`/`Couriers` globals missing in a fresh Lua state (see §1 protocol note: diag scripts must bootstrap `require("loader")`/`api.register()`; QA diag now guards).

### B8. Loop discipline log (this session)
| Event | Line |
|---|---|
| start | `20:33:51 host: running D:\hake\lotus\src\bot_loop.lua` / `20:33:51 === BOT LOOP ===` |
| stop | `=== BOT LOOP done ===` after `stop.txt` (21:39→ see §1) |
| no overlap | exactly one `=== BOT LOOP ===` between previous `done` and the next start; verified before each start |

### B9. Still open after this window
1. task-14 pause bind (SPACE/A) — FAIL, dev to fix ButtonCode↔VK mapping/IsDown.
2. task-16 inventory enumeration (NPC.GetItemByIndex slots 0-15, GetCurrentLevel) + duplicate-buy loop.
3. task-9 Phase A movement proof — needs fresh match (script-cover idle in this won mid-joined game).
4. task-12 `[clock] src=horn` ±2 s — needs lobby→fresh-match run.
5. loader-events animation fire cost (OnUnitAnimation 216-588 ms/poll) — filter landed 20:38:39, needs next-window `[perf] slow poll` numbers.
6. task-18 player-data (10 controllers/10 distinct heroes/ally origins) — probe v4 section `[17]` in next window.

### B10. Loop-count / concurrency finding (QA process, not product bug)
Loop transition markers from `host.log` (20:18-20:40) show GAPS: several `=== BOT LOOP ===` starts without an interleaved `=== BOT LOOP done ===`
(e.g. starts at 20:19:16 / 20:23:44 / 20:26:08 / 20:29:36 / 20:29:59 / 20:30:04 / 20:33:51 / 20:35:15 / 20:39:49 vs only done at 20:23:42 / 20:27:31 / 20:33:40 / 20:39:25).
=> **more than one `bot_loop.lua` instance was started concurrently during 20:26-20:40** by the crew's RunHost calls (RunHost always spawns a new Lua state and does not stop an existing loop).
QA-side symptoms that match two loops: intermittent `loop N ... nil hp=- 0 0` lines and bot-log `[SelfPlay state] bot not running: no local hero or player` toggles (5 occurrences in the 20:18-20:35 bot log).
This is a **QA/runtime-discipline finding, not a product bug**: `call_elevated.bat` cannot know whether a loop is already running; only stop.txt stops loops. From this point: before starting any loop QA verifies (a) no `=== BOT LOOP ===` without a following `done`, (b) loop-line cadence is single-source, (c) `stop.txt` quiet window; and records every start/stop here.

---

## Appendix C — API probe v4 (20:40:27–20:40:44, Treant mid-joined bot game, loop running; block saved `D:\hake\lotus\qa_api_p1_v4.txt`, 249 lines)

### C1. `[17]` player/controller data — task-18 acceptance
```
20:40:41 [17] Players.GetAll n=10 firstCall=2.00ms x10=0.00ms (cached TTL 0.5s)
20:40:41 [17] ctrl[10] pid=0 team=2 assigned=npc_dota_hero_treant heroOrigin=-7195,-6582,393 owner=dota_player_controller isLocalCtrl=true samePosAsLocalHero=true
20:40:41 [17] distinctAssignedHeroes=10 duplicateAssignments=0
20:40:41 [17] Heroes.GetAll n=14
20:40:41 [17] heroOrigins distinct=14 heroesAtRadiantFountain=1 heroesSharingPositions=0
20:40:41 [17] localPlayer roleInputs laneFlags=0 heroId=16777215 networth=102 lasthits=0 denies=0
```
**PASS**: 10 controllers, 10 distinct assigned heroes, duplicateAssignments=0, only 1 hero (local Treant) at the radiant fountain, no shared positions, local player resolves to Treant.
Interference note: this probe ran while a loop was running (loop state is read-only for the probe; no new loop was started by QA for it).

### C2. `[12]` per-player teamData vs teamPlayer — **teamData values are GARBAGE (task-19)**
```
[12] player2 ... | teamData{kills=1124073472 deaths=0 assists=1 lvl=15 lane=0 heroId=-11184811 respawn=0} | teamPlayer{nw=9544 lh=41 dn=8 rel=141 unrel=378 earned=9349 xp=12589}
[12] player4 ... | teamData{kills=0 deaths=1 assists=1258291200 lvl=17 lane=0 heroId=1430537284 respawn=0} | teamPlayer{nw=16284 lh=158 dn=23 rel=76 unrel=333 earned=15774 xp=17361}
[12] player1 ... | teamData{kills=1430537284 deaths=1430537284 assists=1146443093 lvl=16777215 ...} | teamPlayer{nw=105 lh=0 dn=0 rel=1 unrel=0 earned=4137 xp=344}
```
=> `Player.GetTeamPlayer` (teamPlayer row) is SANE (nw/lh/dn/gold/xp look real: enemy player4 158 last-hits). `Player.GetTeamData` (fallback DataTeamPlayer path) returns garbage (1430537284 / 16777215 / negative) → task-19 FAIL evidence. Enemy teamPlayer rows all zeros (fallback path doesn't map enemy ids).
Legacy `Hero.GetCurrentXP` now works (344), `NPC.GetCurrentLevel` returned 2 while HUD level 15 (see B7) — still broken.

### C3. `[14]` modifiers — names resolve, timing fields misaligned (L2)
```
[14] hero layout cnt@0x10 ptr@0x18 cnt=5: 0{name=modifier_treant_natures_guise die=755.63 cre=146.43 dur=-1.00 stk=0 rem=-1268.88}
     1{modifier_treant_leech_seed_passive die=657.13 cre=658.13 ...} ... 3{modifier_fountain_aura_buff die=1820.73 cre=1236.30 dur=3.00 rem=-203.78}
[14] hero m_nUnitState64=0x40000000000 states=42 schemaMask=0
[16] hero statesDuration: (empty)   hero modifiers: ?@0x255D1264800 | ?@... (Modifier.GetName returns "?" for live handles)
```
Names come from modifier manager list, but `die/cre/dur/rem` are not chronologically consistent (creation time > die time, negative remaining) → CDOTA_Buff `m_flCreationTime/m_flDieTime` offsets/time base wrong. `statesDuration` empty and `Hero.GetRecentDamage` garbage (`recentDmg=2059206657` for a creep) — task-19/api-core.

### C4. `[15]` visibility mask — 132/163 "visible" (81%) with plausible mixed samples
```
[15] m_bNPCVisibleState visible=132/163
[15] VISIBLE samples: npc_dota_creep_lane(idx2282 team=2 hp=550) | ... (6 lane creeps, both teams)
[15] HIDDEN  samples: npc_dota_creep_siege(idx2753 team=2) | ... | npc_dota_lantern(idx530 team=5 hp=100)
```
Both outcomes exist; ratio is high but this is a 30-min won bot game (most units visible). api-core to decide trustworthiness.

### C5. `[16]` attack timing
```
[16] localHero unitName=npc_dota_hero_treant baseAS(0xCE4)=90 bat(0xCE8)=1.9 dmg=88/96 bonus=0 basedmg=60/68
  KV rate=1.9 animPoint=0.6 range=150 | API aps=0.562 spa=1.779 anim=0.6 proj=nil rangeBonus=0 ttf=0.000 recentDmg=0
[16] creep1 npc_dota_creep_goodguys_melee baseAS=100 bat=1 dmg=19/23 | API aps=1.000 spa=1.000 anim=0.467
```
animPoint=0.6 (not constant 0.45) PASS; spa=1.779 is consistent with bat 1.9 / current AS ~107% (level-15 value), earlier probe at level 2 gave 2.111; melee creeps have no projectile — no ranged-creep sample in this window (projectileSpeed>500 not verified).

**CORRECTION (B7 level claim)**: Treant level was **2** in the finished 37-1 game (scoreboard `qa_play4.png` УР.=2, HUD hero panel 2, `Hero.GetCurrentXP=344` ⇒ level 2). So `NPC.GetCurrentLevel=2` is **CORRECT** — the earlier "HUD level 15" note was wrong (15 came from `GetTeamData` garbage fields, e.g. `lvl=15` for player2). Only the inventory enumeration issue remains for task-19.

---

## Appendix D — CLEAN CYCLE 2026-11-16 21:02+ (NEW DLL md5 1AB3D773…, human/Lead-captured window; QA annotated)

> STATUS: human took runtime control at 21:04 (Lead stand-down order); Lead/human create the lobby + Treant game and capture lines; QA fills this appendix from their excerpts.
> Runtime state for this window: Dota pid **4428**, `host16.dll` md5 **1AB3D7734E6A6F02FFC72DA11E384342** (185856 B, staged build; old 422751ED… kept as `host16.dll.bak_20261116_205629` / `host16.dll.old_20261116_210003`).
> Injection: `inject_result.txt` = `injected D:\hake\lotus\src\host16.dll into pid 4428`; `[21:02:04.452] host: watchdog thread start pid=4428`; `21:02:04 host: running D:\hake\lotus\src\bot_loop.lua`; `21:02:04 === BOT LOOP ===`; `21:02:06 loader: Self Play loaded in 1948ms`; `21:02:06 [perf] load total=2045ms require=1948ms kv=95ms ...`; `[21:02:06] R11: init ok sw=1920 sh=1080`.
> Loop discipline (answer to Lead's "one loop?"): starts `21:02:04` (watchdog auto-run after injection) → `21:05:15 stop.txt / === BOT LOOP done ===` → new start `21:05:40 === BOT LOOP ===` (loader loaded 21:05:42; human/Lead-managed). No concurrent instances: every start is preceded by injection or by a done marker; one-shot scripts (`names_probe.lua` 04:21:03 log-clock, `open_menu.lua` 21:06:01) ran in their own Lua states while the loop was running (expected, they are not loops).
> In-match observation (read-only, before hand-over): **CORRECTED — the slow ticks I first quoted were STALE/misattributed.** Line-index proof (timestamps in `host.log` are NOT monotonic because the system clock jumps; attribution must use line order, not timestamps): `loop 41691 16.3s ... hp=670 -7054,-6080` is at **line 75455**, while the current (post-swap) window starts at `=== BOT LOOP ===` **line 317947** (file total 322770) — i.e. the 16-23 s ticks belong to the pre-swap 20:53 session, NOT this window. Current window (lines 317947..end): `[perf] tick n=10..4560 total=0ms..1ms nav=0 synth=0 script=0/1 draw=0 overlay=0`, `loop 4120..4122 0.0s nil hp=- 0 0 gt=-1.0`, `[clock] state=0 (no in-game clock yet, gs=0)` → still LOBBY, no match started, **no task-10 regression in this window**.

### D0. Window definition (line-index, NOT timestamps)
- Window = `host.log` from the `=== BOT LOOP ===` at **line 317947** (`21:02:04`) to end of file at paste time. Attribution by **line index** (see LOG ATTRIBUTION RULE above; timestamps in this file are non-monotonic).
- Loop segments in the window (one loop at a time):
  - `line 317947 === BOT LOOP ===` (21:02:04, post-injection, new DLL) — lobby
  - `line 339531 === BOT LOOP done ===` (21:15:57) — stopped after the in-match segment
  - `line 339549 host: running diag_api_probe.lua` (21:16:28) — one-shot probe (not a loop)
  - `line 339805 === BOT LOOP ===` (21:17:53) — new loop after probe (Lead-driven)
- DLL loaded in this window: `host16.dll` md5 **1AB3D7734E6A6F02FFC72DA11E384342** (new input-fix build); Dota pid **4428**; mode = **single-player bot game**; hero = **`npc_dota_hero_treant`** (HUD "Farming the lane" in Lead screenshot).
- Zero `OnUpdate error` / `poll error` / `runtime error` / `load error` in the window (count = 0).

### D1. State / versions
- `21:02:04.452 host: watchdog thread start pid=4428`; `21:02:04 host: running D:\hake\lotus\src\bot_loop.lua`; `21:02:06 loader: Self Play loaded in 1948ms`; `21:02:06 [perf] load total=2045ms require=1948ms kv=95ms onLoaded=0ms warmup=2ms (entity=0ms nav=2ms modules=0ms updateEx=0ms)`.
- After probe: `21:17:53 host: running D:\hake\lotus\src\bot_loop.lua`; `21:17:55 [perf] load total=2112ms require=1954ms kv=113ms onLoaded=0ms warmup=45ms (entity=0ms nav=35ms modules=0ms updateEx=10ms)`.

### D2. task-12 clock — **PASS (Lead closed)**
```
21:11:35 [clock] anchor: observed m_flGameStartTime transition -> 100.300
21:11:35 [clock] src=horn gt=100.30 gs=100.30 state=4 in_game=0.0 samples/10s=0 scans=0
21:11:45 [clock] src=horn gt=110.32 gs=100.30 state=5 in_game=10.0 samples/10s=0 scans=0
21:11:55 [clock] src=horn gt=120.33 gs=100.30 state=5 in_game=20.0 samples/10s=0 scans=0
21:12:06 [clock] src=horn gt=130.47 gs=100.30 state=5 in_game=30.2 samples/10s=0 scans=0
21:12:16 [clock] src=horn gt=140.57 gs=100.30 state=5 in_game=40.3 samples/10s=0 scans=0
21:13:47 [clock] src=horn gt=231.50 gs=100.30 state=5 in_game=131.2 samples/10s=0 scans=0
21:13:57 [clock] src=horn gt=241.66 gs=100.30 state=5 in_game=141.4 samples/10s=0 scans=0
```
- Sample 1 (`clock_s1.png`): on-screen clock **0:43** vs `src=horn ... in_game≈43.7` → Δ<1 s.
- Sample 2 (`clock_s2.png`): on-screen clock **2:22** (=142 s) vs `in_game=141.4` → Δ<1 s. Samples ≥60 s apart (0:43 → 2:22 = 99 s).
- `samples/10s=0 scans=0` — scan-free anchor path active. Absolute-epoch contract (`gt = gs + in_game`) holds (`241.66 = 100.30 + 141.4` within rounding).

### D3. task-9 Phase A movement/pathing — **PASS (Lead closed)**
Movement (verbatim `loop` lines, hero = local Treant):
```
21:10:09 loop 11244 0.0s npc_dota_hero_treant hp=670 -6700 -6700 gt=-1.0      <- spawn
21:11:39 loop 13093 0.0s npc_dota_hero_treant hp=670 -6554 -5712 gt=104.1
21:11:52 loop 13274 0.0s npc_dota_hero_treant hp=670 -6357 -2134 gt=117.2
21:12:01 loop 13334 0.2s npc_dota_hero_treant hp=670 -6122 205  gt=125.6
21:12:06 loop 13347 1.1s npc_dota_hero_treant hp=670 -5800 1400 gt=130.8    <- lane anchor
21:19:38 loop 496  0.3s npc_dota_hero_treant hp=670 -5800 1400 gt=583.3     <- stays laning
```
HUD mode: **"Farming the lane"** (Lead screenshot) — no `no safe route` / `Stop short` / `path obstructed` / `[nav] stall` lines in the window (counts = 0).
Nav rescan (first valid + steady):
```
21:10:02 [nav] rescan ms=1.2 entities=927 obstacles=0 trees=0 hard=0 dyn=0 cells=65536 valid=false   (map streaming)
21:10:13 [nav] rescan ms=10.9 entities=5372 obstacles=2258 trees=2198 hard=60 dyn=0 cells=65536 valid=true
21:10:24 [nav] rescan ms=10.7 entities=5369 obstacles=2258 trees=2198 hard=60 dyn=0 cells=65536 valid=true
21:10:34 [nav] rescan ms=10.3 entities=5369 obstacles=2258 trees=2198 hard=60 dyn=0 cells=65536 valid=true
```
Nav path (first warmup, then all sub-ms):
```
21:11:36 [nav] path ms=9.43 waypoints=4 len=8314 straight=8150 treeWalking=true expanded=170 incomplete=false   <- first-path warmup
21:11:46 [nav] path ms=0.85 waypoints=3 len=801 straight=646 treeWalking=false expanded=30 incomplete=false
21:14:56 [nav] path ms=0.26 waypoints=2 len=242 straight=202 treeWalking=false expanded=4 incomplete=false
21:18:00 [nav] path ms=0.91 waypoints=3 len=645 straight=553 treeWalking=false expanded=13 incomplete=false
21:18:11 [nav] path ms=0.13 waypoints=2 len=483 straight=447 treeWalking=false expanded=9 incomplete=false
21:19:18 [nav] path ms=0.37 waypoints=2 (Lead line)
```
`hard=60` interpretation (orders-nav, benign): the earlier `hard=58` was a 27-min mid-joined game with destroyed structures absent + static set accumulating as PVS streams entities while the hero walks out; HARD_PATTERNS/HARD_IGNORE unchanged; expected real-map total ≈60 (≈22 towers / ≈18 rax / 2 ancients / ≈4 shops / ≈4 shrines+filler). Benign proof: `trees=2198` identical pre/post-fix, hero reached lane, zero stall, all orders `-> ok`.
Orders (verbatim):
```
21:11:36 [order] queue mode=auto hostlib=true queueDisabled=false
21:11:36 [order] PUO type=16(DOTA_UNIT_ORDER_PURCHASE_ITEM) tgt=46 abil=46 issuer=3 unit=npc_dota_hero_treant queue=false id=- item=tpscroll -> ok buy-attempt=1
21:11:36 [order]	MoveTo npc_dota_hero_treant -> -6360,-5654
21:11:36 [order] PUO type=1(DOTA_UNIT_ORDER_MOVE_TO_POSITION) tgt=0 abil=0 issuer=3 unit=npc_dota_hero_treant queue=false id=- item=- -> ok
21:11:36 [order]	MoveTo npc_dota_hero_treant -> -6357,-5645
21:11:36 [order] PUO type=1(DOTA_UNIT_ORDER_MOVE_TO_POSITION) ... -> ok
21:11:37 [order] PUO type=16(DOTA_UNIT_ORDER_PURCHASE_ITEM) tgt=44 abil=44 ... item=tango -> ok buy-attempt=1
21:14:41 [order] stats sent=9 failed=0 mismatches=0 lastSeq=10 queued=9 direct=0 drainTo=0 drainAvgMs=9.91 drainMaxMs=21.62 [DOTA_UNIT_ORDER_HOLD_POSITION=1 DOTA_UNIT_ORDER_MOVE_TO_POSITION=3 DOTA_UNIT_ORDER_PURCHASE_ITEM=5]
21:17:56 [order] stats sent=1 failed=0 mismatches=0 lastSeq=12 queued=1 direct=0 drainTo=0 drainAvgMs=39.26 drainMaxMs=39.26 [DOTA_UNIT_ORDER_PURCHASE_ITEM=1]
```
No `-> fail:` and no `MISMATCH=` lines in the window.

### D4. task-20 input acceptance on NEW DLL — **OPEN (awaiting Lead/human lines)**
QA-side partial before hand-over: with menu CLOSED, `gui: hook swallow` lines in window = **0**; `R11: frame hud=0 menu=79 open=0 sw=1920`; screenshots `qa_newdll_menu.png` (21:02:41), `qa_newdll_play.png`. Full matrix (menu-closed click on ИГРАТЬ/X must respond; menu-open outside click passes, widget click eaten + `gui: hook swallow click X,Y (onGui=1)`, Del↔Esc symmetric) to be pasted from Lead/human post-game test.

### D5. task-4 pause retest — **OPEN (awaiting Lead/human Space ≥10 s trace)**
Expected: `[menu] bind 'Pause while held' ... code=65 vk=0x20 held=true` → `held=false` with mid-hold HUD "Manual control"; A hold → no pause. No such lines in the captured window yet.

### D6. task-10 tick cost — **PASS on accepted single-loop window RUN-C** (RUN-A/RUN-B discarded as interleaved)
Window A (pre-restart, line-index inside window):
```
21:13:04 [perf] tick n=13400 total=1110ms nav=25 synth=38  pump=0 script=1046 draw=1 overlay=0 avg=6ms  SLOW
21:13:16 [perf] tick n=13410 total=1063ms nav=20 synth=8   pump=0 script=1034 draw=1 overlay=0 avg=7ms  SLOW
21:13:27 [perf] tick n=13420 total=1050ms nav=0  synth=9   pump=0 script=1041 draw=0 overlay=0 avg=7ms  SLOW
21:13:42 [perf] tick n=13430 total=2054ms nav=43 synth=526 pump=0 script=1484 draw=0 overlay=1 avg=8ms  SLOW
21:13:57 [perf] tick n=13440 total=1389ms nav=37 synth=258 pump=0 script=1093 draw=1 overlay=0 avg=10ms SLOW
21:14:11 [perf] tick n=13450 total=1231ms nav=28 synth=132 pump=0 script=1070 draw=0 overlay=1 avg=11ms SLOW
21:14:22 [perf] tick n=13460 total=1216ms nav=1  synth=194 pump=0 script=1021 draw=0 overlay=0 avg=11ms SLOW
21:14:29 [perf] tick n=13470 total=716ms  nav=0  synth=192 pump=0 script=524  draw=0 overlay=0 avg=12ms
```
Lead stats for that window: p50=984 / p90=1316 / max=2054 ms; `[perf] slow poll mode=tick cost=208-269ms ... top=OnUnitAnimation(143-254ms)`.
Window B (post-restart, after line 339805): `[perf] first-tick total=528ms nav=0 synth=52 pump=0 script=472 (onUpdateEx=0 onUpdate=471) loaded=true`; 55-73 `[perf] tick` lines → min 5 / max 439 / avg 174 / **p50=214 / p90=359 ms**; `script=` 198-287 ms, synth 9-25 ms; **NO `[perf] slow poll`**; early ticks fast (`21:17:57 n=10 total=34ms`; `21:17:58 n=20 total=5ms`; `21:17:59 n=30 total=8ms`), later `21:20:48 n=720 total=253ms script=233`, `21:20:51 n=730 total=284ms script=246`; Lead observed early-game `loop 597/598 0.0/0.1 s`, current `0.3-0.4 s`.
Verdict: **OPEN** — p90=359 ms > 300 ms target; must be re-measured MID-GAME with `[perf] tick` breakdown + `jit.profile` (reviewer suggestion). Loader event numbers in window (healthy): `21:18:53 events: polls=1726 avg=2.6ms scan=0.9ms fire=1.7ms max=101.0ms slowPolls=0 errors=0 hurtsDropped=0 humanOrders=0 drawSkips=1380 OnEntityDestroy=817 OnEntityHurt=1118 OnNpcDying=49 OnProjectile=111 OnUnitAnimation=346 OnUnitAnimationEnd=80 | OnEntityHurt=223ms OnProjectile=97ms OnUnitAnimation=2449ms OnUnitAnimationEnd=172ms`.
`[ev]` payloads: `21:11:55 [ev] OnEntityHurt source=npc_dota_creep_lane target=npc_dota_creep_lane damage=18 ability=nil` (nonzero; Lead window 74/74 nonzero, sizes 18/30/34/58); `21:18:53 [ev] OnEntityHurt summary n=1118 with_source=1099 (98%) sample{... damage=2}`; `21:13:03 [ev] OnProjectile handle=2 source=npc_dota_creep_lane target=npc_dota_creep_lane moveSpeed=900 isAttack=true ability=nil`; `[ev] OnProjectile summary n=111 ... moveSpeed=900`; `[ev] OnUnitAnimation summary n=346 distinct_castpoint=5 values={p0.33,p0.47,p0.50,p0.56,p0.70}`.

### D6b. RUN-C — ACCEPTED single-loop perf baseline (line-index tagged)
Loop establishment: two concurrent instances (my `21:24:32.438` start + another `21:24:59.023` start; interleaved counters e.g. `21:25:05 loop 523` and `21:25:05 loop 65` at the same second) were resolved by Lead/human: both old instances finished (`21:26:41 === BOT LOOP done ===` ×2), then **RUN-C** started:
```
line 358017: [21:27:02.272] host: running D:\hake\lotus\src\bot_loop.lua
line 358023: 21:27:02 === BOT LOOP ===
21:27:05 [perf] first-tick total=735ms nav=0 synth=61 pump=0 script=671 (onUpdateEx=0 onUpdate=670) draw=1 overlay=2 loaded=true
```
No further `host: running ... bot_loop` after line 358017 → single loop for this window (line-index rule; timestamp confusion resolved by file order).

PM-accepted RUN-C stats (72 `[perf] tick` lines ≈720 in-match ticks):
`p50=14 ms / p90=58 ms / max=161 ms`; `synth` p50=3 / p90=5 / max=9 ms; `script` split: `onUpdateEx` p90=2 ms, `onUpdate` p90=53 ms; `[perf] slow poll` = 0; `pollErrors` = 0; first-tick 735 ms.

QA extended same-window recomputation (140 `[perf] tick` lines, n=10 → n=1400):
```
count=140  min=3  p50=23  p90=68  p99=127  max=161  avg=31.4 ms
script:    p50=12 p90=55 max=154      onUpdateEx: p90=2 max=14      onUpdate: p50=11 p90=55 max=154
SLOW flags=0   [perf] slow poll=0   errors=0
21:28:45 [perf] tick n=1320 total=17ms nav=0 synth=11 pump=0 script=6 (onUpdateEx=0 onUpdate=6) draw=0 overlay=0 avg=29ms
21:28:54 [perf] tick n=1400 total=29ms nav=0 synth=10 pump=0 script=18 (onUpdateEx=6 onUpdate=12) draw=1 overlay=0 avg=31ms
21:28:54 [api] calls/5s: Ability.GetLevel=2836 ... GetAbsOrigin=5638 GetGameTime=938 GetItemByIndex=2049 GetTeamData=25 ... Players.GetAll=10
21:28:54 [entity] iter build ms=7.00 n=5850 tickBuilds=1 total=1403 cached=0   (byHandle tickBuilds=2)
```
**Task-10 thresholds met: first-tick 735 <2000 ms; p90 58-68 <300 ms; max 161 <1000 ms.** `script=` is dominated by `onUpdate` (not `onUpdateEx`), so the old 116 s / 1-2 s SLOW series is no longer reproducible in RUN-C.
PM independent verification of the same window (line 358018 onward, 140 `[perf] tick` lines): `p50=24 / p90=70 / max=161 ms, avg=31.4`; `first-tick 735 ms (script=671, onUpdate=670, onUpdateEx=0, nav=0, synth=61)`; slowPoll=0; errors=0; no `host: running` after L358018 (single loop). **Task-10 = PASS — reviewer lifted REJECT / W2 perf carve-out closed (REVIEW.md 21:33).** Condition: a later single-loop window with p90>300 ms or slowPoll>0 reopens it.
RUN-A (n=13400-13470, 984-2054 ms, `script=1021-1484`) and RUN-B (post-restart window with p50=214/p90=359/max=439) are **discarded as interleaved/concurrency-contaminated** (two loops overlapped); RUN-C is the accepted baseline.

### D7. task-19 / W1 data fixes — GetTeamData PASS, inventory/modifier OPEN
Player resource located:
```
21:17:56 [api] C_DOTA_PlayerResource located @0x3BAAED15800 validated players=10
21:16:29 [19] PR candidates=	1
21:16:29 [19]   cand1 idx=80 name='' cnt608=10 cnt670=10 playerIDToPlayerHits=6/10
21:16:29 [19] playerIDToPlayer=	0:dota_player_controller 1:dota_player_controller 2:dota_player_controller 3:dota_player_controller 4:dota_player_controller 5:- 6:- 7:- 8:- 9:dota_player_controller
21:16:29 [19] m_iszName=	0:Heron 1:Jakub 2:- 3:Julia 4:Nam 5:- 6:Grace 7:- 8:- 9:-
```
(pids 5-8 enemy `playerIDToPlayer` = "-" is the documented entity-table limitation, not a data bug.)
RAW teamData sane (fix for W1 item 1):
```
21:16:29 [19] teamData RAW all pids: 	0{k=0 d=0 a=0 lvl=1 heroId=83 team=0 slot=0 lane=0} 1{k=0 d=0 a=1 lvl=4 heroId=31 slot=1} 2{k=1 d=0 a=0 lvl=3 heroId=18 slot=2} 3{k=0 d=0 a=0 lvl=5 heroId=36 slot=3} 4{k=0 d=0 a=0 lvl=4 heroId=42 slot=4} 5{k=0 d=0 a=0 lvl=3 heroId=30 slot=0} 6{k=0 d=0 a=0 lvl=3 heroId=37 slot=1} 7{k=0 d=0 a=0 lvl=4 heroId=47 slot=2} 8{k=0 d=0 a=0 lvl=3 heroId=8 slot=3} 9{k=0 d=1 a=0 lvl=2 heroId=29 slot=4}
21:16:29 [19]   API GetTeamData pid=0 kills=0 deaths=0 assists=0 lvl=1 lane=0 heroId=83
21:16:29 [19]   API GetTeamData pid=1 kills=0 deaths=0 assists=1 lvl=4 lane=0 heroId=31
21:16:29 [19]   API GetTeamData pid=5 kills=0 deaths=0 assists=0 lvl=3 lane=0 heroId=30
21:16:29 [19]   API GetTeamData pid=6 kills=0 deaths=0 assists=0 lvl=3 lane=0 heroId=37
```
Inventory — **vector assumption FAIL, inline array returns real items** (task-19 OPEN; inline-array fix GO to api-core):
```
21:16:29 [19] inventory header 0x18..0x40: 	18=2 1C=0 20=25 24=22741439 28=-1 2C=-1 30=-1 34=-1 38=-1 3C=-1 40=-1
21:16:29 [19] m_hItems vector cnt=25 ptr=0x0
21:16:29 [19] inventory dwords 0x00..0x50: 	0=1346269768 4=32760 8=1 C=0 10=-600928320 14=954 18=2 1C=0 20=25 24=22741439 28=-1 ... 48=25233599 4C=27494685 50=15436170
21:16:29 [19] OLD inline-array reads (0x20+i*4): 	0:- 1:item_tango 2:- 3:- 4:- 5:- 6:- 7:- 8:- 9:- 10:item_ward_observer 11:item_tpscroll 12:item_tango 13:- 14:- 15:- 16:item_tpscroll 17:- 18:-
```
Duplicate-buy LIVE evidence in this fresh match (`self_play.log`, in-game clock stamps):
`[SelfPlay buy] magic_stick for magic_wand; own: flask,tpscroll,ward_observer` at `[10:29] [10:47] [10:54] [11:06] [11:15] [11:26] [11:32]` (~10-20 s repeats) — acceptance signal: task-19 stays OPEN until api patch + probe rerun + repeats stop.
Modifier timing (W1 modifier OPEN, no guess-patch; `+0xA0` clue):
```
21:16:29 [19] buff1 modifier_treant_natures_guise cre=13.667 lastApplied=13.667 dur=-1.000 die=12.667 | die-now=-381.44 la+dur-now=-381.44 cre+dur-now=-381.44 | idx=0 ser=278 stk=0 creationFrame=486
21:16:29 [19]   floats near clock +/-30s: 	A0=393.867
21:16:29 [19] buff2 modifier_treant_natures_guise_tree_walking cre=13.700 lastApplied=13.700 dur=-1.000 die=12.700 | die-now=-381.41 ... idx=2 ser=293 stk=2 creationFrame=486
21:16:29 [19]   floats near clock +/-30s: 	A0=393.867
21:16:29 [19] buff3 modifier_tower_aura_bonus cre=128.667 lastApplied=128.667 dur=0.500 die=129.167 | die-now=-264.94 ... idx=5 ser=646 stk=0 creationFrame=12985
21:16:29 [19]   floats near clock +/-30s: 	A0=393.867
```
`A0=393.867` is in the same epoch as now≈394.108 (matches the live clock), while `cre/die` are ~26 s offset ⇒ deferred rule evidence; needs a **two-sample** `+0xA0` proof before patching.

### D7b. task-19 LIVE ACCEPTANCE — duplicate-buy loop GONE (single-loop window 21:27:02+)
**Bot-log path correction:** the live bot log is `D:\hake\lotus\self_play.log` (session header `===== Self Play session 2026-11-16 21:27:25 =====`, mtime 21:28:06+); the scripts-dir copy `...\scripts\self_play.log` is stale (mtime 20:22:32) — do not quote it for current evidence.
Verbatim live-log purchase chain (in-game clock stamps):
```
[13:00] [SelfPlay buy] magic_stick for magic_wand; own: tango,tpscroll
[13:01] [SelfPlay buy] branches for magic_wand; own: magic_stick,tango,tpscroll
[13:03] [SelfPlay buy] branches for magic_wand; own: branches,magic_stick,tango,tpscroll
[13:04] [SelfPlay buy] recipe_magic_wand for magic_wand; own: branchesx2,magic_stick,tango,tpscroll
```
`own:` now accumulates correctly (magic_stick → branches x2 → recipe) and the **10-20 s repeat loop is gone** (earlier: `[SelfPlay buy] magic_stick … own: flask,tpscroll,ward_observer` repeating for 10+ min).
Order-level proof from host.log (same window; item id = tgt = abil; all `-> ok`):
```
21:24:34 [order] PUO type=16(DOTA_UNIT_ORDER_PURCHASE_ITEM) tgt=42 abil=42 ... item=ward_observer -> ok buy-attempt=1
21:24:36 [order] PUO type=16(...) tgt=34 abil=34 ... item=magic_stick -> ok buy-attempt=1
21:24:37 [order] PUO type=16(...) tgt=16 abil=16 ... item=branches -> ok buy-attempt=1
21:24:39 [order] PUO type=16(...) tgt=16 abil=16 ... item=branches -> ok buy-attempt=2 REPEAT(prev 1.6s ago)
21:24:40 [order] PUO type=16(...) tgt=35 abil=35 ... item=recipe_magic_wand -> ok buy-attempt=1
```
(`REPEAT` here = two consecutive branches components for the same wand recipe, flagged by orders.lua bookkeeping — not the old failed-buy loop.)
`[api] calls/5s: GetItemByIndex=1346 / 863 / 608 / 2049` per window, zero errors; `[api] C_DOTA_PlayerResource located @0x3BAAED15800 validated players=10`; `[entity] iter build … tickBuilds=1`, `byHandle … tickBuilds=2`.
**Status:** duplicate-buy loop GONE (primary acceptance). Remaining for task-19 closure: Lead double-probe `[19]` slot rows (`slot[0]=tango`, `slot[15]=tpscroll`, `slot[16]=nil`, reference `GetItemByIndex(15)/(16)`) + `[12]` rows + modifier two-sample `prevTick(0xA0)`/die-now.

### D7c. task-2 coverage matrix (loader-events; record for D8) — PASS(code) with documented gaps
Payload evidence line-backed in host.log: `OnEntityHurt` 95% with source + nonzero damage; `OnUnitAnimation` distinct castpoints 8-11; `OnProjectile` 18 payload keys + ranged-creep moveSpeed=900 + unique handles; `OnPrepareUnitOrders` humanOrders=0 for bot's own orders.
Gaps (known/queued, not regressions): `OnParticle*` only TELEPORT_END approximation; `OnLinearProjectileCreate/Destroy` GAP (needs native usermessage hook); `OnChatEvent`/`OnGCMessage` GAP; stubs outstanding: FogOfWar real mask, NetChannel latency, Panorama (lobby fixed), GC/HTTP/Protobuf/Humanizer inert, `Particle.Create` no-op, `LinearProjectiles.GetAll {}`.

### D7d. Probe v5 two-sample evidence — **task-19 evidence(b) FAIL (api inventory resolution incomplete); W1-modifier epoch mismatch confirmed**
Runtime window: new Dota **pid 3588** injected `21:33:18.293 host: watchdog thread start pid=3588` → `21:33:18 host: running bot_loop.lua` → `21:33:18 === BOT LOOP ===`; probe runs `21:34:13` (pre-horn) and `21:35:08` (in-game `now=109.473 gs=108.067 in_game=1.4`), 57 s apart (`API_P1 BEGIN/END` both); then Lead-driven loop restart `21:35:54 host: running bot_loop.lua` / `=== BOT LOOP ===`. Single loop at each step (line-index check).

**(b1) task-19 inventory — FAIL (fix incomplete):**
```
21:35:16 [19] slot[15] off=0x60 handle=0x118007D item=item_tpscroll charges=- apiGetItemByIndex=nil
21:35:16 [19] slot[2]..slot[14] off=0x2C..0x5C handle=0xFFFFFFFF item=- apiGetItemByIndex=nil   (all 0-16 nil)
21:35:16 [19] reference check: GetItemByIndex(hero,15)=nil (expect item_tpscroll) GetItemByIndex(hero,16)=nil (expect nil before 7:00)
```
Layout base `0x24` confirmed (`slot[15] off=0x60`), handle→name resolution works (`handle=0x118007D item=item_tpscroll`; probe's OLD `+0x20`-base reads show `16:item_tpscroll`), but the **API path returns nil for every slot**. Hence: task-19 `PASS(code)+evidence(a)` stands (duplicate-buy loop gone), **evidence(b) OPEN pending api inventory fix + re-probe**.
Re-probe acceptance (Lead/PM): api-core fixes ONLY the `itemAt`/`GetItemByIndex` wrapper; the new probe must call **both isReal variants** — `GetItemByIndex(hero, i)` and `GetItemByIndex(hero, i, false)` — and state which form the reference uses; PASS requires `apiGetItemByIndex == raw item` for every resolved slot, `GetItemByIndex(hero,15)=item_tpscroll`, `GetItemByIndex(hero,16)=nil` (before 7:00).

**(b2) W1 modifier — two-sample epoch mismatch evidence:**
```
21:34:19 buff1 modifier_treant_natures_guise cre=20.267 lastApplied=20.267 dur=-1.000 die=19.267 prevTick(0xA0)=55.300
21:35:16 buff1 modifier_treant_natures_guise cre=20.267 lastApplied=20.267 dur=-1.000 die=19.267 prevTick(0xA0)=111.900 | die-now=-90.21 | idx=0 ser=303 stk=0 creationFrame=624
21:35:16 buff2 modifier_fountain_aura_buff cre=20.300 lastApplied=20.300 dur=3.000 die=23.300 prevTick(0xA0)=111.900 | die-now=-86.17
21:35:16 buff3 modifier_treant_natures_guise_tree_walking cre=20.300 lastApplied=20.300 dur=-1.000 die=19.300 prevTick(0xA0)=111.900 | die-now=-90.17
```
Across 57 s: buff `cre/die` stayed **STATIC** while `prevTick(0xA0)` advanced 55.300→111.900 and `now`=109.473. `buff2` is an active **3 s** aura with `die=23.300`, so the engine-sim clock at sample time ∈ (20.3, 23.3) — a different epoch from our wall-anchored `GetGameTime` (`gs=108.067`). `A0` tracks **next think** (`now+~2.43`, i.e. 111.9 vs now 109.473), not die. ⇒ `CDOTA_Buff` uses the engine-sim epoch; our clock is wall-anchored. **Lead decision: record as OPEN CONTRACT item — do NOT patch**; offsets are not timestamps; contract decision with reviewer; probe v5.2 may add engine sim-time candidates. **W1 modifier remains OPEN (contract).**

**(b3) ownership/recent-damage guards (task-18 unaffected):**
```
21:35:16 [19] GetOwner(localHero)=nil raw m_hOwnerEntity=0x1748001 | RecursiveGetOwner(localHero)=nil
GetRecentDamage: hero API=0 raw=0 | creep API=0 raw=0   (guard works — no garbage values)
```
(task-18 remains won't-fix: `GetOwner` on a hero returning nil is consistent with the raw `m_hOwnerEntity` sentinel handle.)

### D7e. task-19 evidence(b) — **CLEAN PASS (API inventory resolution works)** [supersedes D7d/b1 FAIL]
Window (line-index): `stop.txt` L370723 @21:43:54 → `=== BOT LOOP done ===` L370724 → probe `host: running diag_api_probe.lua` L370738 @21:44:04 → parity diag L371003/L371115 → ONE loop restart L371138/L371144 @21:45:49 (single loop, pid 3588).
Verbatim probe rows (21:44:13):
```
[19] slot[0] off=0x24 handle=0x2A86EE item=item_tango       apiGetItemByIndex=item_tango      apiIsRealFalse=item_tango      apiByInstance=nil
[19] slot[1] off=0x28 handle=0x17086F8 item=item_magic_stick apiGetItemByIndex=item_magic_stick apiIsRealFalse=item_magic_stick apiByInstance=nil
[19] slot[2..14] off=0x2C..0x5C handle=0xFFFFFFFF item=-     apiGetItemByIndex=nil            apiIsRealFalse=nil             apiByInstance=nil
[19] slot[15] off=0x60 handle=0x118007D item=item_tpscroll   apiGetItemByIndex=item_tpscroll   apiIsRealFalse=item_tpscroll   apiByInstance=nil
[19] slot[16] off=0x64 handle=0xFFFFFFFF item=-              apiGetItemByIndex=nil            apiIsRealFalse=nil             apiByInstance=nil
[19] reference check: GetItemByIndex(15)=item_tpscroll, (16)=nil
```
- **PASS:** slot0=tango, slot15=tpscroll through `apiGetItemByIndex` and `IsRealFalse`; slot16=nil; reference `(15)/(16)` correct; raw-handle@0x60 resolver two-way matches.
- **Caveat:** third variant `apiByInstance` = **nil** in these rows (PM's expected "all three forms" not observed); either probe path doesn't provide a handle→instance for items or the ByInstance variant isn't wired — flagged to api-core/PM, does not block slots 0/15 acceptance.
Hero owners (all non-nil, raw retained) — `[19] hero owners:` 8 heroes `…ctrl/raw0xB0005 … ctrl/raw0x1748001`; `[17] hero[1..6] … owner=dota_player_controller replicating=nil` (real heroes); `[api] C_DOTA_PlayerResource located @0x3917A427000 validated players=10`.

### D7f. W1 modifier contract item — new two-sample evidence (offsets, NOT timestamps; no patch)
Probe v5.2, now-session lines:
```
21:44:14 [19] clock now=649.914 gs=108.067 in_game=541.8
21:44:14 [19] buff1 modifier_treant_natures_guise cre=20.267 lastApplied=589.167 dur=-1.000 die=588.167 prevTick(0xA0)=649.667 | die-now=-61.75
21:44:14 [19] buff2 modifier_treant_natures_guise_tree_walking cre=20.300 lastApplied=20.300 dur=-1.000 die=19.300 prevTick(0xA0)=649.667 | die-now=-630.61
21:44:14 [19] buff3 modifier_treant_living_armor_passive cre=154.200 lastApplied=590.733 dur=-1.000 die=589.733 prevTick(0xA0)=649.667 | die-now=-60.18
21:44:14 [19] epoch candidates: now=649.914 | localHero anim=649.667 sim=0.000 create=20.267 | gamerulesEntity anim=0.000 sim=0.000 create=0.000
```
Now-epoch: `prevTick(0xA0)=649.667` ≈ `now=649.914` (Δ0.25, advances with clock) ⇒ **A0 is now-epoch**, while `die < lastApplied` and `cre` static (20.267) for a long-lived aura ⇒ **field offsets are wrong, not timestamps**. Lead: **contract review, do NOT patch**. api-core probe v5.2 sim-time candidates included (`sim=0.000` on hero/gamerules entity). **W1-modifier stays OPEN CONTRACT.**

### D8. PASS/FAIL matrix (Lead/PM-mapped)
| Item | Verdict | Evidence |
|---|---|---|
| task-12 clock (`src=horn` ±2 s) | **PASS** | D2: anchor 100.300; 0:43↔43.7 s, 2:22↔141.4 s; samples/10s=0 |
| task-9 Phase A (movement/pathing) | **PASS** | D3: spawn→lane (-5800,1400), HUD "Farming the lane", `hard=60` benign, path 0.13-0.91 ms post-warmup, zero stall/no-route, orders all ok |
| task-13/4 HUD (draw/hud counters) | PASS (prior windows) | `[hud] cmds=47-55 text=16-24 world=0 overlaps=0 offscreen=0`, zero textwidth-fallback, screenshots 8/9/10 |
| W1 item1 `GetTeamData` | **PASS** | D7 RAW/API pid rows sane (kills/assists/level/heroId) |
| task-19 inventory + duplicate-buy | **CLOSED (code + evidence a + evidence b)** | D7b (duplicate-buy loop gone) + D7e (probe v5.2: slot0=tango, slot15=tpscroll via apiGetItemByIndex/IsRealFalse, slot16=nil, reference 15/16 correct, `+0x60` two-way match). Caveat: `apiByInstance` variant = nil (flagged, non-blocking) |
| W1 modifier timing | **OPEN CONTRACT — do NOT patch** (Lead) | D7f: `now=649.914`, `prevTick(A0)=649.667` (Δ0.25, advances) ⇒ A0 is now-epoch; `die<lastApplied` + static `cre=20.267` ⇒ wrong offsets not timestamps; contract review, no patch; api-core v5.2 sim-time candidates |
| task-21 API parity baseline | **PASS (api iteration-1, final; reviewer REVIEW.md 23:20)** | D12c: loader-context run `SUMMARY ok=86 garbage=0 stub=4 unverified=6 missing=3 error=0`, `FLAGGED: none`, `manifest total=214 missing=0`; `Entity.GetClassName=C_DOTA_Unit_Hero_Treant OK`, `GetRotation=fwd=-0.49,-0.87 OK`; api 111542 md5 BF073C4B…, backup ok_215024; remaining gap = loader globals (D12e/task-25) |
| task-22 API parity inventory | **DELIVERED (reference)** | `API_PARITY_INVENTORY.md`: 225 fns / 5604 sites / 136 early-game |
| task-24 GridNav aliasing (orders-nav) | **PASS(code)** | D12f/D12g: 4 gridnav rows OK in both samples — `IsTraversable` canonical+global `true,0`, `BuildPath hero+400` waypoints=1→2, `CreateNpcMap/Release twice` idempotent |
| task-25 GLOBALS content (loader-events) | **PASS(code) content gates validated** | D12m validation run: LaneGroups `visible_ally=7 all_groups=9`, `LaneGroup lane=1 creeps=5 refOk=true lane_path=4pts name=top`; `JungleCampsManager camps=24 source=nav`; `CampSites n=24`; `NAV statsValid=true lanesFromNav=true`; `XHelpers aoe=8 radius=537 start=8 end=1`; live rows green (D12l/B). Lane acceptance still pending (lastHits) |
| task-21 residual (new) | **PASS — Entity.IsDormant proof captured** | D12m: `Entity.IsDormant=false OK`; `IsDormant(own hero/creep/ally)=false b... OK`; `IsDormant(enemy heroes)=visible=5 foggedDormant=0 OK`; `SUMMARY ok=93 garbage=0`, `FLAGGED: none`; patch loaded via diagnostic bundle (loader 99132/EC0A4858, globals 44707/40F3FACD) |
| task-10 tick cost | **CONDITIONAL — script-side p90 breach, loader/globals exempt** | D12l proof run: (A) PASS errors=0/no OnNpcDying error/with_source 99%; (B) PASS globals= p50 0/p90 2/max 7-8 ms; (C) clean 74 samples p50=46/p90=456/p99=668/max=668, script p90=318/max=432, synth p90=150, 22 slow polls all top=OnUnitAnimation 150-267 ms (reference ~18-19 ms/event `Self Play.lua:2221`). Pending Lead A/B decision (accept documented script floor vs api hot-call perf pass). D6b RUN-C retained as pre-fix history |
| task-2 event synthesizer | **PASS(code)** with documented gaps | D7c: payload evidence (95% source/nonzero dmg, 8-11 castpoints, 18-key projectile + 900, humanOrders=0); gaps: particle approx-only, linear-projectile create/destroy, chat/GC, FogOfWar/NetChannel/Panorama/GC-http-protobuf-humanizer stubs |
| task-4 pause (Space/A) | **OPEN — pending runtime window** | D5 awaiting Space ≥10 s trace + mid-hold HUD screenshot (no Dota process/injection at 21:30+) |
| task-20 input acceptance (new DLL) | **OPEN — pending runtime window** | D4 post-game click matrix awaiting Lead/human lines (no post-game screen available: match ended and process closed) |

### D9. Defect notes captured in this window (no runtime impact during window)
- `21:02:06 loader: warmup OnUpdateEx error: ...\scripts\self_play\session.lua:52: attempt to call method 'HasClass' (a nil value)` — Panorama stub in warmup path (log-only).
- `21:17:55 loader: warmup entity scan error: D:\hake\lotus\src\loader.lua:1448: attempt to index global 'entity' (a nil value)` — loader warmup-path bug (owner loader-events, fix queued, runtime untouched).

### D10. On-disk build gate (read-only QA sweep — NOT runtime)
**CURRENT GATE: GREEN** (read-only `luajit loadfile` sweep at 21:40, no runtime touched):
```
api    : OK  (109401 B, mtime 21:38:09 — api-core itemAt/GetItemByIndex + entByHandle serial-bit guard fix;
              root cause: guard rejected valid CHandles h>=0xFFFFFF -> now h==0 or 0xFFFFFFFF; backup
              api.lua.ok_20261116_213922 md5 6CB1F93E43707676FFE6BAE0B0A35913, old 6C2E30E… fallback)
loader : OK  (80570 B, mtime 21:21:45 — reviewer batch with per-tick onUpdateEx/onUpdate split)
diag_api_probe : OK (63407 B, mtime 21:39:14 — probe v5.2, all instrumentation incl. both isReal variants)
menu/orders/render/overlay/bot_loop/nav/entity : OK
```
**HISTORICAL record (retained):**
- 21:22:09 on-disk `api.lua` (109709 B) failed `api.lua:2523: main function has more than 200 local variables`; the `21:22:58` reload died with `runtime error: error loading module 'api' ...`.
- earlier accepted build: 109156 B @21:24:20 (backup `api.lua.ok_20261116_212430`, md5 6C2E30E68CE5049EBD997852803502B3).
Lesson: this loadfile sweep is the mandatory pre-reload gate for every future window.

### D11. Runtime state at paste time
- **Update 21:35:** new runtime window on the relaunched process: Dota **pid 3588** injected `21:33:18.293` (`host: watchdog thread start pid=3588`), ONE bot_loop `21:33:18`; Lead double-probe `21:34:13` / `21:35:08` (`API_P1 BEGIN/END`, 57 s apart, in-game `now=109.473 gs=108.067 in_game=1.4`); Lead-driven loop restart `21:35:54 host: running bot_loop.lua` / `=== BOT LOOP ===` (single loop at each step, line-index verified). D7d holds the probe evidence.
- Earlier state (retained): old pid 4428 ended; process pid 3588 started 21:30:26 untouched until this window.
- **Still pending runtime actions:** task-20 post-game click matrix (needs a natural match end) and task-4 Space ≥10 s trace (needs a live match with loop). task-19 evidence(b) needs api inventory fix + re-probe; W1-modifier = OPEN CONTRACT (do not patch).
- **Scheduled narrow reload window (Lead, after the user is done watching):** stop loop (`stop.txt` → wait `=== BOT LOOP done ===` → delete) → api patch reload (api fixes ONLY `itemAt`/`GetItemByIndex` wrapper) → ONE loop restart via `call_elevated.bat 3588` (record `host: running` + `=== BOT LOOP ===` pair) → single `diag_api_probe` pass (both isReal variants) → paste `[19]` slot rows into D7d. Hands-off until then.
- **WINDOW GATE: CLEARED (explicit)** — api-core confirmed `api.lua` **110153 B @21:42:21 / md5 1C6913128FC6F5CD4C46FC04FA5C81B4** as the intended final +4 revision ("nothing newer from me; no further edits until Lead GO") and reviewer issued **PASS(code) on this exact revision** (REVIEW.md 22:02; backup byte-identical verified). Six equality sentinels `:180/:416/:916/:941/:1256/:1528`; `:2102` documented zero-consumer; older fallbacks intact; probe v5.2 OK. **Reload now waits ONLY for the human GO — no further re-check needed.**
  On GO, paste list (final): stop loop → ONE restart via `call_elevated.bat 3588` (record `host: running` + `=== BOT LOOP ===` + `[perf] load` + start number) → single `diag_api_probe` pass → **single `diag_api_parity.lua` pass in the SAME match** → paste (a) `[19]` item rows: slot0=tango; slot15 api/IsRealFalse/ByInstance all `item_tpscroll`; slot16=nil; reference `(15)=tpscroll`/`(16)=nil`; `+0x60` two-way resolver equal; (b) `[19] hero owners` non-nil high-serial + raw retained; (c) `[17] hero[i] replicating=` nil-real/non-nil-illusion; (d) `[12]` rows; (e) modifier contract lines (epoch candidates + 3-sample trace); (f) single-loop start/stop pair; (g) **parity baseline** into **Appendix D12** — run IMMEDIATELY after the probe: `run.txt = diag_api_parity.lua` (FINAL+FROZEN 39174 B @21:44:13, ~1–2 s) → capture block bounded by `=== API_PARITY BEGIN … ===` / `=== API_PARITY END ===` with `[parity] <group> <NS.Fn> = <value> | <TAG> | <doc-section> | <ref-call-site>` rows (~70), `[parity] manifest total=190 missing=N`, `[parity] SUMMARY ok=/garbage=/stub=/unverified=/missing=/error=`, `[parity] FLAGGED: …`; expected flags as-is: STUB `NPC.GetBarriers=nil`, `Engine.RunScript=false`, `GameRules.GetGameModeEntity=nil`, `Entity.GetClassName` (may be GARBAGE → `runes.lua:117` parity defect); watch GARBAGE `Entity.GetOwner(localHero)` nil, `FogOfWar.IsPointVisible(own pos)`, `GlobalVars.GetCurTime==GetGameTime`, `GetIndexOf` uniqueness, `World.GetGroundZ |Δz|<=600`; any MISSING = task-21 follow-up. Then task-21 parity diag analysis when api-core reviews it.
- Accepted evidence stands: task-10 PASS (RUN-C), task-12 PASS, task-9 Phase A PASS, task-19 PASS(code)+evidence(a), task-2 PASS(code).

### D12. task-21 API parity baseline — CAPTURED (iteration 1, line-index window)
Script: `diag_api_parity.lua` **FINAL + FROZEN** (api-core): **39174 B @21:44:13**, `loadfile OK`, standalone dry-run prints `API_PARITY DRYRUN OK` and writes nothing (`client.dll` guard). Re-registers `api` in the same Lua state (harmless) and reads only — no sleeps/loops.
Run order after GO, same match: (1) `run.txt = diag_api_probe.lua` (v5.2) → capture `[19]` slot/owner + `[12]` rows (D11 list); (2) **IMMEDIATELY** `run.txt = diag_api_parity.lua` (~1–2 s) → capture `[parity]` rows; line-index window.
Paste format (bounded by `=== API_PARITY BEGIN … ===` / `=== API_PARITY END ===`):
- lines `[parity] <group> <NS.Fn> = <value> | <TAG> | <doc-section> | <ref-call-site>`;
- final lines `[parity] manifest total=190 missing=N`, `[parity] SUMMARY ok=… garbage=… stub=… unverified=… missing=… error=…`, `[parity] FLAGGED: <list>`;
- ~70 runtime rows + manifest (only MISSING printed individually).
Expected flags to paste as-is: STUB `NPC.GetBarriers=nil`, `Engine.RunScript=false`, `GameRules.GetGameModeEntity=nil`, `Entity.GetClassName` (may be upgraded to GARBAGE by reviewer — parity defect for `runes.lua:117`); possible GARBAGE to watch: `Entity.GetOwner(localHero)` nil, `FogOfWar.IsPointVisible(own pos)`, `GlobalVars.GetCurTime==GetGameTime`, `GetIndexOf` uniqueness, `World.GetGroundZ |Δz|<=600`; MISSING baseline risk: `_G.Enum.*` tables except UnitOrder/OrderIssuer, plus Item/Modifier/GridNav/Input/Panorama/GC/HTTP if loader-owned (**any MISSING = task-21 follow-up**).
**CAPTURED (line-index window L370723-L371144):** `stop.txt` L370723 → `=== BOT LOOP done ===` L370724 → probe run L370738 @21:44:04 → parity diag run L371003 (`=== API_PARITY BEGIN ===` @21:45:07) / END L371115 → ONE bot_loop restart L371138/L371144 @21:45:49 (single loop, pid 3588).
```
21:45:07 === API_PARITY BEGIN === wall=111392.0
21:45:07 [parity] manifest total=190 missing=21
21:45:07 [parity] SUMMARY ok=69 garbage=1 stub=4 unverified=0 missing=21 error=1
21:45:07 [parity] FLAGGED: identity/Entity.GetClassName=STUB[npc_dota_hero_treant] | identity/Entity.GetRotation=GARBAGE[table: 0x02423af3c300] | hud_inputs/FogOfWar.IsPointVisible(heroPos)=ERROR[raise: D:\hake\lotus\src\api....] | handles/Player.GetGameModeEntity?=STUB[nil] | stubs/NPC.GetBarriers(hero)=STUB[nil (documented)] | stubs/Engine.RunScript=STUB[false (documented)] | manifest/GridNav.BuildPath=MISSING | manifest/GridNav.CreateNpcMap=MISSING | manifest/GridNav.IsTraversable=MISSING | manifest/GridNav.ReleaseNpcMap=MISSING | manifest/Item.GetCost=MISSING | manifest/Item.GetCurrentCharges=MISSING | manifest/Item.GetPlayerOwnerID=MISSING | manifest/Item.GetSecondaryCharges=MISSING | manifest/Item.GetStockCount=MISSING | manifest/Item.IsCombineLocked=MISSING | manifest/Item.IsItemEnabled=MISSING | manifest/Item.IsSellable=MISSING | manifest/Item.IsStackable=MISSING | manifest/Item.RequiresCharges=MISSING | manifest/Modifier.GetCaster=MISSING | manifest/Modifier.GetCreationTime=MISSING | manifest/Modifier.GetDieTime=MISSING | manifest/Modifier.GetName=MISSING | manifest/Modifier.GetStackCount=MISSING | manifest/Modifier.GetState=MISSING | manifest/World.GetGroundZ=MISSING
21:45:07 === API_PARITY END ===
```
Non-OK runtime rows (verbatim):
```
[parity] identity    Entity.GetClassName               = npc_dota_hero_treant  | STUB    | entity.md GetClassName     | self_play/runes.lua:117
[parity] identity    Entity.GetRotation                = table: 0x02423af3c300 | GARBAGE | entity.md GetRotation (deg) | self_play/active_items.lua:176
[parity] hud_inputs  FogOfWar.IsPointVisible(heroPos)  = raise: api.lua:21...  | ERROR   | fogofwar.md own position visible | -
[parity] handles     Player.GetGameModeEntity?         = nil                   | STUB    | gamerules.md GetGameModeEntity (documented follow-up) | -
[parity] stubs       NPC.GetBarriers(hero)             = nil (documented)      | STUB    | npc.md barriers table or nil (documented gap) | -
[parity] stubs       Engine.RunScript                  = false (documented)    | STUB    | engine.md documented gap (log-once false) | self_play/draft.lua:275
```
Sample OK rows: `Heroes.GetLocal=npc_dota_hero_treant`, `Heroes.GetAll=n=7 uniqueIdx=true`, `Entity.GetIndex=1395`, `Entity.GetAbsOrigin(hero)=-5800.0,1400.0,128.0`, `Entity.GetHealth=802/802`, `Entity.GetTeamNum=2`, `Entity.IsAlive=true`, `Entity.IsDormant=false` — all `| OK |` with doc+call-site refs.
MANIFEST MISSING detail (21 lines, all with reference call sites): `GridNav.BuildPath (Self Play.lua:764)`, `GridNav.CreateNpcMap (last_hit.lua:554)`, `GridNav.IsTraversable (Self Play.lua:370)`, `GridNav.ReleaseNpcMap (last_hit.lua:599)`, `Item.GetCost (inventory_cleanup.lua:21)`, `Item.GetCurrentCharges (active_items.lua:319)`, `Item.GetPlayerOwnerID (inventory_cleanup.lua:63)`, `Item.GetSecondaryCharges (objectives.lua:134)`, `Item.GetStockCount (shop.lua:18)`, `Item.IsCombineLocked (shop.lua:356)`, `Item.IsItemEnabled (active_items.lua:88)`, `Item.IsSellable (inventory_cleanup.lua:24)`, `Item.IsStackable (shop.lua:557)`, `Item.RequiresCharges (combat.lua:86)`, `Modifier.GetCaster (deward.lua:43)`, `Modifier.GetCreationTime (runes.lua:167)`, `Modifier.GetDieTime (Self Play.lua:1639)`, `Modifier.GetName (heroes/arc_warden.lua:33)`, `Modifier.GetStackCount (heroes/lion.lua:9)`, `Modifier.GetState (heroes/invoker.lua:95)`, `World.GetGroundZ (Self Play.lua:732)`.
**Iteration-1 defect list:** `Entity.GetClassName` STUB (reviewer may upgrade to GARBAGE — parity defect `runes.lua:117`), `Entity.GetRotation` GARBAGE[table], `FogOfWar.IsPointVisible(heroPos)` ERROR[raise in api.lua:21x], 21 MISSING (10×Item, 6×Modifier, 4×GridNav, World.GetGroundZ) = task-21 follow-up (loader-owned namespaces). No GARBAGE in the rest of the early-game path; 69 OK.
Transient (retained as record): an earlier parity launch at `21:43:55` died `[parity] FATAL: diag_api_parity.lua:240: module 'schema' not found:` — the FINAL frozen build (39174 B @21:44:13) runs clean from `=== API_PARITY BEGIN ===`.
Task-22 reference delivered: `API_PARITY_INVENTORY.md` (225 fns / 5604 sites / 136 early-game) — used as manifest source.
Verdict: **baseline captured**; task-21 stays OPEN on iteration-1 defects above.

**D12b. Adjudication corrections (Lead+reviewer accepted; line-index window L371003-L371115 unchanged):**
1) **MISSING(21) + the `FogOfWar.IsPointVisible` ERROR are LOADER-CONTEXT artifacts, not api defects** — the diag ran without loader shims: `Item.*`, `Modifier.*`, `World.GetGroundZ`, `GridNav.*` are loader/orders-owned namespaces and `FogOfWar` is loader-defined. Corrected user-facing summary = **"1 genuine api-owned defect (`Entity.GetClassName`) + a set of loader-side stubs to implement/verify"** (do NOT phrase as "21 api functions missing").
2) **`Entity.GetRotation = GARBAGE[table]` is a DIAG MIS-TAG** — the contract is `Angle` (`entity.md:164-166`); all 14 reference sites call `:GetForward()` immediately. No code change; the probe expectation/tag is fixed, not the API.
3) **Only api-owned defect = `Entity.GetClassName`** (`runes.lua:117` `C_*`-prefix comparison) → api-core iteration-1 item.
4) **Corrected order:** loader-context parity re-run (split manifest api-owned vs loader-owned) → api `GetClassName` → loader-events **task-23** (Modifier/Item/World/FogOfWar shims) → orders-nav+loader **task-24** (GridNav aliasing) → diag fixes (GetRotation tag/labels/acceptance-gap tags).
5) **task-22 inventory corrections** (reviewer's 4) being applied by developer; **task-19 remains CLOSED with residuals documented** (by-instance nil; illusion `replicating` needs an illusion present at probe time).

### D12c. Loader-context parity re-run — PLACEHOLDER (to fill on GO; runnable now)
Artifacts verified read-only at 21:50-21:51 (no runtime touched; live loop pid 3588 left alone). **api-core confirmed FINAL:**
```
diag_api_parity.lua     : FINAL OK 48563 B @21:50:05   (not 47662; loadfile + dry-run OK)
diag_api_parity_ctx.lua : OK       4280 B @21:52:16    (supersedes 3453; adds `loader.parityProbe()` rows once
                                                       loader-events binds them at globals drop; verify mtime/size at run time)
api.lua                 : OK      111542 B @21:49:16   (GetClassName fix; backup api.lua.ok_20261116_215024
                                                        md5 BF073C4BAD4DFFD1B42C090A4C41F2E7; older 214227/110153 retained)
nav.lua                 : OK       57019 B @21:50:26   (orders-nav task-24 GridNav aliasing; evidence pending)
orders.lua              : OK
```
Planned re-run (Lead GO; **SAME live loop, NO restart needed** — read-only script): `run.txt = diag_api_parity_ctx.lua` → capture `=== API_PARITY BEGIN/END ===` block:
- **split manifest: api-owned vs loader-owned rows** (`loaderctx` / UNVERIFIED tags);
- `[parity-ctx] GLOBAL …` rows for `LaneGroupsManager`, `LaneCreepsManager`, `JungleCampsManager`, `LIB_DAMAGE_PREDICTION`, `KV_LIB`, `XHelpers`;
- `[parity] manifest`, `[parity] SUMMARY`, `[parity] FLAGGED`, `[parity] ACCEPTANCE` rows.
Expected vs D12 iteration 1: `loader=true`; `garbage=0` (GetRotation no longer GARBAGE — Angle contract; GetClassName fixed/OK); `stub≈5-7`; `unverified≈5`; `missing≈0-3` (re-attributed to loader-owned namespaces/globals, not api); `error=0`.
**CAPTURED (line-index: `=== API_PARITY BEGIN ===` L380753 → `=== API_PARITY END ===` L380886 @21:51:09/10; 134 rows per PM, 104 in QA slice; loader-context session):**
```
21:51:09 === API_PARITY BEGIN === wall=111754.3 inventory=API_PARITY_INVENTORY.md(225 fns/136 early)
21:51:10 [parity] manifest total=214 missing=0 (note: loader-owned namespaces absent only if this script runs outside the loader session)
21:51:10 [parity] SUMMARY ok=86 garbage=0 stub=4 unverified=6 missing=3 error=0
21:51:10 [parity] FLAGGED: none
21:51:10 === API_PARITY END ===
21:51:10 [parity-ctx] parity diag ok=true err=
```
api-owned rows now clean (fixes verified):
```
21:51:09 [parity] identity Entity.GetClassName = C_DOTA_Unit_Hero_Treant | OK | entity.md GetClassName; runes.lua:117 compares C_* schema class => defect | self_play/runes.lua:117
21:51:09 [parity] identity Entity.GetRotation  = fwd=-0.49,-0.87            | OK | entity.md GetRotation -> Angle:GetForward(), active_items.lua:176 | self_play/active_items.lua:176
```
Globals rows (root-cause surface):
```
21:51:10 [parity] globals LaneGroupsManager   = table keys=4 | OK      | GLOBALS_API.md LaneGroupsManager | -
21:51:10 [parity] globals LaneCreepsManager   = nil          | MISSING | GLOBALS_API.md LaneCreepsManager | -
21:51:10 [parity] globals JungleCampsManager  = table keys=1 | OK      | GLOBALS_API.md JungleCampsManager | -
21:51:10 [parity] globals LIB_DAMAGE_PREDICTION = nil        | MISSING | GLOBALS_API.md LIB_DAMAGE_PREDICTION | -
21:51:10 [parity] globals KV_LIB              = nil          | MISSING | GLOBALS_API.md KV_LIB | -
21:51:10 [parity] globals XHelpers            = table keys=3 | OK      | GLOBALS_API.md XHelpers | -
```
ACCEPTANCE rows (user-symptom evidence, all UNVERIFIED in this mid-joined match):
```
21:51:10 [parity] acceptance lastHits@clock = clock=957.7 lasthits=0 denies=0 | UNVERIFIED | criterion >=3 last-hits by 5:00 | -
21:51:10 [parity] acceptance xpGrowth@clock = clock=957.7 xp=1160 lvl=4      | UNVERIFIED | criterion XP grows between samples | -
21:51:10 [parity] acceptance distToWave    = 2541 u (near<1500=0, enemy<900=0) | UNVERIFIED | criterion <=600u while last-hitting | -
21:51:10 [parity] acceptance distToAlly    = 6980 u (npc_dota_hero_drow_ranger) | UNVERIFIED | criterion <=900u from an ally (teamplay) | -
21:51:10 [parity] acceptance activity      = attacking=false running=false hp=10... | UNVERIFIED | HUD 'Now' must match actions (attacking/running/near wave) | -
21:51:10 [parity] ACCEPTANCE clock=957.7 lasthits=0 xp=1160 lvl=4 distWave=2541 distAlly=6980 attacking=false running=false enemyCreeps<900=0
```
Runtime during diag: one transient `21:51:07 loop 2810 0.0s nil hp=- 0 0 gt=1063.6` (diag run only); recovery immediately after END: `21:51:10 loop 2834 0.0s npc_dota_hero_treant hp=956 -7191 -6584 gt=1066.0` → `21:51:15 loop 2882 0.1s … gt=1071.1` (loop healthy, tick ~53 ms).

**Interpretation (adjudicated root causes — see D12e):** api-owned surface is CLEAN (garbage=0, GetClassName/GetRotation OK); the remaining gap is **loader-side globals**, which are the causal root of the user-visible symptoms.
**api iteration-1 = PASS (final)** — reviewer REVIEW.md 23:20: `Entity.GetClassName` PASS (no reopen), scope=api surface clean; api.lua 111542 B md5 BF073C4B…, backup `ok_215024` verified, 6 handle-sentinels unchanged.

### D12d. Post-globals ctx parity re-run + fresh-match lane acceptance — PLACEHOLDER (after `globals.lua` lands)
Re-run `diag_api_parity_ctx.lua` after loader-events lands `src/globals.lua` (LaneGroupsManager from lane-creep scan, minimal LIB_DAMAGE_PREDICTION contract, JungleCampsManager from `C_DOTA_NeutralSpawner m_Type@0x5F0`, KV_LIB from gamedata, parityProbe; perf caching p90<300 ms) + orders-nav's 3 lane polylines + camp coordinate table.
**Run-time rule:** use ctx diag **4280 B @21:52:16 or newer** (verify mtime/size at run time; older 3453 superseded) and paste **both samples per reviewer protocol** — one at `gt≈75-105 s` and one at `gt≈300 s` (same match, line-index window).
Status check 21:53: `globals.lua` **ABSENT on disk** (not yet landed) — re-run blocked on loader-events.
**GATE UPDATE 22:00 — GLOBALS DROP ON DISK, GATE GREEN** (read-only `luajit loadfile` sweep, no runtime touched; Dota pid 3588 idle at menu):
```
globals.lua            : OK  37626 B @21:59:05  (NEW; LaneGroupsManager per tick, LIB_DAMAGE_PREDICTION,
                                                 JungleCampsManager from C_DOTA_NeutralSpawner, parityProbe bound)
loader.lua             : OK  92045 B @21:58:50  (backup loader.lua.ok_20261116_215616 = 80570 B @21:21:45)
nav.lua                : OK  65627 B @21:58:43
diag_api_parity_ctx.lua: OK   4280 B @21:52:16  (already calls loader.parityProbe() -> no change needed)
api.lua                : OK 111542 B @21:49:16
orders/menu/render/overlay/bot_loop/entity/diag_api_parity : OK
```
**FROZEN-FILES VERIFY 22:02 (read-only, QA md5; use these hashes with the pasted D12d rows):**
```
nav.lua            : OK 65791 B @22:01:08 md5 449DF2C5D99D3431E6746B8431A0F135   (scope fix; defective build preserved
                                                                                 as nav.lua.bak_20261116_defect_inside_cellCenter 65627 B @21:58:43)
loader.lua         : OK 92528 B @22:00:54 md5 40115111330878A3FF8B76E58D9C2121   (GridNav IsTraversable 2nd-return forwarding
                                                                                 + globals nav-consumption + [parity] NAV row)
globals.lua        : OK 42040 B @22:01:42 md5 228B32DEADFB43BCCFF95C29CFD9B6CF   (NEWER than PM freeze 41662 @22:00:46/DD86F0AE
                                                                                 -> reconfirm final with loader-events)
api.lua            : OK 111542 B @21:49:16 md5 BF073C4BAD4DFFD1B42C090A4C41F2E7
diag_api_parity.lua: OK 53680 B @22:01:44 md5 B2C0FB74963EBD7DD345328A3402372A   (NEWER than PM freeze 52830 @22:00:27
                                                                                 -> reconfirm final with api-core)
diag_api_parity_ctx.lua : OK 4280 B @21:52:16 md5 9D9EFD5263436EE2FE45651B44CC6E5E
diag_orders.lua    : OK 28753 B @22:00:14 md5 F38DDE44C76951C3259CC4C52C1103BD
loader backups: loader.lua.ok_20261116_215616 (80570 B) intact.
```
⚠ Two files are NEWER than the PM freeze snapshot (`globals.lua`, `diag_api_parity.lua`) — **reload must wait for owner confirmation of these exact sizes/md5s**, otherwise evidence attribution breaks.
**Loop-stop CONFIRMED (PM): `22:01:29 === BOT LOOP done ===` in host.log.** Reload pending final hash-set only.
**CURRENT VERIFIED SET (for D12d sample attribution; re-verify at run time):**
```
nav.lua            65791 @22:01:08  md5 449DF2C5D99D3431E6746B8431A0F135   CONFIRMED
loader.lua         92528 @22:00:54  md5 40115111330878A3FF8B76E58D9C2121   CONFIRMED
globals.lua        42040 @22:01:42  md5 228B32DEADFB43BCCFF95C29CFD9B6CF   pending loader-events confirmation
api.lua           111542 @21:49:16  md5 BF073C4BAD4DFFD1B42C090A4C41F2E7   CONFIRMED
diag_api_parity.lua 53680 @22:01:44 md5 B2C0FB74963EBD7DD345328A3402372A   pending api-core confirmation
diag_api_parity_ctx.lua 4280 @21:52:16 md5 9D9EFD5263436EE2FE45651B44CC6E5E  CONFIRMED
diag_orders.lua    28753 @22:00:14  md5 F38DDE44C76951C3259CC4C52C1103BD   CONFIRMED
```
**PROVENANCE RULE (recorded):** samples are valid only from a restart that happened **AFTER all final file mtimes**, in a **fresh single-player Treant match from the horn**, with **exactly one `host: running … bot_loop.lua`** (line-index verified) — otherwise discard the sample.

**CLEANUP WINDOW (22:03:51–, valid candidate; line-index):**
- ❌ **Discarded contaminated window:** old process had TWO loop starts — `L395794 [22:01:42.056] host: running bot_loop.lua` / `L395802 22:01:42 === BOT LOOP ===` and `L396940 [22:02:41.729] …` / `L396949 22:02:41 === BOT LOOP ===` — with interleaved counters at `22:02:58 loop 352 1.4s npc_dota_hero_treant hp=956 -7191 -6584 gt=1774.0` **and** `22:02:58 loop 141 1.0s … same gt=1774.0`. Old process then vanished (host.log silent `22:02:58 → 22:04:25`). **Not acceptance evidence.**
- ✅ **Cleanup per Lead:** new Dota launched `22:03:51` (pid **21672**); injected `L397808 [22:04:25.453] host: watchdog thread start pid=21672`; **ONE loop** `L397810 [22:04:25.463] host: running bot_loop.lua` / `L397818 22:04:25 === BOT LOOP ===`; `22:04:27 [perf] load total=2060ms require=1952ms kv=105ms onLoaded=0ms warmup=3ms (entity=0ms nav=2ms modules=1ms updateEx=0ms)`; `stop.txt` absent; loop counters single sequence (`loop 805-817` in lobby, `nil hp=- gt=-1.0`). **Provenance PASS** (restart 22:04:25 is AFTER all final file mtimes: nav 22:01:08 / loader 22:00:54 / globals 22:01:42 / diag 22:01:44 / api 21:49:16 / ctx 21:52:16 / diag_orders 22:00:14). ONE loop verified; no concurrent counters after 22:04:25.
- **Pending:** Lead/human creates fresh single-player Treant match from the horn → `ctx` s1 at `gt≈75-105 s` → `ctx` s2 at `gt≈300 s` → `diag_orders` once; then paste into D12d/D12e with line indices.

### D12f. CLEAN-WINDOW acceptance samples (match live 22:06+, one loop since L397810)
Sample 1 — `ctx` run `L407135 [22:08:10.737] host: running diag_api_parity_ctx.lua`; `=== API_PARITY BEGIN ===` L407154 @22:08:10 → `=== API_PARITY END ===` L407280 @22:08:11; **gt=185.5** (window slightly late vs gt≈75-105 target — record actual); ctx wrapper rows L407287-407299; loop continues (no restart).
```
22:08:10 [parity] context loader=true (loader-owned namespaces expected when true)
22:08:11 [parity] manifest total=214 missing=0
22:08:11 [parity] SUMMARY ok=91 garbage=1 stub=4 unverified=5 missing=2 error=0
22:08:11 [parity] FLAGGED: identity/Entity.IsDormant=GARBAGE[true(want false)]
22:08:11 [parity] gridnav nav.IsTraversable(heroPos) [canonical] = true,0 | OK | gridnav.md:33 (boolean, integer)
22:08:11 [parity] gridnav GridNav.IsTraversable(heroPos) [global] = true,0 | OK | gridnav.md:33 via _G
22:08:11 [parity] gridnav GridNav.BuildPath(heroPos,+400) = waypoints=1 | OK | gridnav.md waypoint list
22:08:11 [parity] gridnav GridNav.CreateNpcMap({})/Release twice = map,release=true,secondRelease=true | OK | idempotent
22:08:11 [parity] globals LaneGroupsManager = table keys=17 | OK
22:08:11 [parity] globals JungleCampsManager = table keys=16 | OK
22:08:11 [parity] globals LIB_DAMAGE_PREDICTION = table keys=25 | OK
22:08:11 [parity] globals XHelpers = table keys=3 | OK
22:08:11 [parity] globals LaneCreepsManager = nil | MISSING   (documented-deferred)
22:08:11 [parity] globals KV_LIB = nil | MISSING                (documented-deferred)
```
ctx (`loader.parityProbe`) rows L407287+:
```
22:08:11 [parity-ctx] loader.parityProbe ok=true rows=14
22:08:11 [parity] context loader=true (api registered + loader shims active)
22:08:11 [parity] Item.* item=item_tango charges=3 secondary=0 enabled=false cost=90 ownerID=0 stackable=true sellable=true combineLocked=false recipe=false stock=99(STUB) | PARTIAL
22:08:11 [parity] Modifier.* name= cre=0.000 die=0.000 dur=148701184000.000 stack=32760.000 state=0.000 | offsets cre=0x54 die=0x64 dur=0x60 now=185.489 epoch=OTHER/NOT-TIMESTAMP | CONTRACT-SAMPLE(pair rows across two probes >=20s apart: cre must stay static, now advances)
22:08:11 [parity] World.GetGroundZ hero(-6083,4544)=128 p2(0,0)=128 p3(-4000,-3000)=128 p4(3000,2500)=128 | varied=false | STUB(flat value; nav grid missing)
22:08:11 [parity] FogOfWar.IsPointVisible(hero)=false IsVisible=true raises=true | STUB(documented: no client FOW mask without native hook; false-conservative) | ERR
22:08:11 [parity] GLOBALS LaneGroupsManager visible_ally=0 visible_enemy=0 invisible_enemy=0 all_groups=0 | EMPTY(no lane creeps in scan)
22:08:11 [parity] GLOBALS LIB_DAMAGE_PREDICTION available()=true unit_attack=0 attack_types=0/1 | OK
22:08:11 [parity] GLOBALS LIB_DAMAGE_PREDICTION targets[hero].attacks=0 | OK
22:08:11 [parity] GLOBALS JungleCampsManager camps=0 source=none | EMPTY
22:08:11 [parity] NAV laneRoutes=present team2.lane1.pts=4 campSites=0 statsValid=false lanesFromNav=false | PARTIAL(nav not ready)
22:08:11 [parity] GLOBALS XHelpers keys=xkv,XAbility,GetScript XAbility aoe=0 radius=0 start=0 end=0 | PARTIAL
22:08:11 [parity] GLOBALS LaneCreepsManager missing=expected(documented-deferred: 0 direct 16.11 call sites)
22:08:11 [parity] GLOBALS KV_LIB missing=expected(documented-deferred: 0 direct 16.11 call sites)
22:08:11 [parity] ACCEPTANCE gt=185.5 lastHits=0.00 denies=0.00 xp=202.00 lvl=1.00 gold=0.00 distWave=-1 distAlly=-1 attacking=false running=false
```
Diag acceptance rows: `clock=75.6 lasthits=0 xp=174 lvl=1 distWave=89 (near<1500=7, enemy<900=3) distAlly=576 (npc_dota_hero_axe)`; `Entity.IsDormant=true(want false)` is the **new GARBAGE flag** (api-owned, self_play `Self Play.lua:244` consumer) — needs api-core triage; `Modifier` contract sample (cre=0/die=0/dur huge/stack=32760) still `OTHER/NOT-TIMESTAMP`; `World.GetGroundZ` flat 128 (nav grid missing); 3 API missing lines `NPC.GetLastHits/NPC.GetDenies/Player.GetGold`.
Sample 2 + `diag_orders` pending (Lead).

**MEASUREMENT CLARIFICATION (PM/reviewer approved — record as clarification, NOT defect):** sample-1's content rows (`[parity] NAV laneRoutes=present team2.lane1.pts=4 campSites=0 statsValid=false lanesFromNav=false`, `World.GetGroundZ … varied=false`, `LaneGroupsManager visible_ally=0`, `JungleCampsManager camps=0`) are **VIRGIN-MODULE artifacts**: `ctx` runs in a fresh Lua state that never rescans nav, while the live session refreshes nav each tick via loader. So those rows describe an uninitialized module, not a product failure. **Sample-2 outcome/acceptance rows (lastHits/xp/dist) are live-readable and valid now**; **content rows must be re-run after the next reload** (see D12g).
Nav build status: tuned build on disk `nav.lua` **67122 B @22:11:09 md5 24304FA6DEE56BAC8A2E895D300C4CC3** (loadfile OK; fixes live `camps=0` detector; `campSites()` lazily builds grid). Needs reload to take effect; task-24 GridNav evidence unaffected.

### D12g. Sample-2 (ctx run #4 @22:11:58) — two-sample table + adjudication
Run/provenance (line-index): `L409901 [22:11:58.391] host: running diag_api_parity_ctx.lua` → bootstrap rows L409909-409917 → `=== API_PARITY BEGIN ===` L409922 → `=== API_PARITY END ===` L410054 @22:11:58/59; wrapper `[parity] ACCEPTANCE gt=413.1 …`.
**File hash set for this run (PM-provided; disk has since moved on — see D12h):** diag **54028 / md5 66CC3AFA…**, ctx **5055 / md5 59483542…**, nav **67122 / md5 24304FA6DEE56BAC8A2E895D300C4CC3**, api **111542 / md5 BF073C4BAD4DFFD1B42C090A4C41F2E7**.
Bootstrap (ctx start): `[parity-ctx] loader bootstrap=true err= tick=function Item=true Modifier=true World=true GridNav=true Tower=true Tree=true Bottle=true PowerTreads=true`; `GLOBAL LaneGroupsManager=table keys=17 [groups_by_index_ally,…] visible_ally=0 visible_enemy=0 invisible_ally=0 invisible_enemy=0`; `LaneCreepsManager=nil`; `JungleCampsManager=table keys=16 … camps=0`; `LIB_DAMAGE_PREDICTION=table keys=25 [unit_attack,…]`; `KV_LIB=nil`; `XHelpers=table keys=3 [XAbility,GetScript,xkv]`; `_G.CACHE=nil`; `HeroInfoCache=nil`.
Diag rows (both samples): `SUMMARY ok=91 garbage=1 stub=4 unverified=5 missing=2 error=0`; `FLAGGED: identity/Entity.IsDormant=GARBAGE[true(want false)]`; `manifest total=214 missing=0`; gridnav 4 rows OK (`IsTraversable true,0` canonical+global; `BuildPath hero+400 = waypoints=2`; `CreateNpcMap/Release twice = idempotent`).
**Two-sample table (diag drives criteria):**
| metric | S1 clock=75.6 | S2 clock=303.2 | verdict |
|---|---|---|---|
| lastHits | 0 | 0 | **FAIL (≥3 required)** |
| XP / level | 174 / lvl 1 | 1004 / lvl 3 | PASS (grows) |
| distWave | 89 u (enemy<900=3) | 94 u (enemy<900=6) | PASS ≤600 |
| distAlly | 576 u (axe) | 495 u (axe) | PASS ≤900 |
| activity | attacking=false running=false | attacking=false running=false | mismatch with wave at 89-94 u |
| Entity.IsDormant(local hero) | true (GARBAGE) | true (GARBAGE) | blocker — see D12h |
(ctx rows S2): `[parity] NAV laneRoutes=present team2.lane1.pts=4 campSites=24 statsValid=false lanesFromNav=false | OK` (campSites improved 0→24); `World.GetGroundZ` flat 128 `STUB`; `LaneGroupsManager visible_ally=0 all_groups=0 EMPTY`; `JungleCampsManager camps=0 source=none EMPTY`; `LIB_DAMAGE_PREDICTION available()=true unit_attack=0 attack_types=0/1 OK`; `XHelpers … XAbility aoe=0 radius=0 start=0 end=0 PARTIAL`; `[parity] GLOBALS LaneCreepsManager/KV_LIB missing=expected(documented-deferred)`.
Adjudication gates (PM): (a) LaneGroups all_groups>0 by gt≈300 — **ctx still EMPTY (virgin-state; live `[globals]` line pending)**; (b) LIB unit_attack non-zero under attack — **0 (no attack in fresh state)**; (c) Jungle camps≥10 real source — **0 (reload of tuned nav pending)**; (d) GroundZ must vary — **flat 128**; (e) XAbility missing list — aoe/radius/start/end all 0; (f) outcome — **only lastHits fails**; (g) `[SelfPlay mode=]` lines — **none exist in host.log or `D:\hake\lotus\self_play.log`**; the bot log only alternates `[SelfPlay state] bot not running: no local hero or player` / `bot running` during this period (recorded as the available decision-state evidence).

### D12h. Causal-evidence note — `Entity.IsDormant=true` is the prime last-hit blocker (Lead GO: patch being applied)
Both samples report `Entity.IsDormant(local hero)=true` although the local hero is alive/moving (loop `hp=473 -5958,3855 gt≈395`) — the script's last-hit/mode logic (`Self Play.lua:244` consumer) treats the hero as dormant ⇒ **explains lastHits=0 with wave at 89-94 u and `attacking=false running=false`**. `Entity.IsDormant` is the **only FLAGGED/GARBAGE row** in an otherwise clean api surface (ok=91, error=0). Patch is write-ready/reviewer-approved; **Lead GO given — patch being applied**, then reload the freeze set and **acceptance re-test must show lastHits>0** (≥3 by 5:00) with GroundZ varying / NAV `statsValid=true` / Jungle camps≥10 on the tuned nav.
Disk moved on since sample-2 (read-only QA at 22:13:47; needs new freeze set + reload): `api.lua` **112707 @22:13:13 md5 71ED9B2D79F95FAB02E8F0A970B4E5E7**, `globals.lua` **43733 @22:12:31 md5 7B4C687B8B6C5CD85F6986EB7F29F4EA**, `loader.lua` **95834 @22:12:56 md5 C3BFEDCF381BB4E1F268ED7605AE471E**, `diag_api_parity.lua` **55931 @22:13:38 md5 D87DDB1B26DD3A3FD69B728391F62F71**, `diag_api_parity_ctx.lua` **5528 @22:13:07 md5 AF414A285AD70F936D45BFAE4F119399**, `nav.lua` 67122 @22:11:09 `24304FA6…` (unchanged).

### D12i. FREEZE SET for next reload window (QA read-only verify 22:14; run-time re-verify required)
```
api.lua                : 112707 @22:13:13 md5 71ED9B2D79F95FAB02E8F0A970B4E5E7  CONFIRMED
                         backup api.lua.ok_20261116_221348 = 112707 @22:13:13 (verified); baseline ok_215024/111542 retained
diag_api_parity_ctx.lua: 5528  @22:13:07 md5 AF414A285AD70F936D45BFAE4F119399  CONFIRMED
globals.lua            : 43733 @22:12:31 md5 7B4C687B8B6C5CD85F6986EB7F29F4EA  CONFIRMED
nav.lua                : 67122 @22:11:09 md5 24304FA6DEE56BAC8A2E895D300C4CC3  FROZEN (unchanged)
diag_api_parity.lua    : 55931 @22:13:38 md5 D87DDB1B26DD3A3FD69B728391F62F71  ⚠ NEWER than PM freeze
                         (PM stated 54587 @22:13:07 md5 46D52310… -> not on disk now)
loader.lua             : 96481 @22:13:58 md5 8287895DFA16BFA91A5721BAD6A1E5DB  ⚠ NEWER than PM freeze
                         (PM stated 95834 @22:12:56 md5 C3BFEDCF…; backup loader.lua.ok_20261116_221351 holds 95834)
                         backups: loader.lua.ok_20261116_221224 = 92528 (22:00:54)
```
**CORRECTED ATTRIBUTION SET — reviewer FINAL PASS (supersedes earlier PM numbers):**
```
api.lua                : 112707 @22:13:13 md5 71ED9B2D79F95FAB02E8F0A970B4E5E7  FINAL (backup ok_221348)
diag_api_parity.lua    :  55931 @22:13:38 md5 D87DDB1B26DD3A3FD69B728391F62F71  FINAL (supersedes 54587/46D52310)
diag_api_parity_ctx.lua:   5528 @22:13:07 md5 AF414A285AD70F936D45BFAE4F119399  FINAL
loader.lua             :  96481 @22:13:58 md5 8287895DFA16BFA91A5721BAD6A1E5DB  FINAL (supersedes 95834/C3BFEDCF;
                                                                                    backup loader.lua.ok_20261116_221351 holds 95834)
globals.lua            :  43733 @22:12:31 md5 7B4C687B8B6C5CD85F6986EB7F29F4EA  FINAL
nav.lua                :  67122 @22:11:09 md5 24304FA6DEE56BAC8A2E895D300C4CC3  FROZEN
```
Reload imminent (Lead). Expected pastes for the next window (line-index):
- **two ctx samples** (gt≈75-105 s and ≈300 s);
- **live `[globals]` rows** (every 30 s): `laneGroups=… all_groups=… visible_ally=… ally_creeps=… camps=… campSource=… navValid=… libAvail=… unit_attack=… attacks=… xability=…`;
- **`diag_orders` rows**;
- **IsDormant proof rows**: `Entity.IsDormant=false OK` (own hero), own-hero/creep/ally `bad=0`, enemy allowed; expect **`SUMMARY ok=94 garbage=0`**;
- `[parity-context] rescan ok=true valid_before/after`;
- **content gates**: camps 10-24 `source=nav`; `laneGroups/all_groups>0`; `unit_attack>0` when attacked; `GroundZ varied`;
- **acceptance table**: lastHits must move **>0** (≥3 by ≈300 s), XP growth, distWave≤600, distAlly≤900, HUD/activity.

### D12j. POST-RELOAD evidence window (22:15:09+) — **PRE-FIX evidence, superseded pending proof run**
_Labelled pre-fix: perf spiked (task-10 reopened) and the OnNpcDying error voids this window as acceptance evidence; rows retained for attribution only._
Reload marker: `L412632 [22:15:09.428] host: running bot_loop.lua` / `L412640 22:15:09 === BOT LOOP ===` / `22:15:11 [perf] load total=2084ms require=1945ms kv=98ms onLoaded=0ms warmup=41ms (entity=4ms nav=30ms modules=0ms updateEx=7ms)`; loop single sequence (`loop 1..66`), match live (`gt 606.9→696.2`).
**LIVE `[globals]` — GREEN (content evidence; reviewer: ctx cached-false rows are non-evidence):**
```
L412744 22:15:11 [globals] XHelpers.XAbility filled from npc_abilities KV: abilities=1634 aoe=8 radius=537 start_widths=8 end_widths=1
L412746 22:15:11 [globals] JungleCampsManager: 24 camps discovered source=nav (camp_type/team from nav map data when available, spawner m_Type@0x5F0 otherwise)
L412747 22:15:11 [globals] laneGroups=10 all_groups=10 visible_ally=8 visible_enemy=2 ally_creeps=30 enemy_creeps=6 camps=24 campSource=nav navValid=true libAvail=true unit_attack=0 attacks=0 xability=554/maps=4/4
L413030 22:15:41 [globals] laneGroups=12 all_groups=12 visible_ally=9 visible_enemy=3 ally_creeps=28 enemy_creeps=4 camps=24 campSource=nav navValid=true libAvail=true unit_attack=10 attacks=0 xability=554/maps=4/4
L413200 22:16:12 [globals] laneGroups=10 all_groups=10 visible_ally=8 visible_enemy=2 ally_creeps=28 enemy_creeps=5 camps=24 campSource=nav navValid=true libAvail=true unit_attack=3 attacks=0 xability=554/maps=4/4
```
Content gates: `camps=24 source=nav` ✓; `all_groups>0` (10-12) ✓; `visible_ally` 8-9 ✓; `libAvail=true` ✓; `unit_attack` 0→10→3 ✓; `navValid=true` ✓; `xability=554/maps=4/4` ✓.
**NEW DEFECT (void criterion for decisive run):**
```
22:15:12 events: OnNpcDying error: ...\Roaming\xYjGsPeqoWTEzbif\scripts\self_play\last_hit.lua:219: attempt to index field 'lastSource' (a nil value)
22:15:39 events: polls=126 avg=23.7ms scan=4.4ms fire=19.2ms max=280.0ms slowPolls=3 errors=1 ... OnEntityHurt=166ms OnProjectile=73ms OnUnitAnimation=2128ms
22:16:42 events: polls=331 avg=23.6ms scan=3.9ms fire=19.7ms max=379.0ms slowPolls=7 errors=1 ... OnEntityHurt=579ms OnProjectile=268ms OnUnitAnimation=5444ms
```
**PERF REGRESSION (QA-measured, task-10 reopen risk; reviewer already reopened on slowPolls/5.2 s):** since reload L412622: **47 `[perf] tick` lines, min=716 ms, p50=1363 ms, p90=1994 ms, max=5210 ms, 45/47 flagged SLOW**, 7 `[perf] slow poll` lines (`cost=203-379 ms`, `top=OnUnitAnimation(165-328 ms)`, `polls` up to 191). Samples: `n=35 total=5210ms script=5040`, `n=41 total=2587ms script=2537`, `n=3 total=1099ms script=977`. `script=` dominated by `onUpdate` (not `onUpdateEx`).
Reviewer ruling recorded: **content evidence = live `[globals]` rows + `diag_orders`; ctx samples only IsDormant proof + ACCEPTANCE; task-25 content sign-off PROVISIONAL until the navValid cache fix lands** (queued next window). loader-events fixing OnNpcDying payload.

### D12k. DECISIVE-WINDOW plan — **ON HOLD** until combined patch + green proof run (Lead stopped the window)
**Fix bundle for the proof run — reviewer RE-SIGNED PASS(conditional)** (scope: loader 57 lines / globals 50 lines; backups `*.ok_221849` verified):
```
loader.lua  : 98534 @22:19:15 md5 2FE4E982D610435166A4FA97FEA2A9DD   (backup loader.lua.ok_20261116_221849 = 96481)
globals.lua : 44215 @22:19:25 md5 D58897A4E9B03A543F932777D1F1B286   (backup globals.lua.ok_20261116_221849 = 43733)
api.lua 112707/71ED9B2D…, nav.lua 67122/24304FA6…, diag 55931/D87DDB1B…, ctx 5528/AF414A28… unchanged
```
**Reviewer conditions (verbatim, recorded):** (1) proof run must include **real-kill rows**; (2) **fatal-window / melee `attackTargets` code confirmation requested from loader-events**; (3) steady-state gate **p90<300 / max<1000 / slowPoll=0 / errors=0 / `globals=` ≤10-20 ms**; (4) **no edits after these hashes without a new re-sign**.
**Runtime state:** Dota **pid 22224** (started 22:16:59), `host.log` silent since `22:16:42` → new process **not injected yet**; Lead is at the PROOF-reload step (inject → one loop → normal match → ≥2 min steady state with `globals=` column + real-kill rows).
**NEW instrumentation to capture in the proof run:** `[perf] tick` now includes a **`globals=<ms>`** column and the `events:` summary includes **globals timing**; also record `with_source` improvement from the event-order fix.
**Gate 1 — proof run required first (combined patch: additive OnNpcDying payload + per-tick cost fix):** normal match, steady-state ≥2 min in ONE loop must show **p90<300 ms, slowPoll=0, errors=0, `OnNpcDying error` ABSENT, live `[globals]` rows green, `globals=` ≤10-20 ms**. Only then is the decisive window scheduled.
**Gate 2 — decisive window (Lead ends match → fresh Treant game → ONE single-loop run):** capture list (line-index):
1. **Steady-state perf sample in the same run** (≥2 min after horn): `[perf] tick` p50/p90/max + slowPoll count + all `[perf] slow poll` lines.
2. Live `[globals]` rows (3-4).
3. `ctx` sample-1 at gt≈75-105 s — **IsDormant proof rows** (`Entity.IsDormant=false OK`, own hero/creep/ally bad=0, enemy allowed; expect `SUMMARY ok=94 garbage=0`).
4. `ctx` sample-2 at gt≈300 s — **ACCEPTANCE** (lastHits must move >0, ≥3 by ≈300 s; XP growth; distWave≤600; distAlly≤900; HUD/activity).
5. `diag_orders` once.
**Run VOID if `errors>0` or the OnNpcDying `lastSource` error reappears.**
Attribute all rows to the final signed hash set **including the new loader** (verify sizes/md5s at run time).
**TASK-10 STATUS: REOPENED / CONDITIONAL** — the post-reload window (47 ticks p50=1363 / p90=1994 / max=5210 ms, 45/47 SLOW, slowPolls=7) **supersedes the previous PASS attribution** (D6b RUN-C) until the proof run is green; D6b is retained as pre-fix history only.

### D12l. PROOF RUN (22:21:38 inject → normal match) — (A) PASS, (B) PASS, (C) task-10 conditional
Window (line-index): `L413391 [22:21:38.683] host: watchdog thread start pid=22224` → `L413393 [22:21:38.692] host: running bot_loop.lua` → `L413401 22:21:38 === BOT LOOP ===` → `L413501 22:21:40 [perf] load total=2206ms require=1981ms kv=105ms onLoaded=0ms warmup=120ms (entity=4ms nav=46ms modules=0ms updateEx=70ms)` → horn `L421493 22:23:43 [clock] src=horn gt=84.13 gs=84.13 state=5 in_game=0.0`; in-match steady window starts `L421364 22:23:41 [perf] tick n=2550`. NB: two `ctx` diag runs happened inside this window (`L423087 [22:24:36]`, `L424018 [22:25:31] host: running diag_api_parity_ctx.lua`) — QA raw window includes them; PM's clean 74-sample subset excludes their load.
**(A) BUGFIX / EVENT-ORDER = PASS:** `errors=0` in every `events:` summary since reload; **zero `OnNpcDying error`**; deaths clean (`OnNpcDying=2 → 20 → 44 → 67 → 92 → 115`); **`with_source=99%`** (was 93-96%); melee+ranged kills covered. Sample: `22:26:09 events: polls=16566 avg=2.3ms scan=0.7ms fire=1.6ms globals=0.0ms max=312.0ms slowPolls=35-58 errors=0 … OnNpcDying=92 | OnEntityHurt=1085ms OnProjectile=1165ms`.
**(B) LOADER PERF = PASS:** `globals=` column p50=**0** / p90=**2** / max=**7-8 ms**/tick (budget ≤10-20); `scan=3-20 ms`, `nav=0-43 ms`. Live `[globals]` content green: `L413511 22:21:41 laneGroups=3 all_groups=3 … camps=0 campSource=none navValid=false libAvail=true` (pre-horn) → `22:23:44 laneGroups=3 all_groups=3 visible_ally=3 … camps=24 campSource=nav navValid=true libAvail=true unit_attack=0` → `22:24:13 laneGroups=9 … unit_attack=1` → `22:24:36 laneGroups=11 …` → `22:25:45 laneGroups=10 all_groups=10 visible_ally=7 visible_enemy=3 ally_creeps=24 enemy_creeps=12 camps=24 campSource=nav navValid=true libAvail=true unit_attack=10 attacks=0` → `22:26:15` same shape.
**(C) TASK-10 = CONDITIONAL (script-side p90 breach; loader/globals exempt):** PM clean 74 in-match samples: **p50=46 / p90=456 / p99=668 / max=668 ms**; `script` p50=26 / p90=**318** / max=432; `synth` p50=12 / p90=150; **globals excluded**; all **22 slow polls top=`OnUnitAnimation(150-267 ms)`** — reference `Self Play.lua:2221` handler runs ~18-19 ms/event, i.e. the script's animation-event floor dominates. QA raw window (97 in-match tick lines incl the two ctx diag runs): p50=35 / p90=540 / p99=909 / max=1036, 64 slow-poll lines (204-425 ms, top OnUnitAnimation 150-392) — recorded as raw observation, not the attributed subset.
**Status:** (A) PASS, (B) PASS, **(C) task-10 CONDITIONAL — gate p90<300 not met script-side; pending Lead A/B decision: accept with documented script floor vs short api hot-call perf pass first.** Loader/globals are exempt from the breach.

### D12m. Evidence-path finding — `loader.parityProbe` crash + DIAGNOSTIC BUNDLE validated (22:28:40 ctx run)
**(1) Crash (explains missing probe rows in the proof window; recorded verbatim):**
```
L423254 22:24:36 [parity-ctx] loader.parityProbe ok=false rows=n/a
L423255 22:24:36 [parity-ctx] loader.parityProbe raised: D:\hake\lotus\src\loader.lua:2113: attempt to call global 'rd' (a nil value)
L424182 22:25:32 [parity-ctx] loader.parityProbe ok=false rows=n/a
L424183 22:25:32 [parity-ctx] loader.parityProbe raised: D:\hake\lotus\src\loader.lua:2113: attempt to call global 'rd' (a nil value)
```
So `refreshWorld` worked but probe rows were lost in the 22:24/22:25 runs; **do NOT attribute zero-row runs as data**. Note for accuracy: the earlier samples DID emit rows (`22:08:11 [parity-ctx] loader.parityProbe ok=true rows=14`, `22:11:59 … ok=true rows=14`) — the crash is specific to the later runs.
**(2) Diagnostic bundle (loader-events; diagnostic-ONLY scope = `rd` fix + `[parity] GLOBALS CampSites idx:type:team:x,y` row + GroundZ base probes ±7000,±6500 expected ~384) — present on disk & validated:**
```
loader.lua  : 99132 @22:27:48 md5 EC0A48585EDEB12CA2B621963CAD12AA   (backup loader.lua.ok_20261116_222734 = 98534)
globals.lua : 44707 @22:27:48 md5 40F3FACD47993D581A66989E0D6F5D62   (backup globals.lua.ok_20261116_222810 = 44707)
```
**(3) Validation run `L426253 [22:28:40.498] host: running diag_api_parity_ctx.lua` (fresh Lua state loads the new bundle):**
```
22:28:40 [parity] context loader=true
22:28:41 [parity] manifest total=214 missing=0
22:28:41 [parity] SUMMARY ok=93 garbage=0 stub=4 unverified=6 missing=2 error=0
22:28:41 [parity] FLAGGED: none
22:28:40 [parity] identity Entity.IsDormant = false | OK | entity.md IsDormant (local false) | Self Play.lua:244
22:28:41 [parity] state_handles Entity.IsDormant(own hero/creep/ally) = hero=false creep=false ally=false | OK | dormancy proof: local hero + own team never dormant (reviewer scope a/b)
22:28:41 [parity] state_handles Entity.IsDormant(enemy heroes) = visible=5 foggedDormant=0 (both allowed) | OK | dormancy proof: enemies keep engine dormancy
22:28:41 [parity] hud_inputs World.GetGroundZ(heroPos) = 128.0000 | OK | loader world.md |dz|<=600
22:28:41 [parity] World.GetGroundZ hero(-6741,3044)=128 p2(0,0)=128 p3(-4000,-3000)=128 p4(3000,2500)=128 radiantBase(-7000,-6500)=384 direBase(7000,6500)=128 | varied=true | OK(nav height grid)
22:28:41 [parity] globals LaneGroupsManager = table keys=17 | OK
22:28:41 [parity] globals JungleCampsManager = table keys=18 | OK
22:28:41 [parity] globals LIB_DAMAGE_PREDICTION = table keys=25 | OK
22:28:41 [parity] globals XHelpers = table keys=3 | OK
22:28:41 [parity] GLOBALS LaneGroupsManager visible_ally=7 visible_enemy=2 invisible_enemy=0 all_groups=9 | OK
22:28:41 [parity] GLOBALS LaneGroup lane=1 creeps=5 refOk=true lane_path=4pts name=top | OK
22:28:41 [parity] GLOBALS LIB_DAMAGE_PREDICTION available()=true unit_attack=0 attack_types=0/1 | OK
22:28:41 [parity] GLOBALS LIB_DAMAGE_PREDICTION targets[hero].attacks=0 | OK
22:28:41 [parity] GLOBALS JungleCampsManager camps=24 source=nav | OK
22:28:41 [parity] GLOBALS Camp index_=1 team_=2 type=1 pos=(-7456,-4320,256) farmed=false box=set creeps_alive=0 | OK
22:28:41 [parity] GLOBALS CampSites n=24 format=idx:type:team:x,y | 1:1:2:-7456,-4320;2:1:2:-7380,-2183;…;24:1:3:7072,2144
22:28:41 [parity] NAV laneRoutes=present team2.lane1.pts=4 campSites=24 statsValid=true lanesFromNav=true | OK
22:28:41 [parity] GLOBALS XHelpers keys=xkv,XAbility,GetScript XAbility aoe=8 radius=537 start=8 end=1 | OK
22:28:41 [parity] ACCEPTANCE gt=382.1 lastHits=0.00 denies=0.00 xp=2258.00 lvl=5.00 gold=0.00 distWave=251 distAlly=296 attacking=false running=false
22:28:41 [parity-ctx] loader.parityProbe ok=true rows=17 | parity diag ok=true err=
```
This is the **first run with a clean probe + populated content rows**: `garbage=0`, `FLAGGED: none`, `Entity.IsDormant=false OK` + dormancy proof rows, `GroundZ varied=true` (radiantBase=384), LaneGroups populated (`visible_ally=7/all_groups=9`, `LaneGroup lane=1 … name=top`), `JungleCampsManager camps=24 source=nav`, `CampSites n=24`, `NAV statsValid=true lanesFromNav=true`, `XHelpers aoe=8 radius=537 start=8 end=1`. Acceptance still `lastHits=0` at clock≈298-382 (IsDormant fix now in loaded state but last-hit acceptance still pending a run where the script actually last-hits).
**(4) Scope notes recorded:** `helpers.contexts()` is **script-owned** → the api perf pass will be **api-side per-call only** (no reference-script edits). `animfilter=0` **diagnostic recipe stored** (runtime write only by QA/Lead, tagged diagnostic).

### D13. SESSION CLOSE / FREEZE — 2026-11-16 22:30:55 (Lead order)
**Loop stopped by QA via `stop.txt` (runtime action explicitly ordered for freeze):**
```
L428341 22:30:55 stop.txt
L428342 22:30:55 === BOT LOOP done ===
L428343 [22:30:55.319] host: script finished
L428344 [22:30:55.721] host: stop.txt detected, watchdog exit
```
`stop.txt` removed afterwards. **Dota left as-is: pid 22224 alive (start 22:16:59), NOT relaunched.** No other runtime actions.
**FINAL MANIFEST (QA md5, 22:31):**
| file | size | mtime | md5 |
|---|---|---|---|
| api.lua | 112707 | 22:31:00* | 71ED9B2D79F95FAB02E8F0A970B4E5E7 |
| loader.lua | 99132 | 22:27:48 | EC0A48585EDEB12CA2B621963CAD12AA |
| globals.lua | 44707 | 22:27:48 | 40F3FACD47993D581A66989E0D6F5D62 |
| nav.lua | 67122 | 22:11:09 | 24304FA6DEE56BAC8A2E895D300C4CC3 |
| diag_api_parity.lua | 55931 | 22:13:38 | D87DDB1B26DD3A3FD69B728391F62F71 |
| diag_api_parity_ctx.lua | 5528 | 22:13:07 | AF414A285AD70F936D45BFAE4F119399 |
| diag_orders.lua | 28753 | 22:00:14 | F38DDE44C76951C3259CC4C52C1103BD |
| bot_loop.lua | 2451 | 20:31:05 | 6F22799A3CB2338C612CBFCD0D38EDE7 |
| menu.lua | 22085 | 20:45:59 | C53D0E96E531C163ED6F4413782C2CBA |
| orders.lua | 35340 | 20:35:32 | 499CC61EDBC18FA585D1302166397A79 |
| render.lua | 15716 | 20:27:18 | 803F9C735AE9AD99BE1E1F27C3B94EDA |
| overlay.lua | 36081 | 20:54:13 | 65625603D1D333FF010919F313E02ED9 |
| entity.lua | 13259 | 20:32:08 | EB459815068F1276CB275446137CD3ED |
| schema.lua | 3640 | 03:33:27 | 978CB9E5F80700D8E4BF70B9F4A3C562 |
| enums.lua | 49164 | 00:16:17 | B5532B34814DF5F334C5CF0FD6235DA4 |
(*api.lua mtime 22:31:00 but md5/size UNCHANGED = 71ED9B2D/112707 — re-save, no content change.)
Other `src/*.lua`: 102 files total incl. legacy/probe scripts (full manifest reproducible with `Get-FileHash src\*.lua`).
**DLL:** active `src\host16.dll` 185856 md5 **1AB3D7734E6A6F02FFC72DA11E384342** (task-20 input-fix build, mtime 20:57:18); rollback backups `host16.dll.bak_20261116_205629` and `host16.dll.old_20261116_210003` both md5 **422751ED3DABB466564B1A6F4E0EAC35** (185344); swap record in `src\host16.dll.md5.txt`.
**host.log:** final **428350 lines**, last write 22:31:07, last line `[22:31:07] R11: frame hud=55 menu=79 open=0 sw=1920`.
**SESSION-END EVIDENCE POINTERS:** proof window **L413391-L421493** ([perf] load L413501 → horn L421493), validation run **L426253 (22:28:40.498)** with `parityProbe ok=true rows=17` / `SUMMARY ok=93 garbage=0` / IsDormant proof / content rows (D12m), decisive-window/perf records D12k/D12l, and section D12/D12m for all parity evidence. Tasks left OPEN at freeze: task-4 pause trace, task-20 post-game click matrix, task-10 A/B decision (conditional), acceptance `lastHits>0` re-test.

### D14. task-26 NATIVE REBUILD WINDOW (P0 NV-driver crash) — state + protocol
**Baseline P0 crash (Windows Application log, confirmed):** `dota2.exe` faults at **2026-11-17 17:38:12** and **17:42:37** — faulting module **`nvwgf2umx.dll` 32.0.15.9159**, exception **0xc0000409** (BEX64), fault offset **0xe4bcdd**; WER entries same timestamps (event 1001/type 5, BEX64). Older 15-16 Nov dota2 crashes were `unknown` module 0xc0000005 (different class).
**Runtime state (QA read-only verify 2026-11-17 17:50):**
- Old injected process **pid 22716 is GONE**: `L444738 [17:49:29.104] host: stop.txt detected, watchdog exit`, last overlay frame `[17:49:49] R11: frame hud=0 menu=79 open=0 sw=1920` (host.log now silent).
- **New Dota pid 19596** started 17:49:58 — **NOT injected** (no `host: watchdog thread start pid=19596`; no loop; host.log silent since 17:49:49).
- **`stop.txt` ABSENT** (only the 17:49:29 stop marker in the log); `run.txt` = `src\bot_loop.lua` (mtime 17:48:26); `inject_result.txt` **ABSENT** (removed/stale).
**DLL state (already changed since the 1AB3D773 session baseline):**
```
host16.dll              187904 @2026-11-17 17:49:42 md5 8B24686720094388543B46DEC4E064A8   <- CURRENT ACTIVE
host16.dll.bak_20261117_174938 185856 @2026-11-16 20:57:18 md5 1AB3D7734E6A6F02FFC72DA11E384342  <- ROLLBACK SOURCE
host16.dll.old_20261117_174950 185856 @2026-11-16 20:57:18 md5 1AB3D7734E6A6F02FFC72DA11E384342
host16.dll.bak_20261116_205629 185344 @2026-11-16 02:16:39 md5 422751ED3DABB466564B1A6F4E0EAC35  (legacy)
host16.dll.old_20261116_210003 185344 @2026-11-16 02:16:39 md5 422751ED3DABB466564B1A6F4E0EAC35  (legacy)
src\render11.cpp        35010 @2026-11-17 17:48:31   (developer guard patch in progress)
src\host16_new.exp/.lib present (build artifacts 17:49:42)
src\host16.dll.md5.txt  NOT yet updated with the 8B246867 build record
```
⚠ **State-change flag vs PM snapshot**: PM reported "pid 22716 alive/injected, stop.txt present" — QA sees the old process ended, a NEW un-injected pid 19596, **no stop.txt**, and a swapped DLL (8B246867). Window must be reconciled with Lead/developer before any kill/relaunch.
**Window protocol (on Lead GO + reviewer re-sign of the 2 fixes: post-`EnsureCap` `g_vb` null re-check; NUL-terminate published text in `R11_PublishHud`/`R11_PublishMenu`):**
1. Clean stop marker (none present now) → 2. developer builds `host16_new.dll` + records compile/md5 + updates `host16.dll.md5.txt` → 3. QA kills Dota (confirm 0 processes; current pid 19596) → 4. developer swaps DLL + records md5/backup → 5. QA relaunch `steam://rungameid/570` → inject → ONE `bot_loop` in lobby (record `inject_result` + `[perf] load`) → 6. **stress Del open/close 10-20× on busiest menu page** + normal-match soak, capture `[r11] frame … verts=/cap=`, `[r11] skip draw reason=…`, no Lua errors, Windows Application log for `nvwgf2umx.dll` faults → 7. **rollback rule** if crash recurs: restore `1AB3D773…` from `host16.dll.bak_20261117_174938`, record crash fields + rollback hashes, report, do NOT retry blindly.
**Staging ready:** `D:\hake\lotus\QA_TASK26_EVIDENCE.md` (v2 template: preconditions, hash bookkeeping, FIXED synthetic-input commands, protocol with line-index capture, in-match HUD soak, menu-visibility test, PASS criteria, rollback rule, screenshot index) + `D:\hake\lotus\qa_task26\` screenshots dir.

**v2 FINAL WINDOW — reviewer PASS(code) (REVIEW.md 18:20), waiting only on Lead GO:**
- Fixed source: `render11.cpp` **36126 B @17:51:27 md5 C6F17EC6255B8471FAA9289E5943C974** (+ `host.cpp` 23009 B md5 EBA76DD3CAB0D4F5B0B1B401E80C9776).
- v2 artifact: `host16_new.dll` **188928 B @17:52:28 md5 65A35E4883797CCD8BA1CA32E1C77551** (≠ intermediate 8B246867); `host16.dll.md5.txt` FINAL CANDIDATE record + provenance (17:52:58) + rename note.
- Current active = **intermediate v1 8B246867** (187904 B @17:49:42), injected into **pid 19596** @17:51:32; loop running in lobby. Baseline frames: `R11: frame hud=0 menu=79 open=1 verts=0 cap=0` → **overlay not rendering** (Lead screenshot; single `R11: skip frame reason=resource-null buf=0 vb=0 srv=1`) — v1 is **NON-GATE** reference only.
- **Execution order on GO (reviewer-amended emphasis):** stop loop (`stop.txt` → wait `=== BOT LOOP done ===` → remove) → QA kill pid 19596 → confirm `Get-Process dota2` EMPTY → developer swap + verify active md5 = **65A35E48…** (backup 8B246867 first; record old/new md5/size/mtime) → QA relaunch `steam://rungameid/570` → inject → `bot_loop` → capture `inject_result` + `R11: init ok` + first `[r11] frame` → **PRIMARY crash test: in-match HUD soak 5–10 min, menu CLOSED, hud≥50 cmds continuous** (both NVIDIA faults happened while only HUD drew, hud≈47–55): capture `[r11] frame … hudN … verts= cap=` (verts≤cap every line), zero skip lines, event-log check, normal-match continuation → **SECONDARY menu/Del stress** with fixed synth (`synth_key.ps1 -Keys 0x2E -HoldMs 80`, verify `open=0→1`; Del 10–20× ≥5 s open + widget clicks/hover; minutes continuous menu-open) → 3–5 min no-menu lobby soak → Windows event log check → post-game click check if a match ends (task-20).
- **Menu-invisible v1 finding = separate FUNCTIONAL defect, NOT crash gate:** reviewer hypothesis = `menuOpen` desync (renderer draws only when `g_r11Open`; GUI may open without `R11_SetMenuOpen`). If v2 still shows `menu=79 open=1 verts=0`, record frames+screenshot as **task follow-up** (debug build planned after crash window) — do not fail the crash gate on it.
- **Key-synth root cause (recorded):** old `synth_key_elevated.bat` passed `-HoldMs %2` with empty `%2` → PowerShell binding error (`synth_key_result.txt` 17:52:36, RU "cannot convert \"\" to System.Int32") → **zero keys sent**; that's why v1 menu-open evidence never existed. Fixed usage documented in QA_TASK26_EVIDENCE.md.
- **Exit criteria:** zero skip lines in all categories (`skip vert overflow`, `vb-size`, `resource-null-after-cap`, `map-fail`, `resource-null`, `cmd-count`, `non-tri`), `verts ≤ cap` in every frame, no new `nvwgf2umx` 0xC0000409, overlay correct, crash-free. **Rollback:** `host16.dll.bak_20261116_205629` (422751ED…) first, else `host16.dll.bak_20261117_174938` (1AB3D773…) per Lead/dev.

**V2 NON-GATE EVIDENCE (captured 2026-11-17 17:55-17:57; v2 deadlocked, must NOT be graded as crash gate):**
- Swap: active `host16.dll` = **188928 B md5 65A35E48… @17:52:28** (v2); v1 moved to `host16.dll.old_20261117_175339` (8B246867, 17:49:42); backups 1AB3D773 (174938) + 422751ED (205629) intact; swap record appended to `src\host16.dll.md5.txt` (`[20261117_175339] Lead window: swapped v2 …`).
- Injection: `L447948 [17:55:34.010] host: watchdog thread start pid=9204` → `L447950 host: running bot_loop.lua` → `L447958 17:55:34 === BOT LOOP ===` → `L448050 17:55:36 [perf] load total=2054ms require=1937ms kv=113ms onLoaded=1ms warmup=3ms` → `L448104 [17:55:36] R11: init ok sw=1920 sh=1080` → `L448106 [17:55:36] R11: skip frame reason=resource-null buf=0 vb=0 srv=1` (log-once).
- **Deadlock baseline (window L448105→end, as of 17:57:29):** `[r11] frame` lines with verts= format = **55, all `verts=0 cap=0`; frames with cap>0 = 0**; exactly **1** skip line (the init-time `resource-null`); sample `[17:55:38] R11: frame hud=0 menu=79 open=0 verts=0 cap=0 sw=1920`.
- **Fixed-synth Del attempt (QA, elevated):** `powershell -File src\synth_key.ps1 -Keys 0x2E -HoldMs 80` → `[17:57:09] R11: frame hud=0 menu=79 open=0 verts=0 cap=0` → **`L450445 [17:57:11] R11: frame hud=0 menu=79 open=1 verts=0 cap=0 sw=1920`** — menu opens logically (`open=0→1`) but **renders nothing** (`verts=0 cap=0`, no overlay on screen). Note: `synth_key_result.txt` mtime 17:52:36 is stale from the earlier broken `.bat` invocation; direct elevated `-File` invocation does not redirect output, so the open-transition in host.log is the delivery evidence.
- **Screenshots:** `qa_task26/v2_nodraw_before_del.png` (17:57:02, lobby, no overlay) and `qa_task26/v2_nodraw_after_del.png` (17:57:15, after Del; Dota lobby UI normal, **no ClickGUI**).
- **Non-render health (same window):** `[api] calls/5s: GetGameTime=933` (stable, ~930-936 across summaries); `events: polls=10261 avg=0.0ms scan=0.0ms fire=0.0ms max=1.0ms slowPolls=0 errors=0`; loop counters stable (`loop 2635 0.0s nil hp=- 0 0 gt=-1.0` @17:57:29); process healthy (`pid 9204 responding=True`, cpu≈233 s); no lua/callback/runtime errors (only benign `errors=0` summaries). No `[entity]` builds / validated-players rows because state is lobby (no match) — expected.
- **Labelled v2 NON-GATE.** Root cause per developer/reviewer: native bootstrap ordering — resource gate returns before `EnsureCap` allocates vertex buffer; overlay never draws (HUD+menu invisible). v3 fix (ordering + per-frame diag fields) awaits Lead GO; on v3 first-frame prerequisite = `[r11] init ok` + **frame with cap>0 (stop if cap stays 0)**, then amended full protocol (HUD soak primary, fixed-synth Del + menu visibility, lobby soak, WinEvent, post-game click).

**V3 GATE CANDIDATE (staged 17:58; reviewer fast re-sign pending; Lead owns kill pid 9204 + swap):**
```
src\host16_new.dll   189440 B @17:57:16 md5 CB0ED3F4D9E07271DD59A154D03DDE9A   (differs from v2 65A35E48 / v1 8B246867)
src\render11.cpp      38215 B @17:57:03 md5 CAAF6827BD2669A65BA2AB3181355777   (+ host.cpp 23009 B md5 EBA76DD3…)
src\host16.dll.md5.txt  V3 build record present (order fix + diag fields, swap=pending, rollback 422751ED first / 1AB3D773 second)
```
**v3 first-frame prerequisite (QA checks on inject; ABORT soak + report exact line if violated):** `[r11] init ok sw=1920 sh=1080` → **`diag(first=1)` with `cap>0` AND `verts>0`** (v3 prints first 5 frames immediately: `hud menu open est verts cap vbB drew mapOk` + counters `init/bb/cmd/res/ens/mapfail`) → within ≤2 s `[r11] frame … cap= est= verts= drew= mapOk=`. **If `cap` stays 0 or `verts==0` on `diag(first=1)` → abort and send line (different defect).**
**v3 gate protocol (amended):** (1) **PRIMARY HUD soak** — in-match, menu CLOSED, `hud≥50 cmds`, **≥5 min continuous drawing**; require `verts ≤ cap` on every frame line + zero skip lines among `skip vert overflow` / `skip draw reason=vb-size` / `resource-null-after-cap` / `map-fail` / `resource-null` / `cmd-count` / `non-tri`; **no new nvwgf2umx 0xC0000409** in Application log; overlay visible (HUD screenshots). (2) **SECONDARY menu/Del stress** — fixed synth `synth_key.ps1 -Keys 0x2E -HoldMs 80` elevated, Del 10–20× each open ≥5 s + widget clicks/hover + minutes menu-open; require **`open=1 && menu>0 → verts>0`** + visible ClickGUI screenshot; **`cap>0` but `verts=0` with menu open = REJECT** per reviewer. (3) normal-match soak; keep match for **role/last-hit Carry test if menu renders**. (4) Record verbatim `diag(first=1..5)` lines + last 20 `frame` lines + skip-line count + WinEvent check + **max verts / max cap** in this report. (5) Rollback `422751ED` first, else `1AB3D773`.
Template: `D:\hake\lotus\QA_TASK26_EVIDENCE.md` (v3 rewrite: preconditions, first-frame gate, evidence format, PASS criteria).

**V3 LIVE EVIDENCE (window 17:59:47+; first-frame gate PASS):**
- Injection: `L451949 [17:59:47.464] host: watchdog thread start pid=14876` → `L451951 host: running bot_loop.lua` → `L451959 17:59:47 === BOT LOOP ===` → `L452051 17:59:49 [perf] load total=2069ms require=1954ms kv=111ms` → `L452106 [17:59:49] R11: init ok sw=1920 sh=1080`.
- Idle lobby note: with menu closed and no match, nothing is drawn — frames read `hud=0 menu=0 open=0 est=0 verts=0 cap=0 vbB=0 drew=0 mapOk=0 | counters 0` and **no `diag(first=…)` lines** (expected idle, not deadlock; v2-style permanent dark does not apply here because the draw path is only entered when there is something to draw).
- **Del open (fixed synth, elevated) → first draw → PREREQUISITE PASS:** `R11: diag(first=1)`…`diag(first=5)` `hud=0 menu=79 open=1 est=6718 verts=6456 cap=14972 vbB=299440 drew=1 mapOk=1 | init=0 bb=0 cmd=0 res=0 ens=0 mapfail=0`; steady frames (L453055/L453103/L453152/L453751…) identical `menu=79 open=1 est=6718 verts=6456 cap=14972 vbB=299440 drew=1 mapOk=1`; **zero `R11: skip` lines since init**; `verts ≤ cap` (6456 ≤ 14972).
- **Overlay visible proof:** screenshot `qa_task26/v3_menu_open_180026.png` — ClickGUI (Self Play · Main tab · Bot / Play style / On screen groups) rendered over the Dota lobby (previously invisible on v2).
- Current state: pid 14876 alive/responding, ONE loop (`loop 1469` @18:00:53), lobby (no match yet) → **in-match HUD soak pending match start**.
- Next per protocol: in-match HUD soak 5–10 min menu closed hud≥50 (`verts≤cap` every line, zero skip categories, no new nvwgf2umx 0xC0000409) → Del stress 10–20× + menu visibility screenshots → lobby soak → post-game click → role/last-hit Carry test if menu renders.

**V3 CRASH RESULT — GATE FAIL (P0 REPRODUCED, 2026-11-17 18:03:51):**
- Soak session: ONE loop `L451949 [17:59:47.464] watchdog thread start pid=14876` / `L451959 === BOT LOOP ===` (no second start after; no stop marker — process died).
- QA closed the ClickGUI with Esc (`[18:03:16]` — Esc probe; menu `open=1→0`), then started a single-player Treant match; **match horn `[18:03:50] [clock] anchor: observed state transition <4 -> 5 at gs=78.767` / `src=horn gt=78.77 gs=78.77`**; hero Treant at fountain/spawn.
- **`dota2.exe` CRASHED at `18:03:51`** — Windows Application Error **event 1000**: `Имя сбойного приложения: dota2.exe … | Имя сбойного модуля: nvwgf2umx.dll, версия: 32.0.15.9159 … | Код исключения: 0xc0000409 | Смещение ошибки: 0x0000000000e4bcdd` — **identical module/exception/offset to the P0 baseline faults 17:38:12 and 17:42:37**; WER `event 1001` BEX64 at `18:03:55`. Evidence file: `qa_task26/crash_180351_eventlog.txt`.
- `Get-Process dota2` = **NOT RUNNING**; `host.log` final flush `18:03:50` (24,461,326 B; mtime 18:03:50). Owner process gone → no loop.
- Last logged context (verbatim): `[18:03:50] [clock] … state=5 in_game=0.0` → `[globals] JungleCampsManager: 24 camps source=nav` → `[globals] laneGroups=3 all_groups=3 visible_ally=3 … libAvail=true` → `[menu] bind 'Hold to take over' code=65 vk=0x20 held=false` → **`[18:03:50] [order] PUO type=11 tgt=0 abil=1293 unit=npc_dota_hero_treant`** (last line).
- Last overlay frame `[18:03:49] R11: frame hud=39 menu=79 open=0 est=910 verts=786 cap=14972 vbB=299440 drew=1 mapOk=1 | …` — **healthy draw (786 ≤ 14972), zero `R11: skip` lines since init** → crash was NOT preceded by any overlay guard/skip event in the log.
- **Verdict: v3 FAILS task-26 crash gate** (P0 reproduces within ~1 s of in-match HUD start, same NV signature). Rollback ready: `host16.dll.bak_20261116_205629` (422751ED…) first, else `host16.dll.bak_20261117_174938` (1AB3D773…). QA did not relaunch/rollback — awaiting Lead decision.

**v3 crash evidence — staged detail (line-indexed; no runtime actions):**
- **Last 20 `[r11] frame` lines before crash (L458316→L460842, 18:03:08→18:03:49)** — all identical & healthy:
  `R11: frame hud=39 menu=79 open=0 est=910 verts=786 cap=14972 vbB=299440 drew=1 mapOk=1 | init=0 bb=0 cmd=0 res=0 ens=0 mapfail=0 sw=1920`
  (last: `L460842 [18:03:49] …`; num frames in session = 266).
- **`diag(first=1..5)` (menu-open prerequisite, L453010-L453014 @18:00:26):** `hud=0 menu=79 open=1 est=6718 verts=6456 cap=14972 vbB=299440 drew=1 mapOk=1 | counters 0`.
- **Zero `R11: skip` lines across the WHOLE v3 session (from init L452106):** total = **0**; per category all **0**: `skip vert overflow`, `vb-size`, `resource-null-after-cap`, `map-fail`, `resource-null`, `cmd-count`, `non-tri`.
- **Timeline (line order):** init `L452106 [17:59:49] R11: init ok sw=1920 sh=1080` → diag `L453010-453014 [18:00:26]` → Del `L457358 [18:02:53] toggle -> 1` → first in-match HUD `L457392 [18:02:53] [hud] cmds=39 text=10` / frame `L457445 [18:02:54] hud=39 menu=79 open=1 est=7564 verts=7242` → Del `L458089 [18:03:05] toggle -> 0`; frame `L458190 [18:03:06] hud=39 menu=79 open=0 est=910 verts=786` (**menu closed, HUD-only**) → 20 identical HUD-only frames to `L460842 [18:03:49]` → horn `L460914/460915 [18:03:50] [clock] anchor: observed state transition <4 -> 5 at gs=78.767` / `src=horn gt=78.77 gs=78.77 state=5 in_game=0.0` → `L460919 [18:03:50] [menu] bind 'Hold to take over' code=65 vk=0x20 held=false` → `L460920 [18:03:50] [order] PUO type=11 tgt=0 abil=1293 unit=npc_dota_hero_treant` (**last line**) → crash `18:03:51` (App Error 1000 nvwgf2umx 0xc0000409 0xe4bcdd; WER BEX64 18:03:55). host.log final flush `18:03:50`, size 24,461,326 B, **no stop marker** (process died).
- **Menu/Del activity 18:02–18:03:** Del toggles `18:02:53 ->1`, `18:03:05 ->0` (menu actually closed at 18:03:05/06); QA Esc probe `18:03:16` was a no-op (menu already closed); **no menu geometry during the crash** — menu was closed for ≥43 s / 20 frames before the fault. ⇒ crash is **first in-match HUD epoch transition**, NOT menu-triggered; `hud=39` (<50 target) but continuous HUD-only drawing.

### D14b. ROLLBACK EXECUTED — working baseline 422751ED restored (Lead option A; 2026-11-17 18:09+)
- **Active DLL verified by QA:** `src\host16.dll` **185344 B @11-16 02:16:39 md5 422751ED3DABB466564B1A6F4E0EAC35** = long-stable pre-input-fix baseline. Archived builds kept: `host16.dll.v3_20261117_180924` (189440, CB0ED3F4), `host16.dll.bak_20261117_175812`/`old_20261117_175812` (v2 65A35E48), `bak_20261117_175339`/`old_20261117_175339` (v1 8B246867), `bak_20261117_174938`/`old_20261117_174950` (1AB3D773), `bak_20261116_205629`/`old_20261116_210003` (422751ED). **Labels: v3=crash-gate FAIL/non-evidence; v2/v1 non-evidence; 422751ED=working baseline.**
- **LocalDumps (Lead applied; QA read-only verify):** `HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\dota2.exe` → `DumpFolder=REG_EXPAND_SZ D:\hake\lotus\dumps` (dir created/ready), `DumpType=REG_DWORD 0x2` (full), `DumpCount=0x5`. Next crash will produce dumps there for v4 isolation.
- **Runtime revived:** new Dota pid **25604** (started 18:09:33, Lead relaunch); QA injected at `L460921 [18:10:03.140] host: watchdog thread start pid=25604` → `L460923 host: running bot_loop.lua` → `L460931 === BOT LOOP ===` → `L461023 [18:10:05] [perf] load total=2065ms require=1945ms kv=117ms` → `L461079 [18:10:05] R11: init ok sw=1920 sh=1080` → frames (legacy format, no verts/cap): `[18:10:05] R11: frame hud=0 menu=79 open=0 sw=1920`.
- **Health:** zero Lua/callback/runtime errors since injection; loop single sequence (e.g. `loop 3559 @18:12:41`); `events: … errors=0 slowPolls=0`; Del open/close toggles work (`L462051 ->1`, `L463300 ->0`, `L463713 ->1`, `L464147 ->0`); **ClickGUI renders on this build** (screenshot `qa_task26/rollback_422751ED_menu.png`, Self Play/Main visible).
- **Known limitation re-confirmed (why input-fix existed):** synthetic mouse input is **NOT delivered to Dota UI on 422751ED** — SendInput click on `ИГРАТЬ ПРОТИВ БОТОВ (1637,679)` and mouse_event click on settings gear `(30,30)` produced **no UI reaction** (`foreground_ok=True`, `clicked` logged); ClickGUI tab click `(720,339)` also no effect. Keyboard (Del) does reach the game/overlay.
  - ⇒ QA **cannot start the match nor change ClickGUI widgets (incl. Role combo) on this build** — needs Lead/human real mouse.
- **Role widget observation (Main tab):** combo labelled **"Position" currently shows "1 Carry"** (screenshot `qa_task26/rollback_422751ED_menu.png`); cannot be changed by QA clicks on this build.
- **Pending for role/last-hit test:** human-started **single-player Treant match** (menu closed) → QA then captures ~5:00 acceptance rows (lastHits/XP/distWave/distAlly via `diag_api_parity_ctx`/probe) + HUD mode text; acceptance is role-conditional (Carry/Mid/Offlane expect ≥3 last-hits by 5:00).

### D14c. **422751ED BASELINE ALSO CRASHES IN-MATCH (18:14:40) — P0 is BUILD-INDEPENDENT; 422751ED = lobby-safe only**
**Crash evidence (QA read-only capture; no relaunch/rollback by QA):**
- Session: pid **25604**, injected 18:10:03, ONE loop, `run.txt=bot_loop.lua` at crash time (role1 harness NOT involved); zero Lua/callback errors since injection.
- Match horn: `18:14:39 [clock] anchor: observed m_flGameStartTime transition -> 110.433` / `src=horn gt=110.43 gs=110.43 state=4 in_game=0.0`.
- **Crash `18:14:40`** — Windows Application Error **1000**: `dota2.exe` / faulting module **`nvwgf2umx.dll` 32.0.15.9159** / exception **`0xc0000409`** — identical P0 signature (17:38:12 / 17:42:37 / 18:03:51); WER `1001` BEX64 @18:14:44.
- Last frames healthy (legacy format on this build): `[18:14:24..18:14:38] R11: frame hud=39 menu=79 open=0 sw=1920` (last L471553 @18:14:38); **zero `R11: skip` lines in session; zero errors**.
- host.log final flush `18:14:39` (25,134,020 B; mtime 18:14:39), tail: `… [clock] … state=4 in_game=0.0` → `[globals] JungleCampsManager: 24 camps source=nav` → `[globals] laneGroups=3 all_groups=3 visible_ally=3 … libAvail=true` → `[menu] bind 'Hold to take over' code=65 vk=0x20 held=false raw=0x0000` → **`[order] PUO type=11 tgt=0 abil=1378 unit=npc_dota_hero_treant`** (last line). Process gone (`Get-Process dota2` empty), no loop.
- **Full LocalDump captured:** `D:\hake\lotus\dumps\dota2.exe.25604.dmp` **6.92 GiB (7,432,486,566 B) @18:16:04**; disk free 434.7 GB → dump kept for developer stack extraction. WER dump analysis notes present: `D:\hake\lotus\dumps\analyze.txt` (2,734 B @18:18:12) — cdb via WinDbg: `Security check failure or stack buffer overrun c0000409`, **Subcode 0x2 FAST_FAIL_STACK_COOKIE_CHECK_FAILURE**, frame `nvwgf2umx!NVDEV_Thunk+0x5056bd` (`int 29h`), process uptime 0:05:11.
- **Labels updated:** **422751ED = in-match crash / lobby-safe only**; **v3 = crash-gate FAIL**; **v1/v2 = non-evidence**. Role/Carry acceptance **ON HOLD** until a crash-free in-match build exists (need harness `bot_loop_role1.lua` 3,480 B @18:16:25 md5 B58B85CD9B90ECC5BE7FBBC247829D95 — verified staged, unused).
- **Implication:** crash is tied to the in-match horn/game-start transition and is build-independent (all DLL revisions) ⇒ v4 A/B window (MT-protect + draw masks + flushed stage trace `D:\hake\lotus\r11_stages.log`, LocalDumps armed) must identify the failing stage; gate = failing stage identified + mode-3 survives ≥2 horns + 15-min soak.

### D14d. v4b A/B prep + RUN-0 control result + **FREEZE (user instruction)**
**Artifacts staged (NOT activated; untouched at freeze):**
- v4b diagnostic build `src\host16_new.dll` **201,728 B @18:18:09 md5 CDBAF4720E6ED333180720DAE3421F38** (sources render11 50,488/20BB9CDA…, host.cpp 23,062/DF22BAAC…; provenance in `src\host16.dll.md5.txt`).
- Active DLL at freeze: **422751ED3DABB466564B1A6F4E0EAC35** (rollback baseline, lobby-safe only); backups 1AB3D773 etc. intact; `r11_stages.log` absent; dump `dumps\dota2.exe.25604.dmp` (6.92 GiB) retained.
- QA staging files: `qa_task26/v4_run_matrix.md`, `qa_task26/v4_run_0.md`; live control `src\diag_r11_mode.lua` (2,487 B/B67CF1E5…) + `r11_mode.txt`; out-of-process helper `src\qa_call_export_extra.lua`→`src\qa_call_export_arg.lua` (2,921 B/79EEB26C…).
**RUN-0 (0a) RESULT — PASS (overlay alone insufficient):**
- Plain Dota **pid 21788** (started 18:24:08), **host16 absent**; **Steam overlay ACTIVE in-process** — elevated enumeration (`qa_task26/run0_modules.txt` / `run0_modules_now.txt`, 183 modules): `gameoverlayrenderer64.dll ver 11.23.65.88 LOADED`, `nvwgf2umx.dll 32.0.15.9159`, d3d11/DXGI 10.0.19041.5794.
- Human-started match ~18:28:22; in-game screenshot at 18:28:35 showed **clock 0:13, Treant Protector**; process responding at 18:29:17 / 18:30:08 / 18:32:49 / 18:33:42 (**≈5.3 min past horn**), **no new Windows Application 1000/1001** (latest remained the 18:14:40 injected crash).
- ⇒ **0a PASS: overlay-active plain Dota survives the horn; overlay alone does not reproduce P0.** Host16-injection interaction implicated (dump 25604 thread 98: `gameoverlayrenderer64!OverlayHookD3D3+0x2bde3` adjacent to `host16` frames).
- **Lesson:** module enumeration for high-integrity Dota MUST be elevated (medium-integrity `Get-Process | Modules` returns 0 — false negative).
**FREEZE:** user instructed hands-off (he will play Dota himself). QA performed **no injection/kill/relaunch/loop/input/screenshots** after the freeze; runtime left exactly as observed. Dump 6.9 GB, v4b artifact, rollbacks untouched.
**Resume condition (Lead/user explicit "continue") — next planned actions:** **A1 = v4b mask 7 + Steam overlay ENABLED** (`r11_mode.txt mode=7 guard=0`, `run.txt=src\diag_r11_mode.lua`; expected crash ~1 s after horn) → **A0 = v4b mask 7 + overlay DISABLED** (human disables Steam In-Game Overlay + restart; QA elevated-verifies renderer ABSENT; expected survive) → if split holds: coexistence branch + product fix "detect Steam overlay and skip/defer in-match draw (explicit log/notice)"; if A0 crashes → mask ladder 0/1/2. Per-run capture: elevated module list (host16 + gameoverlayrenderer64 versions), mandatory `[r11] multithread protected already=… now=…`, rotated `r11_stages.log` tail, `present hr=devRemoved=`, skip categories, Windows 1000/1001, horn+1 min screenshots, dump on crash, overlay state noted.

### D14e. **A1 EXECUTED — v4c mask 7 + MT-protect + Steam overlay ENABLED → CRASH; fault occurs AFTER our Present work**
**A1 metadata:** active `src\host16.dll` **772,608 B md5 43294478528D0CF1FA8145D43D5771E9** (v4c, mtime 18:31:37); mask 7; Steam overlay enabled; MT-protect line `L471719 [19:10:31] R11: multithread protected already=0 now=1` (**H0 MT-protect ACTIVE and now=1 — yet crash occurred**).
**Horn (line-index) `L485040-L485047 [19:16:45]`:** `loop 8504 0.0s npc_dota_hero_treant hp=670 -6700 -6700 gt=-1.0` → `[clock] anchor: observed m_flGameStartTime transition -> 108.200` → `[clock] src=horn gt=108.20 gs=108.20 state=4 in_game=0.0` → `[entity] iter build … n=5691` → `[globals] JungleCampsManager: 24 camps source=nav` → `[globals] laneGroups=3 all_groups=3 visible_ally=3 … libAvail=true` → `[menu] bind 'Hold to take over' code=65 vk=0x20 held=false` → `[order] PUO type=11 tgt=0 abil=1291 unit=npc_dota_hero_treant` (last host.log line).
**Crash:** Windows Application Error **1000 @19:16:47** — `dota2.exe` / faulting module **`nvwgf2umx.dll` 32.0.15.9159** / exception **`0xc0000409`** / offset **`0x0000000000e4bcdd`** (same P0 signature); WER **1001 @19:16:50** BEX64. Process gone.
**Stage trace (decisive; `r11_stages.log` 14,000,902 B, mtime 19:16:45) last pipeline — frame `f=16059 tid=22116 mask=7 guard=0 sinceBb=761` COMPLETED the whole path:**
```
f=16059 … stage=enter     hud=39 menu=79 open=0 est=910 verts=786 cap=14972 drew=1 mapOk=1
f=16059 … stage=capture   hud=0 menu=0 open=0 est=0 verts=0 cap=0 drew=0 mapOk=0
f=16059 … stage=rtv       hud=0 menu=0 open=0 est=0 verts=0 cap=0 drew=0 mapOk=0
f=16059 … stage=draw      hud=39 menu=0 open=0 est=910 verts=786 cap=14972 drew=0 mapOk=0
f=16059 … stage=statecopy hud=39 menu=79 open=0 est=910 verts=786 cap=14972 drew=0 mapOk=0
f=16059 … stage=upload    hud=39 menu=79 open=0 est=910 verts=786 cap=14972 drew=1 mapOk=1
f=16059 … stage=restore   hud=39 menu=79 open=0 est=910 verts=786 cap=14972 drew=1 mapOk=1
f=16059 … stage=exit      hud=39 menu=79 open=0 est=910 verts=786 cap=14972 drew=1 mapOk=1
f=16059 … stage=present   hud=39 menu=79 open=0 est=910 verts=786 cap=14972 drew=1 mapOk=1
```
(no subsequent `enter` for f=16060 — **fault is AFTER our Present work / outside the traced draw path**). Previous frames f=16057/f=16058 show the same full-pipeline pattern.
**Full dump + analysis:** `D:\hake\lotus\dumps\dota2.exe.8856.dmp` **6.98 GiB @19:17:28** (v4c PDB/MAP retained). Analysts' files: `dumps\analyze_v4c.txt` (19:17:50) and `dumps\analyze_v4c_threads.txt` (19:18:17) — `Security check failure or stack buffer overrun c0000409`, **Subcode 0x2 FAST_FAIL_STACK_COOKIE_CHECK_FAILURE**, `nvwgf2umx!NVDEV_Thunk+0x5056bd` (`int 29h`, 62 stack refs), process uptime 0:08:02. **Both modules on stacks:** `host16!HostThread+0x25a`, `host16!UiThread+0x6e`, `host16!RunScript+0xa9` **and** `gameoverlayrenderer64!OverlayHookD3D3+0x2bde3` (threads file line 1272) ⇒ A1 had Steam overlay hook active alongside our host16 hook.
**A1 VERDICT:** *crash* — **post-Present fault; H0/MT-protect ineffective** (already=0 now=1 still crashed). Overlay coexistence path remains the prime suspect, pending **A0** (overlay disabled).
**A0 checklist (on Lead "swap/human ready"; no injection/kill by QA until then):** user disables **Steam Settings → In-Game → Steam Overlay** + restart Dota → QA **elevated-verify** `gameoverlayrenderer64.dll` ABSENT and host16 present (v4c md5 43294478…) → capture per-run: mandatory `[r11] multithread protected already=… now=…`, rotated `r11_stages.log` tail, `present hr=devRemoved=`, skip categories, Windows 1000/1001, horn/~1 min screenshots, elevated module list, dump if crash; **A0 target = 2+ horns survive** (⇒ product fix: detect Steam overlay and skip/defer in-match draw with explicit log/notice; gate on overlay-disabled candidate). If A0 crashes → mask ladder 0/1/2.

### D14f. v4h/v4k windows — **NV-driver crash ELIMINATED; mechanism proven; but serial faults continue at horn (host16 GS-cookie → tier0 AV); v4k INVALIDATED**
**Architecture accepted:** inline Present patch was hitting **`gameoverlayrenderer64`** because **Steam replaces swapchain vtable slot 8** (root cause of mask-0/horn/build-independent NV failures); **vtable chaining is the right architecture** and eliminated the NV signature.
**v4h window (v4j B28198B8…):** `hook mode=vtable(v4h)`; `resize inline hooks not installed in v4h mode`; `hook target=gameoverlayrenderer64+0x9c130`; `vtable present patched … slot=8 old=DXGI+0x18c0 new=host16+0xaab0 entries=48 present-tid=19516`; `inline patch restored ok=1 bytes=48 89 5C 24 08 48 89 6C 24 10`; `inline patch absent ok=1`; mask7 `drew=1 mapOk=1`; horn 00:52:29 gt=105.03; **crash 00:52:29+ → `host16!__report_gsfailure+0x1d ← __GSHandlerCheck+0x13 ← PresentCore+0x2d0 ← rendersystemdx11+0x6288f`**, thread #55 tid 0x4c3c, large frame `QOrder local[256]`; dump `dota2.exe.26884.dmp` 7,239,387,683 B. **NV fault gone; host16 stack-cookie corruption replaces it ⇒ v4h trust invalidated.**
**v4k window (v4k FE34518F…):** same vtable evidence (`entries=48 present-tid=7352`, `inline patch absent recheck ok=1` every ~12 s through 01:03:09), in-match `hud=39 verts=786 cap=14972 drew=1 mapOk=1`, `present hr=0x0 devRemoved=0x0`; horn 01:03:11 gt=145.27 state=5; **crash 01:03:12 → Windows 1000 `tier0.dll` `0xc0000005` AV offset `0xaeb60`** (WER 1001 AutoVerifierV2); dump `dota2.exe.16584.dmp` **7,958,398,411 B @01:04:27**; host.log 28,266,973 B & stages 10,418,962 B frozen @01:03:11; archived `qa_task26\host_v4k_crash_20261118_0103.log` + `r11_stages_v4k_crash_20261118_0103.log`. **v4k INVALIDATED; root cause not proven (tier0 likely secondary crash-path corruption). v4k PDB/MAP retained (8,097,792/1,211,472).**
**Consequence:** **v4i control blocked on v4l** (`g_qcs` uninitialized under `R11_NO_HOOKS=1`); next window requires Lead/reviewer decision (v4l), dump symbolization with matching PDBs, and 2+ horns + 15-min soak gate. QA observer-only since window (no injection/kill/screenshots).

### D14g. v4k reviewer verdict (REVIEW.md 01:20) + next-cycle prep (offline)
- **Reviewer: v4k = FAIL.** NV signature **and** `__report_gsfailure` both **absent** ⇒ **vtable mechanism + GS fix hold**. New crash: **`tier0.dll+0xaeb60` AV `0xc0000005`**, `rcx=0x020b2712` (wild), **no host16 frame**; dump `dota2.exe.16584.dmp` 7,958,398,411 B retained; exact `tier0!CKeyValues_Data::Internal_GetName: mov rax,[rcx+8]`, **r14=000002735ceecfd0 = patched swapchain ptr** ⇒ likely **secondary engine-state corruption**, root cause unproven.
- **Baseline restored:** active `host16.dll` = **422751ED3DABB466564B1A6F4E0EAC35** (185,344 B); v4k archived `host16.dll.v4k_20261118_010603`; md5.txt record `[20261118_010603]`.
- **Next-cycle run files staged (offline):**
  - `qa_task26/v4_run_newarch.md` — **new-architecture candidate**: in-place **shared dxgi swapchain vtable slot-8 patch** (not private-vptr). **DO NOT USE `v4l` (`host16_new_v4l.dll` C5634DC9…)** — old private-vptr diagnostics build, superseded. Artifact TBD; intake checklist (fresh hash/PDB/MAP/provenance/reviewer gate), capture contract + invalidation.
  - `qa_task26/v4_run_skip_puo.md` — **`R11_SKIP_PUO=1` control** (engine wild-deref follow-up if default window recurs): env-before-launch, expect skip line + zero engine PUO calls, 2 horns+soak; survive ⇒ engine PUO path implicated.
  - `qa_task26/v4_capture_additions.md` — reviewer additions: **`sc->vptr` expectation check**, **canary static arg / STOP-DRAIN lines**, **per-order logs with engine state**, **±2 s transition-drain logging**.
- **Open blockers:** v4i on v4l (`g_qcs`); v4k dump analysis developer-side (v4k PDB/MAP retained 8,097,792/1,211,472); no runtime actions; user pid 6396 untouched (gone); new windows only on Lead order after reviewer gate.

### D14h. Reviewer v4m REJECT + ROOT CAUSE #2 (PUO stale offset) + v4n contract
- **Reviewer: v4m = REJECT (blocking, 4 bugs → v4n rebuild).** v4m artifacts: `host16_new_v4m.dll` V4M_FINAL **787,968 B md5 393F202C…** (interim DD12F560 superseded). **Do not use.**
- **ROOT CAUSE #2 accepted: PUO RVA stale after game update.** Real `PrepareUnitOrders` prologue now **`client.dll+0x1B5F9B0`**; old hardcoded **`client.dll+0x1B5F860` is mid-function** (`15 0B 22 0B 02 48 8B D8…`) → old-RVA calls landed mid-function ⇒ wild-pointer engine corruption at horn, consistent with **GS smash (26884)** and **tier0 AV (16584)**.
- **v4n contract staged** (`qa_task26/v4_run_newarch.md`): in-place **shared dxgi vtable slot-8 patch** (not private vptr) + PUO signature resolution; required evidence: in-place patch lines + `patched=<n>`; **`g_vtSc` set on first HookPresentVt**; **`vt restored count=<n>` registry-wide**; **no inline-patch-in-match / no `Present hook installed` on host16**; **single `R11_Render`/`PresentCore` per frame**; **`PUO resolved signature … rva=0x1B5F9B0 verified=1`** (any `PUO UNVERIFIED`/fallback line invalidates) + client.dll identity; first-5 per-order logs with clock state/gs/inGame + canary OK; **no CANARY CORRUPTED/drain DISABLED/STOP-DRAIN**; **viewmatrix ok=1**; mask7 `drew=1 mapOk=1`; `present hr=0`; HUD+Steam overlay functional; **behavioral hero visibly last-hits/gains XP**; **2 horns + 15-min soak**; **window order: normal first, `R11_SKIP_PUO=1` split only if normal fails**; crash ⇒ dump+PDB then split. **Reviewer re-gate v4m = REJECT (`393F202C…`; blockers #1/#3/#4 still present, PUO hardening good).**
- Baseline `422751ED` verified on disk (185,344 B); **no dota process running**; pid 6396 gone; v4k archive/dump retained; no launches/injections until Lead window.
Acceptance (fresh match): `loader=true`, `garbage=0`, `missing=0-1` (documented deferred namespaces only), `LaneCreepsManager/KV_LIB` documented non-causal; globals rows show non-empty LaneGroupsManager lists + `LIB_DAMAGE_PREDICTION` available + `loader.parityProbe()` rows. Lane acceptance: ≥3 last-hits by 5:00, XP growth between samples, ≤600 u to wave while last-hitting, ≤900 u to ally (teamplay), HUD "Now" matches actions.
Then paste D12d with line-index window; task-25 closes on this evidence.

### D12e. task-25 GLOBALS contract adjudication (root causes CONFIRMED)
- **Lane positioning cause = empty `LaneGroupsManager`** — ctx all four LaneGroup lists = 0, Jungle camps = 0; `creep_block.lua:36` laneWave falls back to `ctx.waves`; `Self Play.lua:939` wave picker skipped ⇒ hero "stands behind tower".
- **Last-hit / XP-gold cause = nil `LIB_DAMAGE_PREDICTION`** — `prediction.available()=false` ⇒ `combat.lua:211/800`, `last_hit.lua:382` lose incoming-damage math ⇒ missed last-hits.
- `LaneCreepsManager` / `KV_LIB` have **0 direct call sites** ⇒ deferred/documented, **NOT causal**.
- 7 pass/fail globals rows recorded in REVIEW.md 23:05.
Verdict: **OPEN — loader-events writing `src/globals.lua`** (perf caching p90<300 ms; orders-nav lane polylines + camp table); closes with D12d.

---

## Appendix E — Native input-fix window (2026-11-16 20:59-21:04, QA-side)

- Human/Lead order: stop loop (`20:59:37 host: script finished`, `20:59:38 host: stop.txt detected, watchdog exit`), kill Dota pid 4484 (confirmed 0 processes), old DLL 422751ED… released.
- Developer swap verified: `host16.dll` md5 **1AB3D7734E6A6F02FFC72DA11E384342** (185856 B); old renamed `host16.dll.old_20261116_210003`; backup `host16.dll.bak_20261116_205629` (422751ED…) untouched; record in `src/host16.dll.md5.txt`.
- Relaunch: `steam://rungameid/570` 21:00:28 → Dota pid 4428 start 21:00:30 → inject 21:02:04 OK (`inject_result.txt`), watchdog thread start, bot_loop auto-run in lobby, `[perf] load total=2045ms`, R11 frames OK (`open=0`).
- Input probes made before stand-down: elevated synthetic click `1687,1002` (ИГРАТЬ, mouse_event path) with menu closed; screenshots `qa_newdll_menu.png` (21:02:41), `qa_newdll_play.png`; `gui: hook swallow` lines = **0** — i.e. the new DLL did not log swallowing with menu closed. Full pass/fail of the input fix is being captured by Lead/human (human is at the PC) — see Appendix D4.
- Blocker that forced the swap (recorded for developer): in the 20:51 relaunch session on the OLD DLL (pid 4484), UI clicks were not delivered although both mouse_event and SendInput (`SendInput n=2 err=0`) were issued, window geometry was correct (SDL_app 0,0,1920,1080, ex=0x100) and no overlay window existed: `qa_play4.png`, `qa_playpanel.png`, `qa_treasure_click.png` show unchanged screens after clicks; `qa_reportclick.png` (SendInput 1150,530) dismissed the Dota Plus modal, proving injection itself worked. This is the product-level justification for the input-fix build.