# v3 CRASH EVIDENCE PACKAGE — task-26 (QA hand-off)

Frozen 2026-11-17 18:09 MSK. Runtime is DOWN (Dota crashed 18:03:51; QA holding, no relaunch/rollback).
Active DLL: `host16.dll` 189440 B md5 CB0ED3F4D9E07271DD59A154D03DDE9A (v3). host.log mtime 18:03:50.

## Verdict
**v3 FAILS the task-26 crash gate.** P0 reproduced ~1 s after the in-match HUD epoch transition:
Windows Application Error 1000 @18:03:51 — `dota2.exe`, faulting module **`nvwgf2umx.dll` 32.0.15.9159**, exception **`0xc0000409`**, offset **`0x0000000000e4bcdd`** — identical to 17:38:12 / 17:42:37 baseline; WER 1001 BEX64 @18:03:55.
Saved event log: `qa_task26/crash_180351_eventlog.txt`.

## 1. Last 20 `[r11] frame` lines before crash (L458316→L460842, 18:03:08→18:03:49)
All identical and healthy:
```
R11: frame hud=39 menu=79 open=0 est=910 verts=786 cap=14972 vbB=299440 drew=1 mapOk=1 | init=0 bb=0 cmd=0 res=0 ens=0 mapfail=0 sw=1920
```
last: `L460842 [18:03:49]`. Session frame lines total = 266. `verts(786) ≤ cap(14972)`; `drew=1`, `mapOk=1`.

## 2. Zero `R11: skip` lines across the whole v3 session (from init L452106)
- total = **0**
- per category = **0** each: `skip vert overflow`, `vb-size`, `resource-null-after-cap`, `map-fail`, `resource-null`, `cmd-count`, `non-tri`
⇒ crash was NOT preceded/telegraphed by any guard/skip event; vertex-budget/menu-size theory not supported.

## 3. Timeline (line-indexed)
| line | event |
|---|---|
| L451949 [17:59:47.464] | `host: watchdog thread start pid=14876` (single loop; L451959 `=== BOT LOOP ===`) |
| L452106 [17:59:49] | `R11: init ok sw=1920 sh=1080` |
| L453010-453014 [18:00:26] | `diag(first=1..5) hud=0 menu=79 open=1 est=6718 verts=6456 cap=14972 vbB=299440 drew=1 mapOk=1` (menu prerequisite PASS) |
| L457358 [18:02:53] | `R11: Del toggle -> 1` (menu open) |
| L457392 [18:02:53] | **first in-match HUD** `[hud] cmds=39 text=10`; frame L457445 `hud=39 menu=79 open=1 est=7564 verts=7242` |
| L458089 [18:03:05] | `R11: Del toggle -> 0`; L458190 [18:03:06] frame `hud=39 menu=79 open=0 est=910 verts=786` (**menu closed, HUD-only**) |
| L458316→L460842 | 20 identical HUD-only frames, healthy (786≤14972) |
| L460914/460915 [18:03:50] | `[clock] anchor: observed state transition <4 -> 5 at gs=78.767` / `src=horn gt=78.77 gs=78.77 state=5 in_game=0.0` |
| L460919 [18:03:50] | `[menu] bind 'Hold to take over' code=65 vk=0x20 held=false` |
| L460920 [18:03:50] | `[order] PUO type=11 tgt=0 abil=1293 unit=npc_dota_hero_treant` — **LAST host.log LINE** |
| 18:03:51 | **dota2.exe crash** (App Error 1000 nvwgf2umx 0xc0000409 0xe4bcdd); WER BEX64 18:03:55 |
| — | host.log final flush 18:03:50 (24,461,326 B); **no stop marker**; no further `watchdog`/`BOT LOOP` lines; `Get-Process dota2` = empty |

## 4. Menu/Del activity 18:02–18:03 (separates menu-triggered vs first-HUD crash)
- Del `18:02:53 -> 1` (open), Del `18:03:05 -> 0` (closed at 18:03:05/06 per frame L458190).
- QA Esc probe `18:03:16` = no-op (menu already closed).
- **No menu geometry during the crash window** — menu closed ≥43 s / 20 frames before the fault.
⇒ crash is the **first in-match HUD epoch transition** (horn anchor logged 1 s prior), NOT menu-triggered. `hud=39` (<50 target) but continuous HUD-only drawing.

## 5. Artifacts kept
- `qa_task26/crash_180351_eventlog.txt` (Application 1000/1001 rows)
- `qa_task26/v3_menu_open_180026.png` (ClickGUI visible, prerequisite)
- `qa_task26/v3_02_botpanel.png`, `qa_task26/v3_03_after_bot_click.png` (in-game 0:09, Treant)
- `host.log` frozen at 460,920 lines (mtime 18:03:50)

## 6. Ready actions (await Lead word)
- (A) rollback: `Copy-Item -Force src\host16.dll.bak_20261116_205629 src\host16.dll` (422751ED…) → relaunch `steam://rungameid/570` → inject → ONE bot_loop; record md5/start markers. (Alt rollback: 1AB3D773 from `host16.dll.bak_20261117_174938`.)
- (C) no runtime change; hold frozen state for v4 diagnostics.
QA will not act until Lead explicitly chooses.