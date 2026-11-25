# Self Play port — shared team brief (read first)

Goal: run the ORIGINAL Lua "Self Play" Dota 2 bot on our own loader with behavior **exactly**
like the original (Umbrella/Melonity host). No Umbrella, no Themida, no HWID.

## Layout
- Our loader source: `D:\hake\lotus\src\`
  - `host.cpp` — in-process watchdog + Lua host + DXGI Present hook (includes render11.cpp)
  - `render11.cpp` — D3D11 in-game renderer (HUD + ClickGUI + world markers), input hooks
  - `overlay.lua` — publishes HUD/ClickGUI draw commands + hits to render11, handles clicks
  - `menu.lua` — Umbrella-compatible Menu/Widget classes (script builds ClickGUI through this)
  - `render.lua` — Umbrella-compatible Render namespace (Text/Line/Rect/Circle/WorldToScreen...)
  - `api.lua` — Umbrella-compatible API surface (Entity, NPC, Hero, Player, GameRules, Engine,...)
  - `loader.lua` — globals/stubs, real overrides, event synthesizer, script load + tick
  - `orders.lua` — PrepareUnitOrders pipeline (real order issuing)
  - `bot_loop.lua` — dev driver: loads Self Play, enables switches, ticks loop
  - helper scripts: `open_menu.lua`, `diag_*.lua`, `inject_elevated.bat`, `call_elevated.bat`
- Original scripts (installed, UPDATED 16.11.2026): `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\`
  - `Self Play.lua` + `self_play/**` (do NOT edit original script files; they are the reference)
  - backup of previous version: `D:\hake\lotus\backup_scripts_20261116_023749`
- Dota install: `E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\`
- Game data dumps: `D:\hake\lotus\dumper\dota2_dump\client.dll.hpp` (all netvar offsets),
  `D:\hake\lotus\schema_dump.json` (only 15 classes!), `D:\hake\lotus\gamedata\`
- Log: `D:\hake\lotus\host.log` (our side). Bot's own log after update:
  `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\self_play.log`

## Runtime facts
- LuaJIT 2.1 (Lua 5.1). Scripts target Lua 5.4: we provide `utf8.len`, `table.unpack/pack`,
  `math.type/tointeger` in loader.lua.
- Dota client runs **HIGH integrity**: synthetic input must be elevated
  (`src\synth_click_elevated.bat X,Y`, `src\inject_elevated.bat <pid>`, `src\call_elevated.bat <pid>`).
- Injection: `host16.dll` (DllMain starts HostThread that watches `D:\hake\lotus\run.txt`;
  writing run.txt with a script path re-runs it in-process; `D:\hake\lotus\stop.txt` stops loops).
- Lua-only changes: rewrite `run.txt` → hot reload, no Dota restart needed.
- Native changes (`host.cpp`/`render11.cpp`): must rebuild and RELAUNCH Dota (kills the match).
  Only ONE member may rebuild/relaunch; coordinate with the Lead.

## Build
```
cmd /c "call ""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"" x64 >nul && cd /d D:\hake\lotus\src && cl /O2 /LD /EHsc host.cpp /Fe:host16.dll /link user32.lib gdi32.lib d3d11.lib dxgi.lib ole32.lib d3dcompiler.lib"
```
Launch: `Start-Process 'steam://rungameid/570'`, wait ~95s, then
`Start-Process D:\hake\lotus\src\inject_elevated.bat -ArgumentList <pid> -Verb RunAs -Wait`,
then `Set-Content D:\hake\lotus\run.txt 'D:\hake\lotus\src\bot_loop.lua'`.

## Key engine offsets (this Dota build; refresh per patch)
- PrepareUnitOrders RVA `0x1B5F860`; gamerules global client+`0x6219008` (proxy m_pGameRules@0x5F0)
- viewmatrix `0x6221CB0`; hero scene node `0x330` (absOrigin node+`0xD8`)
- controller order vector `0x9A0`, next seq `0x9B8`; modifier manager `0xE30`; unit state64 `0x12B8`
- inventory `0x11C0`+0x20; network activity `0x18E8`; hero XP `0x1AC4`
- ability: m_bAutoCastState `0x644`, m_flChannelStartTime `0x64C`; item m_bRequiresCharges `0x6C1`
- C_DOTAGamerules m_nGameState `0x7C`, m_flGoldTime `0x578`, m_flCreepSpawntime `0x580`,
  m_flGameStartTime `0x594`; C_DOTA_DataNonSpectator m_vecDataTeam `0x5F0` (DataTeamPlayer_t, stride 0x12F0)
- C_DOTA_PlayerResource m_vecPlayerTeamData `0x608`, m_vecPlayerData `0x670`
- DataTeamPlayer_t: reliableGold `0x30`, unreliable `0x34`, totalEarnedGold `0x3C`, netWorth `0x90`,
  denyCount `0x94`, lastHitCount `0x98`, heroDamage `0x104`, kills-per-enemy-team `0x208[24]`

## Current state / known gaps (as of 16.11.2026)
- Updated Self Play (16.11) installed; script loads cleanly; new Menu labels handled in bot_loop.
- HUD/ClickGUI render in-game via D3D11 with Bahnschrift 400/700, native per-frame world markers.
- Known incomplete: GridNav pathing (approximation), Humanizer order queue (stub), matchmaking
  (GC/protobuf/http missing), some API semantics still approximated. Player.GetTeamData deaths=0.
- `Humanizer.GetOrderQueue` and `GC/NetChannel/HTTP` are stubs → matchmaking/queue features can't work.

## Rules
1. Never edit files under `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\` (reference only).
2. Only touch files in your assigned write scope. Never rebuild native DLL without Lead's go-ahead.
3. Verify every change: `luajit -e "loadfile(...)"` syntax check for Lua; for native, build cleanly.
4. Prefer evidence (logs, dumps, screenshots) over guesses. Do not start duplicate bot_loop instances.
5. Report concisely: what changed, why, how verified, remaining risks.