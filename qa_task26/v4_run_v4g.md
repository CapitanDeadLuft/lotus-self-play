# v4g RUN — decoder-only resize-hook fix (artifact `B5928291…`) — staged, execute on Lead order

**V4G WINDOW RESULT — FAIL (2 horn crashes, same NV signature; archived 2026-11-17 20:22, offline evidence)**
Activation record: `[20261117_195753] Lead window v4g: active=B5928291C1A0A66AB8124620525D1F5D (779264 B)`; `host.log` frozen **27,511,245 B @20:05:37**; active disk `src\host16.dll` still v4g B5928291.
- **Run A (pid 4232):** `L498032 [19:57:53.996] watchdog thread start pid=4232` → `L498042 BOT LOOP` → probe `L498137 swapchain vtable probe getDescSlot=12 resizeSlot=13` → **`L498139 decoder selftest ok=1 rbLen=10 rb1Len=15 negRejected=1` (PASS per corrected contract)** → `L498140 hook ResizeBuffers slot=13 addr=00007FF89D922810` (**no prologue mismatch**) → `L498154 modules host16 … md5=B5928291…` → `L498172 modules drawmode mask=7 guard=0 cachedRtv=0 mtProtect=1 stageTrace=1 restoreRt1=0 resize1Hook=0` → `L498173 diag env mask=7 guard=0 cachedRtv=0` → `L498174 multithread protected already=0 now=1` → `L498219 init ok sw=1920 sh=1080` → **`L498222 ResizeBuffers1 hook disabled by default (R11_RESIZE1_HOOK=0)`**.
  - Horn `L502237 [19:58:59] src=horn gt=109.90 gs=109.90 state=4 in_game=0.0`; **crash 19:59:00** — Windows **1000** nvwgf2umx.dll 32.0.15.9159 / 0xc0000409 / 0xe4bcdd; WER **1001 @19:59:04**; dump **`dota2.exe.4232.dmp` 6.59 GiB (7.08 GB dec) @20:00:15**.
- **Run B (pid 25052):** `L502246 [20:03:35.313] watchdog thread start pid=25052` → probe `L502355` → **`L502357 decoder selftest ok=1 rbLen=10 rb1Len=15 negRejected=1`** → `L502358 hook ResizeBuffers slot=13` (no mismatch) → `L502390 drawmode mask=7 … resize1Hook=0` → `L502392 MT already=0 now=1` → `L502433 init ok` → `L502437 ResizeBuffers1 hook disabled by default`.
  - **Live mask switch to hook-only:** `L503696 [20:03:55] modules drawmode mask=0 …`; `r11_stages.log` shows `mask=0 … stage=hookonly … stage=present` (last f=14617, tid=25764).
  - Horn `L510186 [20:05:36] src=horn gt=150.90 gs=150.90 state=5 in_game=0.0`; last host line `L510190 [20:05:37] [order] PUO type=11 tgt=0 abil=1269`; **crash 20:05:38** — Windows **1000** same signature; WER **1001 @20:05:41**; dump **`dota2.exe.25052.dmp` 6.71 GiB (7.20 GB dec) @20:06:56**; stages log **4,895,161 B @20:05:37**.
- **`resize begin` / `resize hr` / `release-refs` lines: counts = 0 — ABSENT in the whole log** (developer contract expected them at horn; per contract this must be reported to Lead/reviewer — next build adds slots 10/14 pass-through logging + cached-RTV=1 discriminator).
- **Verdict: v4g FAIL — 2 horn crashes, identical P0 NV signature.** Decoder selftest PASS (rbLen=10, no prologue mismatch), ResizeBuffers1 disabled by default as specified; **second crash occurred with mask=0 (hook-only, no draw submissions)** ⇒ hook/process presence alone insufficient is implicated at the horn transition, not our draw/Present submission path. This strengthens the overlay-coexistence/hook-presence line (Steam overlay enabled in v4g window by design).
- Dumps retained (6.59 GiB + 6.71 GiB); prior dumps 25604 6.92 GiB / 8856 6.98 GiB also retained.

---

# (staged setup below retained)
Artifact: `src\host16_new_v4g.dll` **779,264 B md5 B5928291C1A0A66AB8124620525D1F5D** (PDB 8,089,600 / MAP 1,203,890 retained); sources pinned per `src\host16.dll.md5.txt` (render11 56,541 B md5 **1B2934D2FCDD6D305512BA15E83BC7F9**, v4f→v4g decoder-only fix). **No rebuild needed** (reviewer PASS(conditional)).
Window type: **overlay ENABLED by design** (do not disable Steam overlay for v4g). `R11_DRAW_MASK=7`, `R11_CACHED_RTV=0` (default), `R11_MT_PROTECT=1` (default), stage trace ON, **do NOT set `R11_RESIZE1_HOOK=1`** (ResizeBuffers1 hook disabled by default this build).

## CORRECTED self-test contract (developer provenance correction 19:45:12)
- **EXPECT: `decoder selftest ok=1 rbLen=10 rb1Len=15 negRejected=1` — rbLen=10 is PASS.**
- `rbLen=12` or `16` ⇒ decoder drift ⇒ **INVALIDATE the run**.
- Then expect: `swapchain vtable probe getDescSlot=12 resizeSlot=13`; `hook ResizeBuffers slot=13 addr=…` with **NO `prologue mismatch` line**; `ResizeBuffers1 hook disabled by default`.
- At horn expect: `resize begin old=WxH new=WxH …`, `resize hr=0x0 …`, `release-refs tid=… present=… skip=0`.
- **ABORT/INVALIDATE run on:** selftest ok=0; any `prologue mismatch`; `release-refs … skip=1`; resize hook addresses absent from log.
- If **no `resize begin`** appears at the horn → report to Lead/reviewer (they'll add pass-through logging for slots 10/14 + `R11_CACHED_RTV=1` discriminator, not in this build).

## Preconditions
- [ ] Lead order + swap to v4g (active md5 must read B5928291…, verify after swap; rollback 422751ED; record previous build)
- [ ] Rotate `D:\hake\lotus\r11_stages.log` **before** the run (delete/rename; fresh log created on v4g init)
- [ ] Steam overlay ENABLED; elevated module archive (`gameoverlayrenderer64` present + version; host16 md5 v4g) → `qa_task26/v4g_modules.txt`
- [ ] `r11_mode.txt` `mode=7 guard=0 modules=1 dump=1`; `run.txt=src\bot_loop.lua` (bot loop; diag helper only for LogModules/DiagDump if needed)
- [ ] LocalDumps armed (`dumps\`, DumpType=2); ONE loop; single-player **Treant** match (2+ horns + **15-min soak**)

## Capture checklist
- [ ] `decoder selftest …` line (verbatim; rbLen=10 PASS) + any `prologue mismatch` (must be none)
- [ ] `swapchain vtable probe …` + `hook ResizeBuffers slot=13 addr=…` + `ResizeBuffers1 hook disabled by default`
- [ ] `R11_LogModules`/`R11_DiagDump` output (host16 md5 B5928291…; `modules drawmode mask=7 guard=0 cachedRtv=0 mtProtect=1 stageTrace=1 restoreRt1=0`)
- [ ] `[r11] multithread protected already=… now=…`
- [ ] horn line(s) + **`resize begin`/`resize hr`**/`release-refs … skip=0` at horn
- [ ] `r11_stages.log` tail (last `stage=` frame); `present hr=/devRemoved=`; skip categories; Lua errors
- [ ] Windows 1000/1001; screenshots horn/~1 min; dump path on crash
- [ ] 2+ horns + 15-min soak survive; archive stages log at end

## Verdict logic
- Run valid + 2 horns + 15-min soak survivable ⇒ v4g gate candidate (task-26 still REJECT until failing stage identified per original gate wording, but resize-hook path validated).
- Crash ⇒ keep PDB dump + stage tail + last `stage=`; report Lead+reviewer+pm.
- Any invalidation condition ⇒ stop run, report exact line; do not interpret.