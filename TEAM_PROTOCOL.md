# Team protocol — autonomous Self Play port crew

The human is away. The team must self-organize: plan → build → review → test → record → next item.
Read `D:\hake\lotus\PORT_BRIEF.md` first (architecture, paths, offsets, build/launch commands).

## Roles and write scopes (strict — never write outside your scope)
| Role | Agent | May write | Must not touch |
|---|---|---|---|
| Architect | `architect` | `D:\hake\lotus\PLAN.md`, `D:\hake\lotus\ARCH_DECISIONS.md`, shared task board | all source files, runtime files |
| PM (Orchestrator) | `pm` | `D:\hake\lotus\PM_STATUS.md`, shared task board | all source files, runtime files |
| Developer | `developer` | `src/render.lua`, `src/overlay.lua`, `src/menu.lua`, `src/render11.cpp`, `src/host.cpp`, and any `src` file not owned by a specialist | `run.txt`, `stop.txt`, Dota process, review/plan docs |
| Specialist: API | `api-core` | `src/api.lua`, `src/diag_api_probe.lua` | everything else |
| Specialist: loader/events | `loader-events` | `src/loader.lua`, `src/diag_events.lua` | everything else |
| Specialist: orders/nav | `orders-nav` | `src/orders.lua`, `src/nav.lua`, `src/diag_orders.lua` | everything else |
| Reviewer | `native-render` | `D:\hake\lotus\REVIEW.md` | all source files, runtime |
| QA Tester | `ui-hud` | `QA_REPORT.md`, `run.txt`, `stop.txt`, Dota launch/inject, `src/diag_*.lua`/`test_*.lua`/`synth_*` | product source files |

Only ONE member may restart Dota / rebuild the DLL / re-run scripts: **QA (`ui-hud`)**. Specialists and the developer prepare and compile, then ask QA for a runtime window. Specialists are the only writers of their files; the Developer covers the rest.

## Runtime control (QA only)
- Rebuild native: see brief. Then relaunch: kill dota2, `Start-Process 'steam://rungameid/570'`, wait ~95s,
  inject `D:\hake\lotus\src\inject_elevated.bat <pid>`, then write `run.txt` with a script path.
- Re-run scripts without restart: `Set-Content D:\hake\lotus\run.txt '<script path>'` (watchdog re-runs in-process).
- Stop a running loop: write `D:\hake\lotus\stop.txt`, wait for `=== BOT LOOP done ===` in host.log, delete it.
- Never run two loops at once. Before a runtime window, announce it to the PM (message) and record it in QA_REPORT.md.
- Logs: `D:\hake\lotus\host.log` (loader/runtime), `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\self_play.log` (bot's own log).
- Synthetic input is elevated-only: `D:\hake\lotus\src\synth_click_elevated.bat X,Y`.
- NOTE: a real match needs a human or the bot's own matchmaking; for tests prefer watching the bot in whatever
  match is available (previous session left the account able to play vs bots through the menu) and the lobby
  for load-time checks. If no match is available, test what can be tested and report the gap.

## Work cycle (repeat until no items left or blocked)
1. **Architect**: pick the highest-impact gap from the audit/plan, write it as a concrete task on the shared board
   (`team_task_create`) with acceptance criteria and file scope, then message `developer` and `pm`.
2. **Developer**: claim the task, implement, syntax-check/compile, message `reviewer` (with file list + what to check)
   and `qa` (with what to run and what evidence is needed).
3. **Reviewer**: review the actual diff of the files (read them), check for correctness, perf, crashes, race conditions;
   PASS or REJECT with concrete reasons; write verdict in `REVIEW.md`; message `developer` (and `pm`).
4. **QA**: run the evidence step, capture log excerpts, write `QA_REPORT.md` entries; message `pm` with PASS/FAIL + evidence.
5. **PM**: update the board (complete/reopen), log status in `PM_STATUS.md`, choose the next item, keep the cycle alive.
   Message the Lead (`lead`) with a compact status every cycle (what shipped, evidence, next).

## Quality bar
- No guesses presented as facts: every claim needs a log line, a dump, a screenshot, or a test.
- Lua changes: `luajit -e "loadfile(...)"` must pass before asking for a runtime window.
- Native changes: `cl` must compile before asking QA to restart.
- Never leave the bot loop running with a broken script: if a reload errors, restore the previous file content and report.
- If a change makes the bot worse in-match, revert it and record why in PM_STATUS.md.

## Escalation
- Blocked >20 minutes on the same issue → message `pm`; PM decides (revert, alternate approach, or skip item).
- Hard blocker (game update, offsets changed, missing data) → message `lead` with the concrete blocker and evidence.