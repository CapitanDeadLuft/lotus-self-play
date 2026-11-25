# v4b DIAGNOSTIC WINDOW — QA RUN MATRIX (staged, NOT executed)

**FREEZE 2026-11-17 18:34 MSK — user instructed hands-off (he will play Dota). No runtime actions until Lead/user says "continue".** State at freeze: active DLL 422751ED (lobby-safe only); v4b artifact CDBAF472 staged in `src\host16_new.dll`; `r11_stages.log` absent; dump `dota2.exe.25604.dmp` 6.92 GiB retained; run-0 already **PASS (overlay alone insufficient)** — see `v4_run_0.md` / QA_REPORT D14d. Next on resume: **A1** (v4b mask 7 + overlay ENABLED, expected crash) → **A0** (mask 7 + overlay DISABLED, elevated-verify renderer absent, expected survive) → mask ladder 0/1/2 if A0 crashes.

**REVIEWER CONDITIONS APPLIED (REVIEW.md 21:35, PASS(conditional)):**
- **Do NOT use `R11_STAGE_TRACE=0`** — flag unwired; **stage trace is ALWAYS ON**. **Clear/rotate `D:\hake\lotus\r11_stages.log` before every run.** Runs ≤10 min.
- **Do not rely on `R11_RESTORE_RT1`** (8-slot only) — if game-state oddities/drift appear, **stop + report**.
- Run **A** must capture `[r11] multithread protected already=… now=…`; **abort A if UNAVAILABLE/`now=0`**.
- Mask-0 (hook-only) runs: `present … devRemoved=0x80004005` is BY DESIGN — ignore.
- **A–F with `R11_CACHED_RTV=0`; G with cache on.** Every run starts **before horn**, **2+ horns/mode**, LocalDumps armed, capture last `stage=` + `present …` lines.
- **Any crash → keep `r11_stages.log` tail + dump; report Lead+reviewer+pm.**
- Active DLL at window start = 422751ED (lobby-only; do NOT use in-match); runtime DOWN now.

Artifact for the next dedicated window (Lead GO only): `src\host16_new.dll` **201,728 B @18:18:09 md5 CDBAF4720E6ED333180720DAE3421F38**
Sources: `render11.cpp` 50,488 B @18:17:46 md5 20BB9CDAF12E9C9645C6248B05265F28; `host.cpp` 23,062 B @18:14:22 md5 DF22BAAC761AB61A5D8AC93144829123 (cl /c OK, 0 warnings). Provenance recorded in `src\host16.dll.md5.txt` (V4b build 2026-11-17 18:18:16; changes vs v4: MT-protect QueryInterface from g_dev, bbRTV AddRef/Release, `R11_STAGE_TRACE` flag (unwired — ignore), `R11_RESTORE_RT1`).
Rollback: `host16.dll.bak_20261116_205629` / active 422751ED (current), 1AB3D773 backups intact.
**Pre-window baseline (recorded):** 422751ED crashed in-match at `18:14:40` (horn 18:14:39), same P0 NV signature; full dump `D:\hake\lotus\dumps\dota2.exe.25604.dmp` 6.92 GiB kept.

## Global rules (every run)
0. **Active-DLL header for the window (fill/verify at window start):** active `host16.dll` = `<v4b CDBAF472… after swap>`; sources render11.cpp 50,488/20BB9CDA… + host.cpp 23,062/DF22BAAC…; **pre-swap active = 422751ED (lobby-only, never in-match)**; record md5s + mtimes in run log.
1. Clear/rotate stage trace before run: delete/rename `D:\hake\lotus\r11_stages.log` (created on DLL init; trace is always-on; `R11_STAGE_TRACE=0` is UNWIRED — do not use).
2. Start sequence: kill any dota2 → swap artifact (verify md5 CDBAF472…) → QA relaunch `steam://rungameid/570` → inject → ONE bot_loop.
3. **Run starts BEFORE horn**; single-player bot game; **2+ horns per mode**; cap ~10 min/run.
4. **Per-run capture row (fill for every A–G run):** run id | mode/env | start/end time | active DLL md5 | horn line(s) | **last `stage=` line** | `present … hr= / devRemoved=` lines | skip counts per category | `R11: frame` tail (verts/cap/hud/menu) | Windows 1000/1001 | **crash? → dump path + stages tail copy**. Save as `qa_task26/v4_run_<id>.md` + `stages_<id>.log`.
5. **Live control path (preferred, in-process):** write `D:\hake\lotus\r11_mode.txt` (`mode=`, `guard=`, `dump=`) and point `run.txt` at `src\diag_r11_mode.lua` (verified: 2,487 B md5 B67CF1E5FCEF5B5E1DBFFB7FA1DBBB73, loadfile OK) — resolves `R11_SetDrawMode`/`R11_SetDrawGuard`/`R11_DiagDump` from the loaded `host16.dll` module and logs `[qa-r11] …` lines to host.log. External variant `src\qa_call_export_arg.lua` (2,921 B md5 79EEB26C5CDC9E556912B2C371EADE45, CreateRemoteThread with numeric x64 RCX arg) exists for out-of-process calls. **If live export call fails, fallback = set env before launching Dota through our launcher; report which path worked.**
6. **`R11_DiagDump()` after each mode** (live export; also called by diag_r11_mode when `dump=1`).
7. Run **A MT-line check is mandatory**: capture `[r11] multithread protected already=… now=…`; abort A if UNAVAILABLE/now=0.
8. Do not rely on `R11_RESTORE_RT1` (8-slot only); if game-state oddities/drift appear → stop + report.
9. Mask-0 runs: `present … devRemoved=0x80004005` by design — ignore.
10. Any crash → keep dump + `r11_stages.log` tail; report Lead+reviewer+pm immediately; no blind retry.

## OVERLAY MATRIX (Lead-locked order: A1 first, then A0; then mask ladder if needed)
**Lead-locked plan:** **A1 = v4b mask 7 + Steam overlay ENABLED** (current state; expected crash ~1 s after horn) → **A0 = v4b mask 7 + Steam overlay DISABLED** (human turns off Steam In-Game Overlay, restart; QA verifies `gameoverlayrenderer64` ABSENT via elevated enumeration; expected survive) → if split holds: coexistence branch + product fix "detect Steam overlay and skip/defer in-match draw (explicit log/notice)", gate on overlay-disabled candidate; if A0 crashes → mask ladder 0/1/2.
Lead drives swap: human done → Lead kills Dota → swaps `host16_new.dll` CDBAF472 → verify md5 + record → relaunch+inject → `r11_mode.txt` `mode=7 guard=0` + `run.txt=src\diag_r11_mode.lua` → human fresh Treant match.
**Per-run capture:** elevated module list (`host16` + `gameoverlayrenderer64` presence/version; medium-integrity enumeration is INVALID for high-integrity Dota), `[r11] multithread protected already=… now=…`, `r11_stages.log` last lines (rotated per run), `present hr=devRemoved=`, skip categories, Windows 1000/1001, screenshots at horn + ~1 min, dump if crash; record overlay state for each run.

| run | config | purpose | notes/abort |
|---|---|---|---|
| **0a** | plain Dota, no host16, **Steam overlay ACTIVE (renderer loaded)** | control: overlay alone vs P0 | **RESULT: survived first horn ≥2 min, no host16, renderer 11.23.65.88 loaded, zero new Windows 1000/1001** (soak/2nd horn noted) |
| **A1** | **v4b mask 7 + overlay ENABLED** | host16+overlay interaction (expected crash) | capture MT line + stage tail + dump; `mode=7 guard=0` |
| **A0** | **v4b mask 7 + overlay DISABLED** | our draw path alone (expected survive) | human disables Steam In-Game Overlay + restart; QA **elevated-verify renderer ABSENT**; then inject. **BLOCKED 19:22-19:28:** pid 15264 still had renderer loaded (invalid), Steam not restarted |
| **A1b** | v4c mask 7 + **`R11_RESTORE_RT1=1`** (env BEFORE Dota launch) | restore-cardinality residue test | must verify `modules drawmode … restoreRt1=1` in R11_LogModules line; **abort/re-launch if restoreRt1=0**. File: `v4_run_A1b.md` |
| **A1c** | v4c **mask 0 hook-only**, overlay ENABLED, set LIVE via `r11_mode.txt mode=0` | hook presence vs our draw calls | no relaunch needed; mask-0 may log resource-null/`devRemoved=0x80004005` by design; survives ⇒ draw path implicated. File: `v4_run_A1c.md` |
| **B** | v4b mask 0 hook-only (overlay per current state) | hook vs draw | devRemoved=0x80004005 ignored |
| **C** | v4b mask 1 state-only | state save/restore only | |
| **D** | v4b mask 2 HUD-no-world | world-marker draw suspect | |
| **E** | v4b mask 7 + cached RTV ON | cache/RTV alias | |

**Every run:** record overlay module presence+version (elevated!), 2+ horns where applicable, before-horn start, ≤10 min, rotate `D:\hake\lotus\r11_stages.log`, LocalDumps armed; any crash → dump + stages tail + report Lead+reviewer+pm. Live control: `src\diag_r11_mode.lua` + `r11_mode.txt` (env fallback).

## Gate (task-26)
- Failing stage identified from last `stage=` line + dump stack.
- **mode-3 (HUD+MENU) survives ≥2 horns + 15-min soak** with zero skip lines, no new nvwgf2umx 0xC0000409, stage log clean.
- Only then candidate becomes active; role/Carry acceptance unblocked (harness `bot_loop_role1.lua` 3,480 B md5 B58B85CD9B90ECC5BE7FBBC247829D95 staged).

## Baseline labels (kept in QA_REPORT D14c)
- **422751ED = in-match crash / lobby-safe only** (18:14:40, dump 6.92 GiB)
- **v3 CB0ED3F4 = crash-gate FAIL** (18:03:51)
- **v2 65A35E48 / v1 8B246867 = non-evidence** (v2 deadlock/no-draw; v1 pre-fix)