# v4 A1b RUN — v4c mask 7 + `R11_RESTORE_RT1=1` (staged; execute on Lead swap/window)

Purpose: test save/restore cardinality residue (restore only RTV slot 0) with same mask 7 as A1.

## ENV (must be set BEFORE Dota2 launch — DLL reads getenv once at first Present; no live setter)
**Launcher shell (Lead/developer owns launch):**
```
$env:R11_DRAW_MASK = 7
$env:R11_CACHED_RTV = 0
$env:R11_RESTORE_RT1 = 1
# then start dota2 and inject (exact launch method per Lead/dev)
```
No other overrides. Defaults otherwise: stage trace ON (1), MT protect 1, guard 0.
**Rotate `D:\hake\lotus\r11_stages.log` before the run** (always-on, ~14 MB by horn).

## Verification lines (host.log, mandatory)
1. `R11: diag env mask=7 guard=0 cachedRtv=0` — confirms env read (does NOT show restoreRt1).
2. `R11: multithread protected already=… now=…` — must be `now=1`; abort/report if UNAVAILABLE/now=0.
3. Run `run.txt = src\diag_r11_mode.lua` (or the inline ff-load diag) after injection — expect:
   - `R11: modules host16 base=… path=D:\hake\lotus\src\host16.dll md5=43294478528D0CF1FA8145D43D5771E9` (active v4c)
   - `modules gameoverlayrenderer64.dll … version=11.23.65.88` or `NOT LOADED` (record overlay state)
   - `modules nvwgf2umx.dll … version=32.0.15.9159`
   - `modules d3d11.dll … 10.0.19041.5794`, `modules dxgi.dll … 10.0.19041.5794`
   - GameBar entries `NOT LOADED`
   - **`modules drawmode mask=7 guard=0 cachedRtv=0 mtProtect=1 stageTrace=1 restoreRt1=1`** ← ONLY proof the env took effect for A1b. **If `restoreRt1=0` → STOP, re-launch with env fixed, do not interpret the run.**
4. `R11: diagdump init=1 dev=… … frames=… bbRtvs=…` follows.

## Run capture (per-run md5 tracking: v4c 43294478…)
- [ ] host.log tail from injection → crash (or run end)
- [ ] rotated `r11_stages.log` tail: last `stage=` frame + `tid=`, full pipeline lines for the final frames
- [ ] `present hr= / devRemoved=` lines; `R11: skip` category counts; Lua errors
- [ ] Windows Application 1000/1001 (dota2/nvwgf2umx/0xC0000409) — dump name if crash
- [ ] elevated module list/archive (renderer present/absent + host16 md5)
- [ ] LogModules + DiagDump lines pasted verbatim
- [ ] horn line(s) + screenshots (horn, ~1 min)
- [ ] **2+ horns** target; if crash → dump + last `stage=` + report Lead+reviewer+pm

## Verdict logic
- A1b crash at same point as A1 ⇒ restore-1 cardinality not the trigger (post-Present fault persists).
- A1b survives where A1 crashed ⇒ save/restore cardinality residue implicated → product fix candidate around RTV restore path.
- Cross-reference A0 (overlay off) result before concluding.