# v4h RUN — vtable Present patch (staged; execute on Lead go after user returns)

**V4H WINDOW RESULT (archived 2026-11-18 01:00) — NV-driver crash ELIMINATED / mechanism proven, BUT host16 GS-cookie crash in `PresentCore`; v4h trust INVALIDATED per rule.**
- Injection/init (line-index): `L510295 [00:52:14.500] host: hook mode=vtable(v4h)` → `L510297 swapchain vtable probe getDescSlot=12 resizeSlot=13` → **`L510300 resize inline hooks not installed in v4h mode (no code patching during match)`** → `L510312 hook target=gameoverlayrenderer64+0x9c130 addr=00007FF864A1C130` → **`L510313 vtable present patched sc=000002C9A2CDBB90 slot=8 old=DXGI+0x18c0 new=host16+0xaab0 entries=48 present-tid=19516`** (recorded verbatim; note slot-8 old value was **DXGI+0x18c0**, while the inline-hook target was `gameoverlayrenderer64+0x9c130`) → **`L510314 inline patch restored ok=1 target=gameoverlayrenderer64+0x9c130 addr=00007FF864A1C130 len=10 nonzeroSnapshot=1 bytes=48 89 5C 24 08 48 89 6C 24 10`** → **`L510315 inline patch absent ok=1 target=00007FF864A1C130 len=10`** → `L510317 modules host16 … md5=B28198B8…` → `L510326 drawmode mask=7 guard=0 cachedRtv=0 mtProtect=1 stageTrace=1 restoreRt1=0 resize1Hook=0` → `L510328 multithread protected already=0 now=1`.
- Horn: `L511334 [00:52:29] clock anchor -> 105.033` / **`L511335 src=horn gt=105.03 gs=105.03 state=4 in_game=0.0`**; last host line **`L511341 [00:52:29] [order] PUO type=11 tgt=0 abil=1401 unit=npc_dota_hero_treant`**; `host.log` frozen **27,593,246 B @00:52:29**.
- `r11_stages.log` frozen **593,651 B @00:52:29**; final frame `f=507 tid=19516 mask=7`: `capture→rtv→draw(hud=39 verts=786 cap=3356)→statecopy→upload(drew=1 mapOk=1)→restore→exit→present` — pipeline completed, then crash.
- **Crash 00:52:29-34:** dump **`dota2.exe.26884.dmp` 7,239,387,683 B @00:54:01`**; analyses `dumps\v4j_crash_26884.txt`, `v4j_presentcore.txt`, `v4j_pc2.txt`, `v4j_analyze.txt`; exception **c0000409 subcode 0x2 FAST_FAIL_STACK_COOKIE_CHECK_FAILURE**; faulting thread `(6904.4c3c)` **#55 tid 0x4c3c**; stack **`host16!__report_gsfailure+0x1d ← host16!__GSHandlerCheck+0x13 ← host16!PresentCore+0x2d0 ← rendersystemdx11+0x6288f ← rendersystemdx11+0x5eeb9 ← …`**; large frame **`QOrder local[256]`** (per reviewer/dev); **exact writer unprovable** from dump.
- **Interpretation:** **NV driver crash (nvwgf2umx 0xc0000409/0xe4bcdd) ELIMINATED** in v4h — first non-NV fault of the series — **mechanism proven (vtable chaining works)**; but a **host16 GS-cookie (stack corruption) crash in `PresentCore`** replaced it ⇒ **v4h trust INVALIDATED per rule; v4i control MANDATORY before further v4h/v4k.**
- Post-window: active disk DLL rolled back to **422751ED**; new plain user-owned Dota **pid 16584** started 00:58:44, NOT injected; freeze holds.
- **v4k artifact (next window, reviewer gate pending):** `src\host16_new_v4k.dll` **786,432 B @00:59:18 md5 FE34518FB6B217791FF5C5E3B74287ED** — stack-safety-only delta vs v4j. Run files to use v4k when Lead names it; keep v4j PDB for 26884 dump (already symbolized).

**REVIEWER APPROVED v4h-FIRST (REVIEW.md 23:40) — conditions (verbatim):**
1. **v4h default mode only** (`R11_NO_HOOKS` unset; confirm `hook mode=vtable(v4h)`) + full evidence list: `hook target=gameoverlayrenderer64+0x…`; `vtable present patched … slot=8 old=gameoverlayrenderer64+0x… new=host16+0x… entries=48 present-tid=…`; `inline patch restored ok=1 … bytes=…`; `inline patch absent ok=1`; `resize inline hooks not installed in v4h mode`; mask-7 `drew=1 mapOk=1`; `present hr=…`; HUD + Steam overlay visible; **2 horns + 15-min soak**.
2. **ANY crash/hang/anomaly invalidates v4h trust and makes v4i control MANDATORY before further v4h/v4k.** Anomalies include: `vtable reinstalled`; mid-match `vtable restored`; `vtable hook failed`/`refused`; missing restore/absence lines; overlay dark.
3. **Crash rule:** LocalDumps armed; retain dump + host.log + rotated stage log; **symbolize with v4j PDB (matching GUID)**; **no cleanup before review**.
4. **If v4h survives clean → gate exit acceptable WITHOUT v4i** (v4i still recommended if time permits).
5. **Only `B28198B8…`**; verify no lingering env vars and that no other patcher changes the `hook target=` module.

**WINDOW ORDER (Lead deviation, 2026-11-17 20:36): v4h FIRST** (default mode; no env/Steam restart needed; user only needs one Treant match). **v4i control only if v4h crashes/anomaly** (v4i needs `R11_NO_HOOKS=1` BEFORE Steam/Dota launch → Steam restart + env-before-launch).
**Rollback state verified (QA file-only):** active `src\host16.dll` = **422751ED3DABB466564B1A6F4E0EAC35** (185,344 B); v4g archived `host16.dll.v4g_20261117_203617`; md5.txt `ROLLBACK (pre-window)` record appended. Window candidate `src\host16_new_v4j.dll` = **B28198B8BAC2150F820F6D37AF8C220A** (785,920 B; **PDB 8,196,096 retained — use it to symbolize any crash dump**). User Dota pid 11408 untouched; freeze holds.
**DUMP RULE:** crash ⇒ capture full dump (`dumps\dota2.exe.<pid>.dmp`) + symbolize with v4j PDB/MAP + last rotated `r11_stages.log` lines; **invalidate v4h trust** until explained; report Lead+reviewer+pm. Flag any `vtable reinstalled` or mid-match `vtable restored` lines.

**REVIEWER v4j GATE = PASS(conditional) on `B28198B8…` ONLY (REVIEW.md 23:25).** Window conditions (verbatim):
- Order: **rollback 422751ED → v4i → v4h**.
- **Expected v4h evidence lines:** `hook mode=vtable(v4h)`; `hook target=gameoverlayrenderer64+0x…`; `vtable present patched … slot=8 old=gameoverlayrenderer64+0x… new=host16+0x… entries=48 present-tid=…`; `inline patch restored ok=1 … bytes=…`; **`inline patch absent ok=1`**; **`resize inline hooks not installed in v4h mode`**; mask-7 `drew=1 mapOk=1`; `present hr=…`; HUD + Steam overlay functional; **2 horns + 15-min soak**.
- **Crash ⇒ dump + invalidate v4h trust until explained;** flag any `vtable reinstalled` / mid-match `vtable restored` lines; keep trace evidence path (stages + PDB).
- v4k follow-ups (non-blocking): unhook free vs render-thread UAF; RefreshVtableHook reinstall guards; 48 vs 40 entries.

**ARTIFACT (v4j, offline verified 20:35):** `src\host16_new_v4j.dll` **785,920 B @20:33:45 md5 B28198B8BAC2150F820F6D37AF8C220A** (PDB 8,196,096 B md5 924D3BCE76391CF2295447AA3A57B36F; MAP 1,211,449 B md5 281AA512EF489FEBBD13909FE393F474). Sources: `render11.cpp` 56,541 B md5 **1B2934D2FCDD6D305512BA15E83BC7F9** + `host.cpp` 41,937 B md5 **37F4E15FD9C63146FCCAAB988303885F**. md5.txt: `V4J_FINAL 2026-11-17 20:33:45` — **gate ONLY `B28198B8…`**; interim `C3A32FCE…` superseded. Mode contract: **default v4h (vtable chaining)**; v4i mode = env `R11_NO_HOOKS=1` (not used in this run). Old `F7FE7BF9…` builds superseded (reviewer REJECT).
Previously-verified v4h behaviour (F7FE7BF9, reference only): temporary inline Present hook → saves patch bytes → copies swapchain vtable (32 entries; v4j expects **≥48** count log) → replaces slot 8 with HookPresentVt under VirtualProtect → restores+verifies pre-patch dxgi Present bytes (Steam E9 intact) → logs `vtable present patched sc=.. slot=8 old=.. new=..` + `inline patch restored ok=1`; no inline hooks during match (legacy `R11_INLINE_HOOK=1` only).

## v4j REBUILD (supersedes v4h artifact F7FE7BF9… — reviewer REJECT 23:10, 6 blocking fixes)
- **v4h runs from the v4j single binary (default mode = vtable chaining; hashes TBD when developer delivers)**. Same env: nothing set for v4h mode (no R11_NO_HOOKS).
- Accepted root cause: our inline hook was patching **`gameoverlayrenderer64`** because **Steam replaces swapchain vtable slot 8** → mask-0 crash, horn timing, build-independence. **v4j v4h mode must chain Steam's handler, not overwrite it** — key evidence is `old=` pointing at **gameoverlayrenderer64+0x…**.
- **v4j-specific expected evidence (capture verbatim, line-indexed; consolidated in `qa_task26/v4j_gate_evidence.md`):**
  - `vtable present patched sc=… slot=8 old=gameoverlayrenderer64+0x… new=…` (old = Steam handler; record exact)
  - `inline patch restored ok=1` **with full saved/read-back bytes** (hex) + patch-absence re-verification line
  - **no inline hooks in-match** (no `hook ResizeBuffers`/`Present hook installed at` during match; any → invalidate)
  - vtable **copy count log ≥48**
  - mask-7 stage trace `drew=1 mapOk=1` frames; `present hr=` lines
  - HUD visible + **Steam overlay functional** (Shift+Tab works; screenshots)
  - unknown-module / render-tid guard logs if triggered
  - if any hook-failure path: `RestoreInlinePatch()` log + restored bytes
  - on shutdown: `R11_UnhookAll()` + vtable-restore log
- Window order after v4j re-gate: **rollback 422751ED → v4i window → v4h window**; v4h: **2+ horns + 15-min soak**, PDB dump on crash.

Purpose: replace inline Present trampoline with a **vtable patch of IDXGISwapChain::Present (slot 8)** to avoid inline-hook/trampoline interference with NV/Steam overlay hooks. Hook presence remains (vtable method), so it tests "inline code patch vs vtable dispatch" as the interaction factor.

## Expected evidence (capture verbatim, line-indexed)
- **`vtable present patched sc=… slot=8 old=… new=…`** (exact wording from dev; record sc/old/new).
- **`inline patch restored ok`** + **prologue read-back** lines (bytes observed/restored) — proof inline code path untouched.
- **No inline hooks in-match** — absence of `hook ResizeBuffers`/`Present hook installed at …` patterns for this run (record absence; any inline install → invalid/investigate).
- `R11: modules host16 … md5=<v4h md5>`; `modules drawmode mask=7 guard=0 cachedRtv=0 mtProtect=1 stageTrace=1 restoreRt1=0`; `multithread protected already=… now=…` (record; H0 still active).
- mask-7 stage trace: `r11_stages.log` present with `mask=7 … drew=1 mapOk=1` frames (verts/cap normal), last `stage=present`.
- `present hr=0x… devRemoved=0x0` lines.
- **HUD visible** on screen (screenshots horn + 1 min) and Steam overlay functional (Shift+Tab/capture noted; overlay ENABLED by window design).
- Window over the run: `R11_LogModules`/`R11_DiagDump` output; elevated module enum (`host16` v4h md5 + `gameoverlayrenderer64` present/version) → `qa_task26/v4h_modules.txt`(+full).
- Windows Application 1000/1001; dump path if crash (`dumps\dota2.exe.<pid>.dmp`).

## Run plan
1. Lead swaps v4h artifact (verify md5, record; rollback 422751ED / agreed baseline).
2. Rotate `D:\hake\lotus\r11_stages.log` before run.
3. Inject → ONE bot_loop → lobby; capture init lines (vtable patch + restored-ok + prologue read-back).
4. Human single-player **Treant** match #1: horn capture (resize/begin lines if emitted by v4h), 1-min survival, screenshots.
5. Match #2 (second horn); target **2+ horns + 15-min soak** if surviving.
6. Any crash → Windows 1000/1001, dump, stages tail, last stage line; report Lead+reviewer+pm.
7. Archive everything in `qa_task26/` + host.log tail.

## Verdict logic
- Survives 2+ horns + 15-min soak with vtable Present (overlay functional) ⇒ **inline Present trampoline implicated**; product fix direction = vtable hook or overlay-coexistence deferral.
- Crashes same signature ⇒ hook presence (any Present interception) or overlay-coexistence still implicated; combine with v4i (no-hooks) result.
- Inline patch not restored / prologue read-back mismatch / inline hook still present ⇒ invalidate run, report.

## Invalidation
- Missing `vtable present patched …` or `inline patch restored ok`; inline hook lines present; HUD not drawn (`drew=0` with mask7); more than one loop.