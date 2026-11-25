# v4 A1c RUN — v4c mask 0 (HOOK-ONLY) with Steam overlay ENABLED (staged; execute on Lead go)

Purpose: hook presence vs draw calls — mask 0 = no D3D calls from our draw path (hook-only). Can be set LIVE via `r11_mode.txt` (`mode=0`) — **no Dota relaunch / no env restart needed**; Steam overlay stays ENABLED (record overlay state).

## Preconditions
- [ ] v4c active (`host16.dll` 772,608 B md5 43294478528D0CF1FA8145D43D5771E9) and injected; ONE bot_loop running.
- [ ] Rotate `D:\hake\lotus\r11_stages.log` (delete/rename old; fresh created on next v4c init if relaunching; if no relaunch, note appended file).
- [ ] `r11_mode.txt`: `mode=0` / `guard=0` / `modules=1` / `dump=1`; `run.txt = D:\hake\lotus\src\diag_r11_mode.lua` (md5 9BA656AAE65CC44A278315C61F039D32) — executes via host run.txt in fresh Lua state; forces `R11_SetDrawMode(0)` live.
- [ ] Steam overlay ENABLED; record elevated module list (`gameoverlayrenderer64` present/version + host16 md5) to `qa_task26/a1c_modules.txt`.

## Capture
- [ ] `[qa-r11] config mode=0 …` + `[qa-r11] R11_SetDrawMode(0) called` + `R11_LogModules()` output (must show `modules drawmode mask=0 … mountProtect=1 stageTrace=1 restoreRt1=0` — mask=0 proof)
- [ ] `R11: multithread protected already=… now=…`
- [ ] `[r11] skip frame reason=resource-null` etc. — mask 0 may log "skip draw" reasons by design; record categories/counts
- [ ] `present hr= / devRemoved=` (mask-0 runs: `devRemoved=0x80004005` BY DESIGN — ignore)
- [ ] `r11_stages.log` tail: with mask 0 expect minimal/no draw stages — record exact last lines
- [ ] horn line(s) + screenshots (horn, ~1 min); Windows Application 1000/1001; dump if crash
- [ ] **2+ horns** target; if survives → hook-only is safe path (draw calls implicated); if crash → hook/RenderThread interaction implicated independent of our draw submissions

## Verdict logic
- A1c survives 2+ horns (mask0) where A1 crashed (mask7) ⇒ our **draw path** (upload/state/present subpath) implicated.
- A1c crashes too ⇒ hook presence itself (or state capture) sufficient — next: A1b restore-1 / MT / mask1 state-only comparisons.