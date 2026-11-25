# task-26 — Native rebuild window — QA EVIDENCE TEMPLATE (v3 GATE CANDIDATE)

Owner: QA (`ui-hud`). ONE runtime owner = QA. No crew restarts without Lead.
v3 artifact built 17:57:16 from ORDER-FIX source; reviewer fast re-sign pending; **Lead owns kill pid 9204 + swap GO**.
Fill every field; paste final rows into `QA_REPORT.md` (D14) with line-index attribution. **v2 block stays NON-GATE.**

## 0. Preconditions (v3)
- [x] QA verify: `src\host16_new.dll` **189440 B @17:57:16 md5 CB0ED3F4D9E07271DD59A154D03DDE9A** (differs from 65A35E48/8B246867)
- [x] Source: `src\render11.cpp` **38215 B @17:57:03 md5 CAAF6827BD2669A65BA2AB3181355777** (+ host.cpp 23009 B md5 EBA76DD3…)
- [x] `host16.dll.md5.txt` has V3 build record (source/compile/contains=order fix + diag fields, swap/pending, rollback)
- [ ] Reviewer fast re-sign PASS (pending)
- [ ] **Lead GO** for kill pid 9204 + swap (QA does NOT kill/swap)
- [ ] Developer confirms artifact final before swap

## 1. Hash bookkeeping (fill at swap)
| item | size | mtime | md5 |
|---|---|---|---|
| active v2 (deadlock) host16.dll | 188928 | 17:52:28 | 65A35E4883797CCD8BA1CA32E1C77551 |
| **v3 artifact host16_new.dll** | 189440 | 17:57:16 | **CB0ED3F4D9E07271DD59A154D03DDE9A** |
| new active host16.dll (after swap) | | | (must = CB0ED3F4…) |
| rollback 1 host16.dll.bak_20261116_205629 | 185344 | 2026-11-16 | 422751ED3DABB466564B1A6F0EAC35 |
| rollback 2 host16.dll.bak_20261117_174938 | 185856 | 2026-11-16 20:57:18 | 1AB3D7734E6A6F02FFC72DA11E384342 |
| v2 backup (create at swap) | 188928 | | 65A35E48… |

## 2. Synthetic input (fixed)
```
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\hake\lotus\src\synth_key.ps1" -Keys 0x2E -HoldMs 80
```
elevated/admin; `0x2E` = Del. Success: `[r11] frame` shows `open=0→1`. (Old `.bat` was broken — missing `-HoldMs` arg caused PowerShell binding error + zero keys; stale `synth_key_result.txt` is NOT delivery evidence.)

## 3. Window protocol
1. Lead/dev stop loop + kill pid 9204 (QA does not kill/swap) → developer swap v3 + verify active md5 **CB0ED3F4…**; QA confirms file hash after swap.
2. QA relaunch `steam://rungameid/570` → inject via `src\call_elevated.bat <pid>` → record `inject_result` + `host: watchdog thread start pid=<pid>`.
3. **FIRST-FRAME PREREQUISITE (v3 gate):** expect
   - `[r11] init ok sw=1920 sh=1080`
   - **`diag(first=1)` line with `cap>0` AND `verts>0`** (v3 prints first 5 frames immediately: `hud menu open est verts cap vbB drew mapOk` + counters init/bb/cmd/res/ens/mapfail)
   - within ≤2 s `[r11] frame … cap= est= verts= drew= mapOk=`
   **ABORT the soak and send the exact line to developer if `cap` stays 0 or `verts==0` on `diag(first=1)`** (different defect).
4. Start ONE `bot_loop`; record `host: running`, `=== BOT LOOP ===`, `[perf] load`.
5. **PRIMARY gate — in-match HUD soak:** normal match (Treant), **menu CLOSED**, `hud≥50 cmds`, **≥5 min continuous drawing**; require every `[r11] frame` line `verts ≤ cap`; zero skip lines among `skip vert overflow` / `skip draw reason=vb-size` / `resource-null-after-cap` / `map-fail` / `resource-null` / `cmd-count` / `non-tri`; **no new nvwgf2umx 0xC0000409** in Application log; overlay visible (HUD screenshots `qa_task26/hud_XX.png`).
6. **SECONDARY — menu/Del stress:** fixed synth Del **10–20×**, each open **≥5 s**, widget clicks + hover; minutes continuous menu-open. Require `open=1 && menu>0 → verts>0` + visible ClickGUI screenshot (`qa_task26/menu_XX.png`). **If `cap>0` but `verts=0` with menu open → REJECT** (reviewer).
7. Normal-match soak; keep the match for the **role/last-hit Carry test if the menu renders**.
8. **Record verbatim:** `diag(first=1..5)` lines; last 20 `frame` lines; skip-line count (and any lines); WinEvent check; **max verts / max cap** overall.
9. Windows event log: `Get-WinEvent -LogName Application` IDs 1000/1001 — no new dota2.exe/nvwgf2umx/0xC0000409 after relaunch.
10. **Rollback if violated/crash:** stop → restore **`host16.dll.bak_20261116_205629` (422751ED…)** first, else `host16.dll.bak_20261117_174938` (1AB3D773…); record + report; no blind retry.

## 4. PASS criteria (v3 gate)
- [ ] `diag(first=1)` has cap>0 AND verts>0; first frame line shows cap>0
- [ ] every frame `verts ≤ cap`; zero skip lines (all categories)
- [ ] HUD soak ≥5 min in-match menu-closed hud≥50: crash-free, overlay visible
- [ ] menu: `open=1 && menu>0 → verts>0`, ClickGUI visible on screenshot, widgets clickable
- [ ] no new nvwgf2umx 0xC0000409
- [ ] diag/frame/skip/WinEvent/max-verts-cap rows pasted with line indices
- [ ] one loop only; screenshots index updated

## 5. Screenshots index
| file | description |
|---|---|
| qa_task26/ | add hud_XX.png (HUD soak), menu_XX.png (Del/menu visible), soak_XX.png |