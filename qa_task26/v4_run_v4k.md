# v4k RUN — Window #2 (vtable mode, overlay ENABLED) — pid 16584 — **INVALID (v4k INVALIDATED)**

**STATUS: INVALID** — `tier0.dll` AV `0xc0000005 @0xaeb60` at horn (01:03:11 → crash 01:03:12); **NV signature absent / mechanism proven**, but v4k invalidated; **root cause unproven**. Dump retained, no cleanup. v4i remains blocked on v4l (`g_qcs` uninit under `R11_NO_HOOKS=1`).

**REVIEWER REVIEW.md 01:20 — v4k = FAIL:** NV signature **and** `__report_gsfailure` both **absent** ⇒ **mechanism + GS fix hold**; new **`tier0.dll+0xaeb60` AV** with **`rcx=0x020b2712` (wild)** and **no host16 frame**; dump 16584 retained.
**Exact exception (dumps\v4k_crash_16584.txt):** `(40c8.1cb8): Access violation c0000005`; `tier0!CKeyValues_Data::Internal_GetName: mov rax,qword ptr [rcx+8] ds:00000000`020b2712`?`; registers `rcx=0x020b2712` (garbage), **`r14=000002735ceecfd0` = the patched swapchain pointer** (`sc` from our vtable line), `rdi=000005affad94000`; module tier0 has no host16 frame above it (engine crash-handler/KeyValues path) ⇒ likely **secondary corruption of engine state**, not direct host16 call.
**Baseline restore verified (QA file-only):** active `src\host16.dll` = **422751ED3DABB466564B1A6F4E0EAC35** (185,344 B); v4k archived `host16.dll.v4k_20261118_010603`; md5.txt `[20261118_010603] after v4k window: baseline 422751ED restored … v4k window=FAIL tier0 AV at horn (NV+GS gone)`. (PM note said disk currently v4k — actual disk is already baseline 422751ED.)

Artifact: `src\host16.dll` **FE34518FB6B217791FF5C5E3B74287ED** (786,432 B; v4k stack-safety delta over v4j). Mode line still prints `vtable(v4h)` (same vtable architecture). **Symbols for dump `dota2.exe.16584.dmp`:** `src\host16_new_v4k.pdb` **8,097,792 B @00:59:18** + `host16_new_v4k.map` **1,211,472 B** (same mtime as DLL — matching build; v4j PDB only partially matches).

## Live evidence captured (line-index, host.log)
- Injection/init:
  - `L511450 [01:00:50.338] host: hook mode=vtable(v4h)`
  - `L511455 [01:00:50.413] host: resize inline hooks not installed in v4h mode (no code patching during match)`
  - `L511523 [01:00:50.757] host: hook target=gameoverlayrenderer64+0x9c130 addr=00007FF864A1C130`
  - `L511524 [01:00:50.757] host: vtable present patched sc=000002735CEECFD0 slot=8 old=DXGI+0x18c0 new=host16+0xaab0 entries=48 present-tid=7352`
  - `L511525 inline patch restored ok=1 target=gameoverlayrenderer64+0x9c130 addr=00007FF864A1C130 len=10 nonzeroSnapshot=1 bytes=48 89 5C 24 08 48 89 6C 24 10`
  - `L511526 inline patch absent ok=1 target=00007FF864A1C130 len=10`
  - `L511528 R11: modules host16 … md5=FE34518FB6B217791FF5C5E3B74287ED`
  - `L511537 R11: modules drawmode mask=7 guard=0 cachedRtv=0 mtProtect=1 stageTrace=1 restoreRt1=0 resize1Hook=0`
  - `L511539 R11: multithread protected already=0 now=1`; `L511555 R11: init ok sw=1920 sh=1080`
- **Repeated `inline patch absent recheck ok=1 target=00007FF864A1C130 len=10`** every ~12 s: L512115 01:00:59, L512605 01:01:06, L513592 01:01:20, L515080 01:01:41, L516222 01:01:59, L516891 01:02:09, L517414 01:02:18, L518208 01:02:30, L520080 01:03:00, L520648 01:03:09.
- In-match (pre-crash): `R11: frame tid=7352 hud=39 menu=79 open=0 est=910 verts=786 cap=14972 vbB=299440 drew=1 mapOk=1 | init=0 bb=0 cmd=0 res=0 ens=0 mapfail=0 sw=1920`; `R11: present tid=7352 hr=0x00000000 devRemoved=0x00000000 f=… mask=7 mt=1`; stages (`r11_stages.log`) mask=7 pipeline `draw→statecopy→upload(drew=1 mapOk=1)→restore→exit→present` with hud=39 menu=79 verts=786 cap=14972.
- Horn: `01:03:11 [clock] anchor: observed state transition <4 -> 5 at gs=145.267` → `[clock] src=horn gt=145.27 gs=145.27 state=5 in_game=0.0`; last host line `01:03:11 [order] PUO type=11 tgt=0 abil=1287 unit=npc_dota_hero_treant`.

## CRASH (new signature)
- **Windows Application Error 1000 @01:03:12**: `dota2.exe` faulting module **`tier0.dll`** (Valve module; version 0.0.0.0, timestamp 0x6ad13ce5) — **exception `0xc0000005` access violation**, fault offset **`0x00000000000aeb60`**, failing pid `0x40c8` (=16584).
- WER **1001 @01:03:15** (container type 5, `AutoVerifierV2`, CAB id 0).
- **Full dump captured:** `D:\hake\lotus\dumps\dota2.exe.16584.dmp` **7,958,398,411 B @01:04:46 final** (was 0 B mid-write at 01:03:16). Retained; **no cleanup**.
- host.log frozen **28,266,973 B @01:03:11**; `r11_stages.log` frozen **10,418,962 B @01:03:11**.
- Archived copies (no cleanup of originals): `qa_task26\host_v4k_crash_20261118_0103.log` (28,266,973 B), `qa_task26\r11_stages_v4k_crash_20261118_0103.log` (10,418,962 B).
- Post-crash: new dota2 process **pid 6396** appeared (user/Steam relaunch; not injected by QA — observer only); old 16584 exiting/not responding (WER).

## VERDICT — v4k CRASH ⇒ INVALIDATE v4k per rule
- **NV driver signature (nvwgf2umx 0xc0000409) absent** (vtable chaining holds), but a **new crash signature appeared: `tier0.dll` AV 0xc0000005 @+0xaeb60 exactly at the horn transition** — third distinct fault across windows (NV → host16 GS-cookie in PresentCore (v4h) → tier0 AV (v4k)).
- tier0.dll is Valve's crash/logging runtime — this may be a **secondary corruption path** (crash handler/assert path) rather than a new root cause; **root-cause-not-proven** diagnosis path per reviewer. **v4k trust invalidated**; do not use v4k for gate; v4i blocked on v4l (`g_qcs` uninitialized under `R11_NO_HOOKS=1`).
- **Anomaly report required:** Lead+reviewer+pm notified; keep dump/logs untouched for analysis; v4j PDB only partially matches v4k (stack-safety-only delta) — v4k PDB/MAP should be used for 16584 dump symbolization; request from developer if missing.
- No screenshots taken (freeze rules); HUD/overlay visibility evidenced by in-match frames `hud=39` + Steam overlay renderer loaded (see module line at injection? capture if needed from log).