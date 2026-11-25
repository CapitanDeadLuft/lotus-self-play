# v4 A0 RUN — v4c mask 7 + Steam overlay DISABLED (staged; execute on Lead "swap/human ready")

**ATTEMPT LOG — 19:22 candidate pid 15264 = INVALID A0 PROCESS (overlay renderer still loaded):**
- pid 15264 (started 19:20:19) not injected (host16 absent), host.log frozen 19:16:45, no inject_result — pre-inject state correct.
- **Elevated enumeration** (`qa_task26/a0_modules.txt` / `a0_modules_full.txt`, 163 modules): **`gameoverlayrenderer64.dll` base=… size=1,912,832 **ver=11.23.65.88 STILL LOADED**; `nvwgf2umx.dll 32.0.15.9159`, `d3d11/DXGI 10.0.19041.5794`. ⇒ **A0 condition NOT met** (overlay must be ABSENT). `gameoverlayui64` pid 26908 still present too.
- Actions: asked Lead/human to disable Steam Overlay BOTH globally (Settings → In-Game) and per-game (Properties → General) then **fully exit & restart Steam + Dota**; QA re-verifies renderer ABSENT before telling Lead "A0 ready".
- `r11_stages.log` A1 file archived/rotated → `qa_task26/r11_stages_A1_191645.log`; fresh log will be created on next v4c init. `r11_mode.txt` = mode=7/guard=0.

Artifact: active `src\host16.dll` **772,608 B md5 43294478528D0CF1FA8145D43D5771E9** (v4c) — same as A1.
Overlay target state: **Steam In-Game Overlay DISABLED** (Steam → Settings → In-Game → "Enable the Steam Overlay while in-game" OFF; per-game Properties override too), then **restart Dota**.

## ENV (must be set BEFORE Dota2 launch — DLL reads getenv once at first Present; no live setter)
**Launcher shell (Lead/developer owns launch):**
```
$env:R11_DRAW_MASK = 7
$env:R11_CACHED_RTV = 0
# overlay disabled in Steam; then start dota2 and inject (exact launch method per Lead/dev)
```
No other overrides. Defaults: stage trace ON (1), MT protect 1, guard 0. Rotate `D:\hake\lotus\r11_stages.log` before the run.

## Verification lines (host.log, mandatory)
1. `R11: diag env mask=7 guard=0 cachedRtv=0` — confirms env read.
2. `R11: multithread protected already=… now=…` — must be `now=1`; abort/report if UNAVAILABLE/now=0.
3. Run `run.txt = src\diag_r11_mode.lua` after injection (defaults now include `modules=1`, `dump=1`) → expect:
   - `R11: modules host16 … md5=43294478528D0CF1FA8145D43D5771E9`
   - **`modules gameoverlayrenderer64.dll NOT LOADED`** (A0 expected; if loaded, A0 invalid → stop)
   - `modules nvwgf2umx.dll … version=32.0.15.9159`, `d3d11/dxgi 10.0.19041.5794`, GameBar `NOT LOADED`
   - `modules drawmode mask=7 guard=0 cachedRtv=0 mtProtect=1 stageTrace=1 restoreRt1=0`
4. `R11: diagdump …` follows.

## Preconditions (QA, elevated checks required)
- [ ] Human disabled Steam overlay + restarted Dota/lobby.
- [ ] **Elevated** enumeration of new Dota pid: `gameoverlayrenderer64.dll` **ABSENT**; `host16.dll` **present** with md5/version of v4c; record full filtered lines to `qa_task26/a0_modules.txt`.
- [ ] **Save the FULL elevated module-list file** (same style as `run0_modules.txt`, all modules + versions/paths) to `qa_task26/a0_modules_full.txt` — this is the evidence that `gameoverlayrenderer64` is ABSENT while `host16` v4c (43294478…) is present. Archive both files.
- [ ] No `gameoverlayui64` overlay window (optional note).
- [ ] `r11_mode.txt`: `mode=7` / `guard=0` / `dump=1`; `run.txt=D:\hake\lotus\src\diag_r11_mode.lua`; loop started by injected run.txt after injection (Lead drives swap/inject; QA does not kill/inject until told).
- [ ] Rotate `D:\hake\lotus\r11_stages.log` before injection/loop; LocalDumps armed (`dumps\`, DumpType=2).

## Capture checklist
- [ ] `[r11] multithread protected already=… now=…` (mandatory; if UNAVAILABLE/now=0 → flag, A0 untestable in this config)
- [ ] `R11: diag(first=…)`/first frames: hud/menu/open/est/verts/cap/drew/mapOk
- [ ] horn line(s): `[clock] anchor … / src=horn gt=… gs=… state=4 in_game=0.0` + last `[order]` line
- [ ] `r11_stages.log` tail after run (last frame pipeline; rotated per run) → copy to `qa_task26/stages_A0.log`
- [ ] `present hr= / devRemoved=` lines; `R11: skip` category counts; Lua errors
- [ ] Windows Application 1000/1001 (no new dota2/nvwgf2umx/0xC0000409) after run
- [ ] Screenshots at horn + ~1 min (`qa_task26/a0_horn_*.png`, `a0_1min_*.png`)
- [ ] **2+ horns** survived (target); if crash → dump path + last `stage=` line + report

## Verdict logic
- **A0 survives 2+ horns** ⇒ overlay coexistence confirmed as trigger; **then keep the match running an extra ~5+ min (total ≥15-min soak proxy) before switching anything** (Lead/gate permits); product fix candidate = detect Steam overlay and skip/defer in-match draw with explicit log/notice; gate on overlay-disabled candidate (task-26 stays REJECT until failing stage identified AND mode-3 survives 2+ live horns).
- **A0 crashes** ⇒ our draw path alone reproduces P0; proceed mask ladder **0 hook-only → 1 state-only → 2 HUD-no-world** with same capture.