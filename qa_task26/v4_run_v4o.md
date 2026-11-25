# v4o RUN — in-place vtable patch (gated BB36C1CB variant) — HOLD: awaiting Lead injection order

## NEXT-WINDOW STATE (verified offline 01:41; QA observer-only)
- **host16 for window = gated `BB36C1CBE5401AAD6A7F602D357E71D7`** (790,016 B; PDB 8,220,672 / MAP 1,215,542) — **active on disk** now; **40C2634E is dead/do-not-use** (window record archived `host16.dll.bak422_20261118_014037` = 422751ED baseline; earlier `host16.dll.bak422_20261118_011244` etc. retained).
- **orders.lua = `C2B0CA29633B3BFB45A4CAD09E0C6864`** (38,832 B @01:39:10) — **reviewer PASS (REVIEW 03:50)**; final acceptance target.
- **No injection yet**: host.log frozen `01:39:18`; `r11_stages.log` ABSENT; new user-owned **Dota pid 22624 (start 01:40:38)** running, not injected by QA (Lead drives).
- `r11_mode.txt` = mode=7 guard=0 dump=0 (verify at window); rollback = `host16.dll.bak422_20261118_014037` (422751ED, 185,344 B).
- Fresh pid + fresh stages log expected; QA will rotate/verify stages file at injection.

## ACCEPTANCE for this window (Lead go)
- `[order] init ok rva=0x1B5F9B0 oIsLocal=…` with **numeric offsets** (schema.init checked / ensureInit consumers).
- `[order] PUO rva=0x1B5F9B0 sig=ok` **AND** host16 `PUO resolved … rva=0x1b5f9b0 sig=ok matches=1` in same host.log.
- **No `:284/:286` nil arithmetic**, no `script finished`; no `fatal`/`refused`/`patched=0`.
- Transient `[order] init retry n=…` allowed **only if it ends `init ok`** (rate-limited 2 s, bounded 200 → fatal).
- mask-7 `drew=1 mapOk=1`; `present hr=0`; HUD+Steam overlay; orders reach engine + hero visibly last-hits/XP; **2+ horns + 15-min soak**; crash/silent-exit ⇒ dump/`*_accessviolation.mdmp` + PDB + stages + host.log retained.

## (previous-window records below: 40C variant window + interim pid 23092 session + anomalies)

## FINAL ORDERS.LUA TARGET (updated 01:40)
- **`src\orders.lua` = 38,832 B @01:39:10 md5 `C2B0CA29633B3BFB45A4CAD09E0C6864`** (loadfile OK) — **final target for run-file acceptance**; reviewer re-gate PENDING.
- Contents: retry/fatal state machine (rate-limited 2 s, bounded 200 → fatal), `schema.init()` checked, ensureInit across consumers, per-offset logs (`[order] init ok rva=0x1B5F9B0 oIsLocal=…`).
- Prior revisions seen/rejected: 2603357B (orders.lua.ok_20261118_013212; running state crashed :284/:286 nil arithmetic → script finished), FD03A5A3 (REJECT 02:40), 4E5EDE49 (partial, PM), intermediate 15C291A6/36F9202C (transient mid-write). **No true pre-change snapshot for the earliest revision.**
- **No Dota process now** (pid 23092 gone); fresh loader state ONLY after reviewer gate + Lead order.

## INTERIM SESSION (pid 23092, 01:38:55–~01:39:4x) — brief, NOT a valid window
- `L546879 [01:38:55.957] watchdog thread start pid=23092`; `BOT LOOP`; `L546984 InitOrders begin`.
- ✓ `L546989 [01:38:58.119] PUO resolved signature addr=00007FFFDC84F9B0 rva=0x1b5f9b0 sig=ok matches=1`
- ✓ `L546992 vtable slot patched in place … patched=1 whence=dummy-shared`; ✓ `L546993 in-place mode … patched=1`
- ✓ `L547012 vtable in-place active sc=000001479FB1FE30 patched=1 present-tid=4852`; drawmode mask=7; MT `already=0 now=1`.
- **`[order] PUO rva=0x1B5F9B0 sig=ok` count = 0 (ABSENT — blocking)**; no PUO calls in session; no errors in first ~40 s; lobby frames only (hud=0 menu=0 verts=0); process gone before any match (no mdmp/WER noted).
- Race observed: orders.lua changed during load/init window (4E5EDE49 → 15C291A6 @01:38:58 → C2B0CA29 @01:39:10) — running state revision under test uncertain; **do not count as acceptance evidence**.

## (earlier live anomaly + PASS(conditional) record below)

## 🚨 LIVE ANOMALY (01:32:30) — **Lua host SCRIPT FINISHED; window invalid for product/last-hit acceptance**
- `L546450 [01:32:27] OnUpdate error: D:\hake\lotus\src\orders.lua:284: attempt to perform arithmetic on local 'o' (a nil value)`
- **`L546578 [01:32:30.096] host: runtime error: D:\hake\lotus\src\orders.lua:286: attempt to perform arithmetic on local 'o' (a nil value)`**
- **`L546579 [01:32:30.111] host: script finished`**
- After that: **no `BOT LOOP` restart, no `loop` lines** (last `01:32:30 loop 2355`); only R11 menu render frames continue (`present tid=27040 hr=0x0 mask=7`, `frame hud=0 menu=79 open=1 verts=6456 drew=1 mapOk=1`, f≈32k @01:36:24). **Lua host/orders dead in current pid 26308** → cannot produce `[order] PUO rva=…`, `R11: puo call`, last-hits/XP; **window INVALID for acceptance** (fail-safe script exit, no crash).
- Running Lua state used older orders.lua (2603357B, pre-sticky-fix); disk changed mid-window → **restart loader state required** (Lead decision).
- `[order] PUO rva=0x1B5F9B0 sig=ok`: **ABSENT** (blocking per PM rule; confirmed missing before any order).
- Stages log still not rotated (contains prior session tid=19492 + current tid=27040).

## ORDERS.LUA RE-GATE (PASS conditional) — applies NEXT loader state
- **`src\orders.lua` md5 FD03A5A31630BE6C1644A8BC176E954D** (37,173 B @01:35:17; loadfile OK). Reviewer **PASS(conditional)** (REVIEW.md 02:30).
- **Caveat: sticky `initErr`** — any first-call failure (incl. client.dll not loaded) is permanent for the session; window must show `sig=ok` on first init.
- **If `[order] PUO … sig=MISMATCH` / `orders uninitialised` / initErr appears ⇒ orders disabled by design → run INVALID for product/last-hit acceptance** (fail-safe, not crash).
- Acceptance lines: `[order] PUO rva=0x1B5F9B0 sig=ok` **AND** host16 `PUO resolved … rva=0x1b5f9b0 sig=ok matches=1` in same host.log; **no MISMATCH**; orders reach engine + hero visibly last-hits/XP.
- Provenance: `orders.lua.ok_20261118_013212` = **2603357B** (36,778 B) older post-change copy; no true pre-change snapshot (old hash unknown). Current disk **FD03A5A3**; intermediate 36F9202C seen briefly at 01:35:04.

## (window record continues below)

**VARIANT ACTIVE: interim `40C2634E`** (not BB36C1CB) — record in every report. `src\host16.dll` = **40C2634E7A4B45F578111FD8E19B35F6** (790,016 B @01:14:51; PDB 8,122,368 / MAP 1,215,198; md5.txt `V4O hotfix 01:14:51`). Final `host16_new_v4o.dll` remains **BB36C1CB** (790,016 B) unused.

**ROOT CAUSE #3 (accepted, product fix on disk): Lua-side stale PUO RVA `src\orders.lua:57`** — old 0x1B5F860; after `[order] WARN queue drain timeout … direct-call fallback` the direct path hit the stale address → tier0 AV; the game's own crash handler wrote `dota2_2026_1118_011939_0_accessviolation.mdmp` (01:19:40) and `dota2_2026_1118_012710_0_accessviolation.mdmp` (01:27:10) in `E:\SteamLibrary\steamapps\common\dota 2 beta\game\bin\win64` and exited silently (no WER). **Fix:** `src\orders.lua` md5 **2603357B4D90A0D278D9BC738C792A66** (36,778 B), RVA **0x1B5F9B0** + signature guard; expect `[order] PUO rva=0x1B5F9B0 sig=ok` at init (MISMATCH ⇒ init error/abort).

**Current live process: pid 26308** (started 01:29:10), injected `[01:30:44.608] watchdog thread start pid=26308`; `r11_mode.txt` = mode=7 guard=0 dump=0; host.log 29.9 MB and growing; stages 37.6 MB and growing.

## Init evidence captured (line-index)
- `L543059 [01:30:46.800] host: PUO resolved signature addr=00007FFFD6D2F9B0 rva=0x1b5f9b0 sig=ok matches=1` ✓
- **`L543062 [01:30:46.866] host: vtable slot patched in place vt=00007FF89D99A000 old=DXGI+0x18c0 new=host16+0xace0 patched=1 whence=dummy-shared`** ✓ (exact contract line)
- **`L543063 [01:30:46.868] host: vtable in-place active sc=0000028017FE6E40 patched=1 present-tid=27040`** ✓
- `L543064 host: in-place mode - shared vtable patched at init, no temp inline capture (patched=1)` ✓
- `L543081 R11: modules host16 … md5=40C2634E7A4B45F578111FD8E19B35F6` ✓
- `L543093 [01:30:46] R11: modules drawmode mask=7 guard=0 cachedRtv=0 mtProtect=1 stageTrace=1 restoreRt1=0 resize1Hook=0` ✓
- `L543095 [01:30:46] R11: multithread protected already=0 now=1` ✓
- 40C variant: **no init-marker expected** (correctly absent per contract).
- ⚠ **Stages log NOT rotated before this injection** — file contains prior session lines (`f=1 tid=19492 …`) plus current session (`f=… tid=27040`); contract asked fresh stages log. Record as observation (not abort per reviewer; separate by tid/line-index). Current session first observed: `f=16120 tid=27040 mask=7 stage=present` (hud=0/verts=0 lobby).
- `[order] PUO rva=0x1B5F9B0 sig=ok` init line: NOT yet observed in current session (only `PUO resolved signature … rva=0x1b5f9b0 sig=ok matches=1` from R11). **Flag: orders.lua init line still to confirm.**
- `R11: puo call n=…` lines so far all from **prior session** (n=1..5 at 01:27, pid 27576 window that crashed silently); none yet in current session (lobby, no orders).
- `[order] WARN queue drain timeout`: historical count 111 in log; **none after 01:29 injection** (good); continue tracking timing/frequency.
- Present/frame: `R11: present tid=27040 hr=0x0 devRemoved=0x0 mask=7 mt=1`; frames `hud=0 menu=0 verts=0 drew=0` (lobby, pre-match) — expected.

## Silent-exit detection (ready)
- On unexpected process end: check **`E:\SteamLibrary\steamapps\common\dota 2 beta\game\bin\win64\*.mdmp`** newest (esp. `*_accessviolation.mdmp`) **and** Windows WER 1000/1001 in Application log; preserve dump + note game-bin mdmp path/size/time; match PDB = active variant (40C: PDB 8,122,368 / MAP 1,215,198; BB: 8,220,096… per md5.txt V4O2 record PDB 8,220,672).

## Remaining capture checklist (this window)
- [ ] `[order] PUO rva=0x1B5F9B0 sig=ok` at init from orders.lua (confirm)
- [ ] `R11: puo call n=… ret=1` in current session (first orders)
- [ ] queue drain timeout occurrences after injection (timing/frequency; soft issue, not abort)
- [ ] horn/2 horns; post-horn survival/orders/nav/overlay; mask-7 `drew=1 mapOk=1`; `present hr=0`
- [ ] hero visibly last-hits/XP (behavioral); 2 horns + 15-min soak
- [ ] crash/silent exit ⇒ mdmp + WER + PDB symbolization; report Lead+reviewer+pm
- [ ] archive host.log tail + stages + module list at end

## Contract variants (reference)
- 40C2634E (active): no init-marker/stage-init expected; all other lines/invalidators as defined.
- BB36C1CB (unused final): would add `r11_stages.log init marker written` + `stage=init` line; absence there = defect-to-report (not invalidator).
Abort/invalidate: patch refused/patched=0; no `vtable in-place active`; PUO UNVERIFIED/fallback/matches≠1; CANARY CORRUPTED/STOP-DRAIN; inline patch in match; crash/hang/anomaly per rule.
Rollback target: `host16.dll.bak422_20261118_011244` = 422751ED.