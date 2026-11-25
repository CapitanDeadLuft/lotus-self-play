# v4i RUN — `R11_NO_HOOKS=1` control (staged; execute on Lead go after user returns)

**STATUS TRIGGER (2026-11-18): v4h window CRASHED (host16 GS-cookie crash in `PresentCore`; NV fault eliminated) ⇒ v4h trust INVALIDATED ⇒ v4i control is MANDATORY before further v4h or v4k.** Next window: Lead names v4k (`host16_new_v4k.dll` 786,432 B md5 **FE34518FB6B217791FF5C5E3B74287ED**, stack-safety-only delta; reviewer gate pending) and v4i mode/env as staged.

**WINDOW ORDER (Lead deviation + reviewer approval 23:40): v4h FIRST (default mode); v4i runs ONLY if v4h crashes/hangs/anomaly** (any crash/hang/anomaly invalidates v4h trust and makes v4i control mandatory before further v4h/v4k). v4i requires `R11_NO_HOOKS=1` set BEFORE Steam/Dota launch (Steam restart + env-before-launch, Lead coordinates user). If v4h survives clean → gate exit acceptable without v4i (v4i recommended if time permits).
**Rollback state verified (file-only):** active `host16.dll` = **422751ED3DABB466564B1A6F4E0EAC35** (185,344 B); v4g archived `host16.dll.v4g_20261117_203617`; v4j candidate `host16_new_v4j.dll` **B28198B8…** (785,920 B, PDB 8,196,096 retained). Freeze holds; pid 11408 untouched.

**REVIEWER v4j GATE = PASS(conditional) on `B28198B8…` ONLY (REVIEW.md 23:25); interim `C3A32FCE` NOT gated.** Six fixes verified; **chaining to Steam slot-8 handler preserved**. Window conditions (verbatim per reviewer/Lead):
- Order: **rollback 422751ED → v4i → v4h**.
- **v4i:** `R11_NO_HOOKS=1` → `hooks disabled by env` + `UiThread hooks disabled`; **no hook/present/stage lines**; Lua host lines present; **2 horns + 15-min soak**.
- **Crash ⇒ dump + invalidate v4h trust until explained; flag `vtable reinstalled` / mid-match `vtable restored` lines**; trace evidence path (stages/PDB).
- **v4k follow-ups (non-blocking):** unhook free vs render-thread UAF; RefreshVtableHook reinstall guards; 48 vs 40 entries.

**ARTIFACT (v4j, offline verified 20:35):** `src\host16_new_v4j.dll` **785,920 B @20:33:45 md5 B28198B8BAC2150F820F6D37AF8C220A** (PDB 8,196,096 B md5 924D3BCE76391CF2295447AA3A57B36F; MAP 1,211,449 B md5 281AA512EF489FEBBD13909FE393F474). Sources: `render11.cpp` 56,541 B md5 **1B2934D2FCDD6D305512BA15E83BC7F9** + `host.cpp` 41,937 B md5 **37F4E15FD9C63146FCCAAB988303885F** (`cl /c /Zi` OK). md5.txt: `V4J_FINAL 2026-11-17 20:33:45` — **supersedes interim `C3A32FCE…`; gate ONLY `B28198B8…`**. Mode contract: **default = v4h (vtable)**; **v4i mode via `R11_NO_HOOKS=1` before Dota launch**. Old `F7FE7BF9…` v4i/v4h builds are superseded (reviewer REJECT).
Previously-verified F7FE7BF9 behaviour (for reference only): `R11_NO_HOOKS=1` → InitOrders returns before any hook/dummy swapchain (log `hooks disabled by env R11_NO_HOOKS=1 (no DXGI/input hooks)`), UiThread skips SetWindowsHookEx (`UiThread hooks disabled by env R11_NO_HOOKS=1`); Lua host/watchdog still starts normally.

## v4j REBUILD (supersedes v4i artifact F7FE7BF9… — reviewer REJECT 23:10, 6 blocking fixes)
- **v4i will run from the v4j single binary (v4i mode × v4h mode; hashes TBD when developer delivers; supersede F7FE7BF9)**. Same env contract: `R11_NO_HOOKS=1` before launch.
- Accepted root cause for prior failures: our inline hook was patching **`gameoverlayrenderer64`** because **Steam replaces swapchain vtable slot 8** → mask-0 crash, horn timing, build-independence. v4h vtable chaining is the right architecture; v4j must prove chaining.
- **Gate evidence to capture** (see consolidated `qa_task26/v4j_gate_evidence.md`): vtable copy count **≥48**; `hooks disabled by env` **including input-hook skip** (`SetWindowsHookExA` not called / no `UiThread hooks` line); `R11_UnhookAll()` on shutdown + vtable-restore log; failure-path `RestoreInlinePatch()` logs; `hook target=`/`hook old=` + saved-bytes hex + patch-absence re-verification; unknown-module/render-tid guard lines.
- Sequence: rollback 422751ED → **v4i window** → v4h window; **2+ horns + 15-min soak**; exact launch sequence (env before Dota/Steam launch, rollback-first) documented in `qa_task26/v4j_gate_evidence.md`.
- v4i extra proof for fix #2: capture that **`SetWindowsHookExA` was not called** — no `UiThread hooks mouse=… key=…` line; `hooks disabled by env R11_NO_HOOKS=1 (no DXGI/input hooks)` + `UiThread hooks disabled by env R11_NO_HOOKS=1`; plus vtable copy count ≥48 line (host-side) and any `R11_UnhookAll()` restore lines.

## ENV (set BEFORE Dota launch; DLL reads getenv at init)
```
$env:R11_NO_HOOKS = 1
```
Defaults: draw mask irrelevant (no hooks/draw), overlay ENABLED per window (Steam overlay decision recorded), LocalDumps armed, stage trace not expected (no hook path).

## Expected evidence (from host.log; record verbatim)
- **Explicit line: `hooks disabled by env`** (e.g. `R11: hooks disabled by env (R11_NO_HOOKS=1)` — capture exact wording).
- **NO** inline-hook lines (`hook ResizeBuffers`, `Present hook installed`, `vtable present patched`), **NO `present hr=` lines**, **NO `r11_stages.log` file/stage lines** (record their ABSENCE explicitly; if any appear → invalid run).
- Lua-host loader lines present: `host: watchdog thread start pid=…`, `host: running bot_loop.lua`, `=== BOT LOOP ===`, `[perf] load …`, `loader: Self Play loaded`, script/loop lines; `modules drawmode …`/`R11_LogModules` only if the build still auto-logs (note presence/absence).
- Elevated module enumeration: host16 present (v4i md5 TBD from Lead/dev), `gameoverlayrenderer64.dll` present+version (overlay ON by design) → `qa_task26/v4i_modules.txt` (full `v4i_modules_full.txt`).

## Run plan (deterministic, 2 horns)
1. Lead swaps v4i (verify md5; record; rollback 422751ED / agreed baseline).
2. Rotate `r11_stages.log` if present (should stay absent).
3. Inject → ONE bot_loop → lobby.
4. Human single-player **Treant** match #1: capture lobby→horn transition lines, in-game survival (screenshots horn + 1 min), Windows 1000/1001 after horn.
5. Match #2 (restart): second horn; same capture; target 2 horns + ≥15-min soak if surviving.
6. Any crash → Windows 1000/1001, dump path (`dumps\dota2.exe.<pid>.dmp`), last host lines (no stage trace available), report.
7. Archive: host.log tail injection→end, module list, screenshots, Windows events, dump.

## Verdict logic
- **Survives 2+ horns with hooks OFF** ⇒ hook presence implicated (our inline hooks / hook-trampoline interaction with NV/overlay).
- **Crashes with hooks OFF** ⇒ DLL/thread presence (Lua host threads, UiThread, CreateRemoteThread payload) sufficient — escalate to "DLL presence" (next: R11_NO_HOOKS + still-loaded but threads pared, or plain Dota with only remote thread) per Lead.
- Any non-determinism (hooks still installed) ⇒ invalidate run.

## Invalidation
- Any hook/present/stage line, `hooks disabled by env` missing, module md5 mismatch, more than one loop.