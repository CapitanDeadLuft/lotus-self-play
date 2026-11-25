# v4j (single binary, both modes) — QA GATE-EVIDENCE CHECKLIST

**REVIEWER APPROVED v4h-FIRST (REVIEW.md 23:40) — conditions verbatim:** (1) v4h default mode only (`R11_NO_HOOKS` unset; confirm `hook mode=vtable(v4h)`) + full evidence list (target/slot/entries/present-tid/restore bytes/absence/resize-inline-not-installed/mask7 drew=1 mapOk=1/present hr/HUD+Steam overlay/2 horns+15-min); (2) **ANY crash/hang/anomaly invalidates v4h trust and makes v4i control MANDATORY before further v4h/v4k** (anomalies include `vtable reinstalled`, mid-match `vtable restored`, `vtable hook failed`/`refused`, missing restore/absence lines, overlay dark); (3) crash rule: LocalDumps armed, retain dump + host.log + rotated stage log, **symbolize with v4j PDB (matching GUID)**, no cleanup before review; (4) if v4h survives clean → gate exit acceptable without v4i (v4i recommended if time); (5) only `B28198B8…`; verify no lingering env and no other patcher changes `hook target=` module. Freeze holds until Lead go.

**WINDOW ORDER UPDATED (Lead, 2026-11-17 20:36): v4h FIRST** (default mode, no env/Steam restart; one Treant match); **v4i control only if v4h crashes/anomaly** (requires `R11_NO_HOOKS=1` before Steam/Dota launch → Steam restart + env-before-launch).
**ROLLBACK STATE VERIFIED (file-only):** active `host16.dll` = **422751ED3DABB466564B1A6F4E0EAC35** (185,344 B); v4g archived `host16.dll.v4g_20261117_203617`; md5.txt `ROLLBACK (pre-window)` appended; v4j candidate `host16_new_v4j.dll` = **B28198B8BAC2150F820F6D37AF8C220A** (785,920 B; PDB 8,196,096 retained — symbolize any dump). User Dota pid 11408 untouched; freeze holds.
**DUMP RULE:** crash ⇒ full dump (`dumps\dota2.exe.<pid>.dmp`) + symbolize with v4j PDB/MAP + last rotated stages lines; **invalidate v4h trust until explained**; report Lead+reviewer+pm; flag `vtable reinstalled`/mid-match `vtable restored` lines.

**V4H WINDOW (00:52:14–00:52:29) — NV DRIVER CRASH ELIMINATED / MECHANISM PROVEN, but host16 GS-COOKIE CRASH in `PresentCore` → v4h trust INVALIDATED.**
- Evidence: `hook mode=vtable(v4h)`; `resize inline hooks not installed in v4h mode`; `hook target=gameoverlayrenderer64+0x9c130`; `vtable present patched sc=… slot=8 old=DXGI+0x18c0 new=host16+0xaab0 entries=48 present-tid=19516` (slot-8 old recorded verbatim = **DXGI+0x18c0**); `inline patch restored ok=1 … bytes=48 89 5C 24 08 48 89 6C 24 10`; `inline patch absent ok=1`; mask=7 `drew=1 mapOk=1` (f=507, cap=3356); horn `gt=105.03 state=4`; stages completed `present` then crash.
- Crash: `dota2.exe.26884.dmp` 7,239,387,683 B @00:54:01; **c0000409 subcode 0x2 FAST_FAIL_STACK_COOKIE_CHECK_FAILURE**; thread #55 tid 0x4c3c; stack `host16!__report_gsfailure+0x1d ← host16!__GSHandlerCheck+0x13 ← host16!PresentCore+0x2d0 ← rendersystemdx11+0x6288f …`; large frame `QOrder local[256]`; exact writer unprovable.
- Conclusion: NV-driver signature gone (vtable chaining mechanism works) but host16 stack-cookie corruption in PresentCore replaces it. **Per rule: v4i control mandatory before further v4h/v4k.**
- **v4k artifact (next window candidate; reviewer gate pending):** `src\host16_new_v4k.dll` **786,432 B @00:59:18 md5 FE34518FB6B217791FF5C5E3B74287ED** (stack-safety-only delta).

**REVIEWER v4j GATE = PASS(conditional) on `B28198B8…` ONLY (REVIEW.md 23:25)** (interim `C3A32FCE…` NOT gated). Six fixes verified; **chaining to Steam slot-8 handler preserved**.
**Window conditions verbatim:** order **rollback 422751ED → v4i → v4h**; **v4i** = `R11_NO_HOOKS=1` (`hooks disabled by env` + `UiThread hooks disabled`, no hook/present/stage lines, Lua host lines, **2 horns + 15-min soak**); **v4h** = `hook mode=vtable(v4h)`, `hook target=<module>+0x…`, `vtable present patched … entries=48 present-tid=…`, `inline patch restored ok=1 … bytes=…`, **`inline patch absent ok=1`**, mask-7 `drew=1 mapOk=1`, `present hr=`, HUD+Steam overlay functional, **2 horns + 15-min soak**; **crash ⇒ dump + invalidate v4h trust until explained; flag `vtable reinstalled`/mid-match `vtable restored` lines**; keep trace evidence path (stages/PDB).
**v4k follow-ups (non-blocking):** unhook free vs render-thread UAF; RefreshVtableHook reinstall guards; 48 vs 40 entries.

**ARTIFACT (offline verified 20:35):** `src\host16_new_v4j.dll` **785,920 B @20:33:45 md5 B28198B8BAC2150F820F6D37AF8C220A**; PDB 8,196,096 B md5 924D3BCE76391CF2295447AA3A57B36F; MAP 1,211,449 B md5 281AA512EF489FEBBD13909FE393F474. Sources: `render11.cpp` 56,541 B md5 **1B2934D2FCDD6D305512BA15E83BC7F9** + `host.cpp` 41,937 B md5 **37F4E15FD9C63146FCCAAB988303885F** (`cl /c /Zi` OK). md5.txt: `V4J build 2026-11-17 20:33:18` + **`V4J_FINAL 20:33:45` (supersedes interim `C3A32FCE…`; gate ONLY `B28198B8…`)**. Mode contract: **default = v4h (vtable chaining); v4i mode via `R11_NO_HOOKS=1` before Dota launch.** Old `F7FE7BF9…` v4i/v4h builds are superseded (reviewer REJECT). Reviewer fast re-gate requested; window only after Lead go (rollback 422751ED → v4i → v4h).

Reviewer **REJECTED v4i/v4h as built** (md5 F7FE7BF9…, REVIEW.md 23:10) with **6 blocking fixes**; v4j is the single-binary rebuild (v4i mode + v4h mode). Sequence on Lead go: **rollback 422751ED → v4i window → v4h window**.

**Accepted root cause (context for evidence):** our inline hook was patching **`gameoverlayrenderer64`** because **Steam replaces swapchain vtable slot 8** (Steam's own Present hook owns slot 8) → explains mask-0 crash, horn timing and build-independence. v4h vtable **chaining** architecture is the right direction; v4j must prove it chains Steam's hook, not overwrite it.

## Per-run evidence for the 6 fixes (capture verbatim, line-indexed)
1. **Vtable copy count ≥48** — log line reporting copied vtable entries (e.g. `vtable copy n=…`) must show **≥48**; if absent or <48 → invalidate run.
2. **v4i `hooks disabled by env` incl. input hooks skip** — expect both:
   - `hooks disabled by env R11_NO_HOOKS=1 (no DXGI/input hooks)` (or v4j wording)
   - explicit `UiThread hooks disabled by env R11_NO_HOOKS=1` **and evidence `SetWindowsHookExA` not called** (absence of `UiThread hooks mouse=… key=…` line; note it explicitly).
3. **`R11_UnhookAll()` on shutdown + vtable-restore log** — on script/host shutdown (or explicit unhook call) expect `R11_UnhookAll()` log + vtable-restore line (slot 8 restored to Steam/original) + verification.
4. **Failure-path `RestoreInlinePatch()` logs** — if any hook step fails, expect `RestoreInlinePatch()` log + original bytes restored; **no silent partial patch**. (Trigger naturally or note absent on happy path; record line.)
5. **`hook target=`/`hook old=` + saved-bytes hex + patch-absence re-verification** — for v4h temporary inline step: log `hook target=…`/`hook old=…`, hex of saved bytes, and a **re-read proving patch absence after restore** (`patch absent`/`inline patch restored ok=1` with bytes).
6. **Unknown-module / render-tid guards** — expect logs when hook target/module is not a known DXGI/Vulkan module or when called off render thread; capture any `unknown module`/`render-tid` guard lines; if a guard triggers, record and do not interpret as failure unless it breaks draw.

## Common per-run capture (both modes)
- Elevated module archive: host16 md5 (v4j) + `gameoverlayrenderer64.dll` present/version → `qa_task26/<mode>_modules_full.txt`/`_modules.txt`.
- `R11_LogModules`/`R11_DiagDump` outputs; `[r11] multithread protected` (v4h); `modules drawmode mask=… guard=… cachedRtv=… restoreRt1=…`.
- Rotated `r11_stages.log` (v4h: mask7, drew=1 mapOk=1 frames; v4i: expect absent/no stage lines — record absence).
- Horn lines (2+ horns), present hr/devRemoved, skip categories, Lua errors, Windows 1000/1001, dump path on crash.
- v4i: survive 2+ horns ⇒ hook presence implicated; crash ⇒ DLL/thread presence escalation.
- v4h: HUD visible (screenshots), Steam overlay functional, 2+ horns + 15-min soak; crash same signature ⇒ report with dump/stages.

## Launch sequence (Lead-approved order; offline staged)
**Window order: rollback 422751ED → v4i window → v4h window.** Env must be set **BEFORE Dota launch** (Steam restart expected; Lead coordinates with user). Freeze holds until Lead go.

1. **Pre-step (Lead/QA, runtime must be down):** restore rollback baseline 422751ED per `rollback_prep_v4g_to_422751ED.md`; verify active `host16.dll` md5 = 422751ED3DABB466564B1A6F4E0EAC35 (185,344 B); append md5.txt record.
2. **v4i window:** Lead/developer swaps v4j binary (record md5/size; verify against md5.txt), sets env in the launcher shell **before launch** (`$env:R11_NO_HOOKS = 1`), relaunches Steam+Dota with that env (Steam must be fully restarted so Dota inherits it), QA verifies: elevated module list (host16 = v4j md5; gameoverlayrenderer64 present+version), then Lead injects via approved path, run ONE bot_loop, human starts single-player Treant match; capture per `v4_run_v4i.md` + 2+ horns + 15-min soak.
3. **v4h window:** Lead/developer swaps (same binary; **no R11_NO_HOOKS in env** — verify `modules drawmode`/env logs show default), restarts Dota with clean env; inject → ONE bot_loop → Treant match; capture per `v4_run_v4h.md` (slot-8 chaining, bytes restore, mask7 drew=1, HUD/overlay, 2+ horns + 15-min soak).
4. After each run: archive host.log tail, rotated `r11_stages.log` (v4h; absent for v4i), elevated full+filtered module lists, presents/skips/Windows events, screenshots (when allowed by window rules), dump on crash.
5. Any crash → **STOP**, keep PDB dump + last `stage=`/saved-bytes lines, report Lead+reviewer+pm; no blind retry.

## Invalidation
- Artifact md5 mismatch or not v4j-frozen; vtable copy <48/missing; v4i has any hook/present/stage line or `UiThread hooks` line; v4h missing `vtable present patched`/restore-proof bytes; more than one loop; missing gate line from the relevant fix list.