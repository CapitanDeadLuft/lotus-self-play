# v4n RUN — in-place shared dxgi vtable slot-8 patch + PUO signature resolution — **WINDOW ABORTED (v4o gap); INVALID — pre-match abort: module-name case bug**

**VERDICT: WINDOW ABORTED (v4o gap)** — abort condition met exactly (`vtable slot patch refused module DXGI+0x18c0 … (dummy-shared)`, `patched=0`, no `vtable in-place active`, no stages log, lobby only, no crash). **No gate evidence.** PUO resolution/viewmatrix/client identity PASS before refusal. `r11_mode.txt` verified later = **mode=7 guard=0 dump=0** (fine; earlier `mode=0` was stale from mask-0 test).
**Observer-only:** QA did not kill/inject/swap/screenshot; Lead decides rollback (backup `host16.dll.bak422_20261118_011244` = 422751ED).
- `vtable slot patch refused module DXGI+0x18c0 vt=00007FF89D99A000 (dummy-shared)` (L520913)
- `in-place mode - shared vtable patched at init, no temp inline capture (patched=0)` (L520914)
- no `vtable in-place active … patched=1`; no present/frame lines; no `r11_stages.log`; `r11_mode.txt` had stale `mode=0` (would also invalidate draws).
**Lead classification/fix:** developer rebuilding **v4o** with **case-insensitive module-name comparison** in vtable patch/guard (resolver emits uppercase `DXGI`, guard refused correct `old=DXGI+0x18c0`), plus restored dummy-swapchain `FAILED(hr)||!sc` check and double-`InitOrders` return tidy-up. `r11_mode.txt` reset to **mode=7 guard=0 dump=0**. Lead will kill pid 24380 (non-hooking DLL → clean restart), swap v4o, relaunch, inject in lobby; **no rollback needed until window over** (rollback target `host16.dll.bak422_20261118_011244` = 422751ED retained). QA observer-only (no kill/inject/screenshots); next run = **new pid + new stages log** → contract in `qa_task26/v4_run_v4o.md`.

## (pre-abort capture for history — PUO/viewmatrix checks PASSED before patch refusal)

**ARTIFACT:** `src\host16_new_v4n.dll` **787,968 B @01:12:02 md5 640F9348FE239329D8C33CC27D61732A**; PDB **8,105,984 B** md5 9C7451111AB9A174948EBEED7F5663AB; MAP **1,214,041 B** md5 11B44BD0AC80FBA542BC89878A57657A; sources render11.cpp 56,541/1B2934D2FCDD6D305512BA15E83BC7F9 + host.cpp 45,492/**B8E81E88AA3C1002F9ED93CBFC352467**; `cl /c /Zi` OK; md5.txt `V4N build 2026-11-18 01:12:15` + `[20261118_011244] v4n WINDOW candidate active=640F9348…; 422751ED -> host16.dll.bak422_20261118_011244`. Reviewer PASS(conditional)/window authorized.

## WINDOW LIVE — **CONTRACT ABORT CONDITION MET (patch refused / patched=0)**
Injection detected on user-owned pid 24380 (started 01:12:23): `L520800 [01:12:51.872] host: watchdog thread start pid=24380`; `L520810 === BOT LOOP ===`. Init block:
- `L520906 [01:12:53.951] host: hook mode=vtable(v4h)`
- `L520907 host: R11_SKIP_PUO=0`
- `L520909 host: client.dll identity base=00007FFFDACF0000 size=0x6E3B000 timestamp=0x6AFB971F path=E:\SteamLibrary\steamapps\common\dota 2 beta\game\dotabin\win64\client.dll`
- **`L520910 host: PUO resolved signature addr=00007FFFDC84F9B0 rva=0x1b5f9b0 sig=ok matches=1`** ✓ (required)
- `L520911 host: audit hardcoded client-rvas count=2 PUO=0x1B5F860(sig 0x1B5F9B0) viewmatrix=0x6221CB0 client=00007FFFDACF0000`
- `L520912 host: resolved viewmatrix rva=0x6221CB0 first=0.000 0.000 ok=1` ✓ (required `viewmatrix ok=1`)
- **`L520913 [01:12:54.070] host: vtable slot patch refused module DXGI+0x18c0 vt=00007FF89D99A000 (dummy-shared)`** ← **expected `vtable slot patched in place … when=dummy-shared`**
- **`L520914 [01:12:54.072] host: in-place mode - shared vtable patched at init, no temp inline capture (patched=0)`** ← **`patched=0`, required `patched=1` + `vtable in-place active … patched=1` line ABSENT**
- No `vtable in-place active` line; no `vt restored count=…` (no restore yet); no `PUO UNVERIFIED` (good); no second InitOrders line yet; **`r11_stages.log` ABSENT** (no draw/hook path initialized); `r11_mode.txt` = `mode=0 guard=0 dump=0` (window required mask-7 evidence).
- State now 01:14:08: pid 24380 responding, loop 1730 in **lobby** (nil hero, no in-match frames/present/hud lines); host.log growing; **no crash**.
- QA shell env: `R11_INLINE_HOOK`, `R11_NO_HOOKS`, `R11_DRAW_MASK`, `R11_SKIP_PUO` all unset (QA launcher clean, but Dota was launched by Lead/user — Dota-side env unverified; host.log shows `R11_SKIP_PUO=0`).

**Per authorized contract: abort+rollback if `in-place mode` absent OR init crashes; also required `patched=1`/`vtable in-place active` — all violated (patch refused (dummy-shared), patched=0). This matches noted v4o follow-up ("dummy-swapchain guard restore"). Window run cannot produce required mask-7 `drew=1 mapOk=1` evidence; no stages log.** Lead decision needed: abort/kill+rollback (QA cannot kill/inject/swap) or authorize capture-only annotation. QA observer-only.

## Contract checklist (for continuation if Lead orders capture-only)
- [ ] `vtable slot patched in place … when=dummy-shared` — **MISSING (refused)**
- [ ] `vtable in-place active … patched=1` — **MISSING (patched=0)**
- [x] `PUO resolved signature … rva=0x1B5F9B0 sig=ok matches=1` (L520910)
- [x] client.dll identity (L520909)
- [x] `viewmatrix … ok=1` (L520912)
- [ ] first-5 per-order logs + canary — no in-match/orders yet
- [ ] no CANARY CORRUPTED/drain DISABLED/STOP-DRAIN — n/a yet
- [ ] no inline-patch lines — currently no in-match; init says "no temp inline capture"
- [ ] mask-7 `drew=1 mapOk=1` — no stages/frames yet
- [ ] `present hr=0` — none yet
- [ ] HUD + Steam overlay functional — none yet
- [ ] hero visibly last-hits/XP — none yet
- [ ] 2 horns + 15-min soak — none yet
- [ ] crash ⇒ dump + v4n PDB — no crash
- [ ] watch second InitOrders line (in-place repeat-call return uses `g_origPresent?1:0` = NULL) — not seen

## Notes
- v4o follow-up: dummy-swapchain guard restore (patch refused on dummy-shared target; build should restore trace then patch real swapchain).
- v4m remains DO-NOT-USE (393F202C rejected).
- Baseline rollback source: `host16.dll.bak422_20261118_011244` (422751ED).