# v4 RUN 0 — PLAIN Dota control (NO host16 injection)

Started: 2026-11-17 18:24:08 (dota2 pid **21788**, QA-verified NOT injected: no `host16` module in process; host.log frozen 18:14:39; no `inject_result`; `run.txt=bot_loop.lua`; no `stop.txt`; no watchdog/loop markers).
Runtime owner: QA. Purpose: decisive crash control — plain Dota at horn, 2+ horns, LocalDumps armed.

## Pre-run environment notes (QA)
- Active `host16.dll` on disk: 422751ED (lobby-only; NOT loaded in pid 21788).
- First screenshot `run0_01_start.png` (18:24:41) showed a **Windows dialog "Вам понадобится новое приложение, чтобы открыть эту ссылку ms-gamingoverlay"** over the Dota main menu (plus a Dota Plus battle-report popup behind it).
- Dialog dismissed by QA at 18:24:53+ (elevated PostMessage WM_CLOSE sweep) → `run0_02_dialog_dismissed.png`, `run0_03_after_close.png` (main lobby restored).
- **⚠ CORRECTION — overlay state must be read ELEVATED.** Medium-integrity `Get-Process dota2 | Modules` gave a **false negative** (high-integrity process hides modules). Elevated enumeration (`qa_task26/run0_modules.txt`, 183 modules) shows:
  - **`gameoverlayrenderer64.dll` ver 11.23.65.88 IS LOADED** in pid 21788 (`C:\Program Files (x86)\Steam\gameoverlayrenderer64.dll`) → **Steam overlay IS ACTIVE in-process** (valid 0a control).
  - **`host16` module: ABSENT** (also no host.log writes/watchdog/inject_result) → plain Dota confirmed.
  - `nvwgf2umx.dll` 32.0.15.9159 loaded (driver); `d3d11.dll`/`DXGI.DLL` 10.0.19041.5794.
  - Overlay component versions on disk: GameOverlayRenderer64.dll **11.23.65.88**, gameoverlayui.dll 11.23.65.88, GameOverlayUI.exe 10.41.26.25.
- No runtime injection/swap performed. Match start requires **real mouse/human** (synth path is DLL-dependent; Run-0 is un-injected).

## Match timeline (plain Dota, overlay ACTIVE, no host16)
- ~18:28:22: human started match; first observed screenshot `run0_04_ingame_013.png` at 18:28:35 shows **in-game clock 0:13, hero Treant Protector** → match is live, **horn passed** (≈18:28:22).
- 18:29:17: pid 21788 responding, **host16=absent**, overlay renderer present, **no new Windows 1000/1001** (latest remains the prior injected crash 18:14:40).
- 18:30:08: elevated re-check — `pid=21788 modules_total=183 gameoverlayrenderer64.dll ver=11.23.65.88 LOADED, host16=[]` (file `run0_modules_now.txt`); still no new crash events.
- **0a EARLY VERDICT (subject to soak/2nd horn): plain Dota + overlay ACTIVE + no host16 SURVIVES the first in-match horn** (≥2 min at last check) — contrast with every host16-injected run crashing ~1 s after horn ⇒ overlay alone does not reproduce P0; host16 interaction implicated.
- [ ] 2nd horn / second match still to observe (Lead plan instead moved to A1-first swap; 0a recorded as survivor-so-far)
- [ ] later Windows 1000/1001 re-check + soak
- NOTE: screenshot capability limited while human is in Discord foreground (QA elevated helper windows also steal focus); capture when Dota is foreground.

## Lessons recorded
- **Module enumeration for high-integrity Dota MUST be elevated** — medium-integrity `Get-Process | Modules` returns 0 for these modules (false negative); use elevated enumeration and archive the line.
- Steam overlay renderer was actually ACTIVE during 0a (`gameoverlayrenderer64.dll 11.23.65.88`), so 0a is a valid overlay-active plain-Dota control (not renderer-absent).

## Capture checklist (fill as the run progresses)
- [ ] human starts single-player **Treant** match (ИГРАТЬ ПРОТИВ БОТОВ → ОДИНОЧНАЯ)
- [ ] screenshot at match start / horn (in-game clock 0:00) → `run0_horn_*.png`
- [ ] 2+ horn/state transitions observed (second match or second horn)
- [ ] Windows Application 1000/1001 checked after each horn (no dota2/nvwgf2umx/0xC0000409 ⇒ clean)
- [ ] crash? (yes/no) — if yes: dump path under `D:\hake\lotus\dumps`, event rows, screenshot
- [ ] verdict: plain-Dota crash at horn ⇒ game/driver fault independent of overlay; clean through 2+ horns ⇒ overlay interaction implicated

## Result
**RUN-0 (0a) = PASS (overlay alone insufficient).** Plain Dota pid 21788, host16 absent, Steam overlay ACTIVE in-process (`gameoverlayrenderer64.dll 11.23.65.88`, elevated 183-module enumeration), match started ~18:28:22 with Treant; process responding and **no new Windows Application 1000/1001** at 18:29:17, 18:30:08, 18:32:49 and **18:33:42 (≈5.3 min past horn)**. Latest fault events remained the prior injected crash (18:14:40/18:14:44).
**FREEZE 18:34+:** user instructed hands-off (he will play Dota himself). No further runtime actions (no injection/kill/relaunch/loop/input/screenshots). State left as observed; v4b artifact CDBAF472, rollback DLLs 422751ED/1AB3D773, `r11_stages.log` (absent) and dump `dota2.exe.25604.dmp` (6.92 GiB) untouched.
**Resume only on explicit Lead/user "continue":** A1 (v4b mask 7 + overlay ENABLED, expected crash) → A0 (v4b mask 7 + overlay DISABLED, elevated-verify renderer absent, expected survive) → mask ladder 0/1/2 if A0 crashes; per-run capture per `v4_run_matrix.md`.