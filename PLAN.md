# PLAN — Self Play (16.11 original Lua) on our own loader

Owner: `architect` (this file + `ARCH_DECISIONS.md` are architect write scope).
Goal: the ORIGINAL 16.11 `Self Play.lua` plays exactly like it does under Umbrella/Melonity on our loader.
No Umbrella, no Themida, no HWID.

## Hard test rules (from Lead/PM, non-negotiable)
- **Live proof only in a single-player bot game**: Dota menu → Игра против ботов → **ОДИНОЧНАЯ**.
- **Test hero is always Treant Protector (`npc_dota_hero_treant`)**. Evidence from any other hero is invalid.
  Treant is deliberately chosen: `MODIFIER_STATE_ALLOW_PATHING_THROUGH_TREES` exercises the tree-walking path
  in `navigation.treeWalking`, and Leech Seed / Living Armor / Overgrowth / Nature's Grasp exercise
  heal/damage/root/vision branches that a plain hero does not.
- QA is the only member who launches/injects/rebuilds Dota. No human review: every item must be provable from
  `D:\hake\lotus\host.log`, `…\xYjGsPeqoWTEzbif\scripts\self_play.log`, `QA_REPORT.md` excerpts or screenshots.
- Matchmaking/queue/party/HTTP cannot be tested under the single-player rule → backlog only (see P3).

## Evidence base (16.11.2026, current code)
Reference scripts: `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\` (136 Lua files, 2.26 MB, read-only).
API usage counted from all of them (339 distinct symbols; top: `Entity.GetAbsOrigin` 807, `Entity.GetHealth` 312,
`Entity.IsAlive` 232, `NPC.HasState` 150, `GridNav.IsTraversable` 86, `GameRules.GetGameTime` 60,
`GridNav.BuildPath` 22, `Player.PrepareUnitOrders` 34).

Observed defects, each with a log/source anchor:
1. **Purchase orders do not buy anything.** `host.log` has 101×(02:45–03:00 runs) `[order] PUO type=16 tgt=0 abil=0`
   for `npc_dota_hero_treant` while the bot repeats `[SelfPlay buy] magic_stick … own: tpscroll,ward_observer`
   for 2+ minutes without ever acquiring magic_stick (`self_play.log`/host.log). Reference call:
   `self_play/shop.lua:844` passes `itemId` as **both** targetIndex and abilityIndex.
2. **In-match tick latency is seconds, not milliseconds.** 02:45–02:53 Treant bot game: `loop 1 9.7s`,
   `loop 2 12.8s`, `loop 3 7.4s`, `loop 6 8.1s`, `loop 8 385.7s` (host.log lines ~105814–106160). The script's
   whole brain is `selfPlay.OnUpdate` (`Self Play.lua:1955`), so every decision is 7–13 s stale.
   Menu-only runs log `0.0s` ticks → cost is in in-match code path, not the driver.
3. **Navigation is the visible "bot stands still" suspect.** `src/nav.lua` is real A* over live-entity obstacles
   (wired in `loader.lua:140-181` by Lead; offline-tested only). Bug: `nav.lua:147-149` stores `lastRefresh` from
   `GameRules.GetGameTime()` but `nav.refresh()` compares against `os.clock()` (mixed clock domains → rescan every
   tick or never). It models trees/buildings/edge only — no cliffs/high-ground walls — so A* can return paths the
   server refuses, and the hero never reaches waypoint 2+. Never verified in a match.
4. **Event synthesizer cannot drive last-hit/combat.** `loader.lua:379-433` fires only: `OnEntityHurt`
   (`source=nil`, damage=HP delta), `OnNpcDying`, `OnUnitAnimation` (only activity 1502/1503, `castpoint=0.3`,
   `lag_compensation_time=0` hard-coded), `OnEntityDestroy`. Missing entirely: `OnProjectile`,
   `OnLinearProjectileCreate/Destroy`, `OnParticleCreate/Update/UpdateFallback/UpdateEntity/Destroy`,
   `OnUnitAnimationEnd`. Reference requires payloads: `OnProjectile{source,target,moveSpeed,isAttack,ability,handle}`,
   `OnUnitAnimation{unit,castpoint,lag_compensation_time}`, `OnUnitAnimationEnd{unit}`,
   `OnLinearProjectileCreate{source,velocity,origin,distance,handle}`, `OnParticle*{index,fullName,entity,
   entity_for_modifiers_id,controlPoint,position}` (`Self Play.lua:2192-2296`, `last_hit.lua:108-180`,
   `teleports.lua:9-43`). `OnPrepareUnitOrders` reads order type from `ctrl+0x9A0+0x2C` — that is the vector
   *base*, not the first element → garbage; manual-order pause is effectively untested/broken.
5. **Attack-timing API is approximated, which directly caps last-hit accuracy** (the core farm loop):
   `NPC.GetAttackAnimPoint` returns constant `0.45` (`api.lua:360`), `GetAttackProjectileSpeed` 0, and the
   scripts feed these into `last_hit.lua` release/impact prediction; `NPC.GetSecondsPerAttack` uses
   `m_flBaseAttackTime*m_iBaseAttackSpeed` only (no agility/attack-speed modifiers).
6. **Clock is wall-clock anchored, not engine time.** `GameRules.GetGameTime` (`api.lua:630-680`) anchors on
   `m_flGameStartTime` (0x594) + `GetTickCount64`; pause/disconnect/frame stalls drift it.
   All timing decisions (last-hit, respawn, runes, win model) consume it.
7. **No pause awareness**: `GameRules.IsPaused` is `state == 6` (loader.lua:339) but state 6 is POST_GAME
   (`DOTA_GAMERULES_STATE_POST_GAME`), not pause.
8. **Missing-ish API semantics used by the scripts** (soft-stub returns typed defaults — silently wrong):
   `Player.GetTeamData` deaths/assists always 0 (`api.lua:522-534`); `Player.GetAssignedHero(p)` ignores `p`
   and always returns the local hero (`api.lua:448`); `NPC.GetStatesDuration` {} (`api.lua:378`),
   `HasScepter/HasShard` false, `IsVisibleToEnemies` false, `GetBarriers` zeros, `GetGoldBounty*` 0;
   `Hero.GetPrimaryAttribute` 0, `TalentIsLearned` false, `GetLastVisibleTime` 0; `FogOfWar.IsPointVisible`
   always true; `World.GetGroundZ` 128; `Input.IsKeyDown` false; `NetChannel.GetAvgLatency` from unverified 0x948.
9. **Config is in-memory only** (`api.lua:727-740`): win model / last build / localization choices reset on
   every reload (the bot writes them through `Config.Write*`).
10. **UI**: `Render.PushClip/PopClip` are no-ops (`render.lua`) but **NOT a port blocker** — 16.11 Self Play has
    0 calls (only root-level `dominator_autofarm`/`LDfarm`/`units_autofarm` use them). `Render.TextSize` falls
    back to `#text*size*0.5` when `R11_TextWidthW` is unavailable → HUD alignment risk; HUD/menu draw order works
    (R11 `menu=83` cmds in lobby). `hud.lua:300 Render.Rect` error from 02:49 is fixed (render.lua updated 02:50).
11. **Humanizer.GetOrderQueue** returns `{}` (`loader.lua:128`): `creep_block.lua:130` uses it to confirm its
    pending order was accepted; stub makes creep-block always "accepted" → block logic broken.
12. **Matchmaking/GC/protobuf/HTTP are stubs** (`loader.lua:191-199`): `matchmaking.lua`, `queue_account.lua`,
    `party_queue.lua`, `session.lua` cannot work. Untestable under the single-player rule → P3.

### Live single-player Treant match, 20:12–20:14 (current code; invalidated the earlier ranking)
Setup: QA injected at 20:04; bot loop reloaded **mid-match** at 20:12:51 in a Treant bot game.
Anchors: host.log ~288600–290700, `…\scripts\self_play.log` 20:14:05.
- **P0-A clock is contract-wrong, not merely offset.** Umbrella contract: `GetGameTime()` is **absolute** engine
  time; scripts compute `ingame_timer = game_time - GameRules.GetGameStartTime()`
  (`D:\hake\lotus\umbrella_api\gamerules.md`, GetGameTime example; `Self Play.lua:1850`
  `ctx.clock = ctx.now - GameRules.GetGameStartTime()`). Our `api.lua:633-706` returns **elapsed-since-horn**
  in the anchored path, and `estimateClock` (`api.lua:610-628`, unit+0x1ACC) returns a different epoch.
  Live proof: 20:12:20 diag `GameRules gt=175.75 gs=236.37 state=5` (gt<gs is impossible for absolute time) and
  self_play.log `20:14:05 [147:15]` = (9072.1−236.37)/60 → bot clock 147 min while HUD showed 2:23.
- **P0-B bot permanently in "Paused: manual control".** Root cause (developer, verified): `src/menu.lua`
  catch-all widget `__index` returned a truthy table for `ui.pause:IsDown()`, so `Self Play.lua:1860` returned
  early every tick. Fix in `src/menu.lua:119-132`: real `Widget:IsDown()` via `GetAsyncKeyState` (source comment
  cites Self Play.lua:1860).
- **P0-B2 `poll error:` every tick** — host.log 20:12:53–20:14:19:
  `loader.lua:440: bad argument #2 to 'VirtualQuery' (cannot convert 'struct 209' to 'struct 175 *')` → two
  conflicting `API_MBI`/`VirtualQuery` ffi cdefs (loader vs entity/api). The event poll aborts each tick, so
  **no event/callback evidence is trustworthy until this is zero**. Owner `loader-events`, fixed inside the
  P0-B verification window.
- **P0-C purchase defect** confirmed in the same live context (see P0.C below).

## Cycle queue (AUTHORITATIVE — Lead, 16.11 20:2x; supersedes every earlier ordering)
1) **QA baseline + reload evidence** — `task-7` (QA, owner `ui-hud`) — process blocker for every live item.
2) **`task-9` nav live proof** — `orders-nav` (hero now moves; prove reachability + no-stall in a Treant bot game).
3) **`task-11` event payloads** — `loader-events` (Lead order puts events BEFORE tick latency; the board
   dependency `task-11 ← task-10` is being dropped and must be ignored).
4) **`task-12` attack timing** — `api-core` (farm accuracy).
5) **`task-10` tick latency** — `loader-events` (current live state: ~0.2 s typical, one 2.6 s spike — the target is
   the spike, not the median).
6) **`task-13` HUD Lua slice** — `developer` (HUD/world markers only; the clip premise is void — 16.11 Self Play
   has 0 `PushClip`/`PopClip` calls, see P2.1).
Still open but not in the current queue (slot by evidence when an owner frees): **P0.A clock contract**
(`api-core`), **P0-B2 `poll error` flood** (`loader-events`), **P0.C purchase orders** (`orders-nav`). P0-B is
verified by "hero now moves" (menu.lua `IsDown` fix landed). Cycle-2 native `task-3` only after Lead go-ahead.
P3 never queued. One item in flight per owner; every live proof = Treant Protector in a single-player bot game.

## Backlog (small slices, each = one developer→reviewer→QA cycle, ≤1 h)

### P0 — "the bot must actually play a game"

**P0.A — GameRules clock: return Umbrella-exact absolute time** (PM-created board slice) — owner `api-core`
- Files: `src/api.lua` clock block (`gamerules()` resolver, `GameRules.GetGameTime/GetGameStartTime`, lines
  579-706; delete/replace `estimateClock` 610-628 and `orderStamp` uses).
- Fix: `GetGameTime()` must return **absolute engine time in the same epoch as `GetGameStartTime()`** (0x594) so
  `GetGameTime() - GetGameStartTime() == in-game clock`. Anchored path: `return m_flGameStartTime +
  (GetTickCount64_ms/1000 - hornWall)`; mid-match estimate must not return a different epoch (unit+0x1ACC gave
  9072 vs expected ~379 in the live match) — either find a same-epoch growing stamp in `C_DOTAGamerules`
  (candidates `m_flGoldTime` 0x578 / `m_flCreepSpawntime` 0x580, prove by diag over 10 s) or return the
  documented sentinel (-90) until a horn transition is observed. Keep `GetGameStartTime()` = raw 0x594.
- Acceptance (QA, **Treant Protector**, single-player bot game, **new match entered from lobby while the bot loop
  is already running** so `m_flGameStartTime` 0→value transition anchors): at 0:00 and at 5:00 host.log
  `[clock] gt=<abs> gs=<abs> inGame=<gt-gs>` and self_play.log stamp `[m:ss]` equal the HUD clock ±0.5 s
  (two screenshots); zero `[clock]` warnings; last-hit/runes still sane after the semantic change.
- Risk: semantics change touches ~60 `GetGameTime()` call sites (incl. all last-hit timing) — reviewer checks
  consumers; QA must compare farm before/after. Do NOT queue the old P1.2; this item supersedes it.

**P0.B — Manual-control pause must expire (root cause fixed; verify) + P0-B2 poll errors** (PM-created board slice)
— owners `developer` (menu.lua fix, already in tree) + `loader-events` (event side + poll error)
- Verified root cause: `src/menu.lua` catch-all widget `__index` returned a truthy table for `ui.pause:IsDown()`
  → `Self Play.lua:1860` paused the bot forever. Fix landed `src/menu.lua:119-132` (real `Widget:IsDown()` via
  `GetAsyncKeyState`, aliased `IsPressed`).
- Event side (AD-8): `OnPrepareUnitOrders` must fire only for **human** orders — real order type from
  `CUtlVector` deref (`ctrl+0x9A0` count, data ptr at +8, element orderType at data+0x2C) and seq
  `ctrl+0x9B8` vs `orders.lastSeq`; bot's own orders must never re-arm the pause. Also fix `poll error:`
  (`loader.lua:440` VirtualQuery ffi cdef conflict) to zero — it aborts the event poll every tick.
- Acceptance (QA, **Treant**, single-player bot game; current match is fine/cheap): bot leaves fountain within
  10 s of bot-on and keeps farming ≥2 min; zero "Paused: manual control" lines in self_play.log after t+3 s;
  one synthetic elevated right-click (`src/synth_click_elevated.bat`) pauses ≥2 s then resumes
  (`[ev] manual order …` + "Paused" then resumes); host.log `poll error:` count = 0; no `[order] … fail`.
- Precedent for reviewer (class-of-bug sweep): catch-all `__index` methods that return tables/truthy defaults may
  be used as booleans by the scripts. Reviewer sweeps `src/menu.lua` (and other catch-alls) for
  `Get*/Is*/Can*/Has*/Should*` returns used in conditions and records findings in `REVIEW.md` (no board item).

**P0.C — Purchase/item order parity (bot never buys items)** (PM-created board slice) — owner `orders-nav`
+ `api-core` support — supersedes old P0.5
- Files: `src/orders.lua`, `src/api.lua` (whichever evidence blames); reference `self_play/shop.lua:513,844`
  (`PURCHASE_ITEM` passes `item.id` as **both** targetIndex and abilityIndex).
- Evidence: 101× `[order] PUO type=16 tgt=0 abil=0` while `[SelfPlay buy] magic_stick … own: tpscroll,ward_observer`
  repeats 2+ min without acquiring the item (02:45–03:00 runs). Verify catalog item `id` reaches the call
  (`catalog.lua` has `["magic_stick"]={["id"]=34}`), correct param slot, hero-vs-courier buy, and
  `GetTotalGold`/`Item.GetStockCount` agreement.
- Acceptance (QA, **Treant**, single-player bot game): fresh game, bot on 60 s → self_play.log
  `[SelfPlay buy] magic_stick … own:` followed within 10 s by an `own:` list containing `magic_stick`, host.log
  `[order] PUO type=16 tgt=<non-zero>`; inventory screenshot; no accidental item activation.
- Risk: wrong param slot can issue an item-use order — QA checks no item was consumed.

**P0.1 — Nav/pathing live proof + no-stall recovery** (board: `task-9`) — owner `orders-nav`
- Files: `src/nav.lua`, `src/orders.lua` (+ `src/diag_nav*.lua` for QA only).
- Fix `lastRefresh` clock-domain bug; add `[nav]` instrumentation (refresh ms, obstacles, path ms, waypoints,
  `treeWalking=`); on "move order active but hero displacement < 50 u over 1.5 s", mark the segment blocked and
  re-path (server-as-oracle walkability). A* budget hard cap (≤5 ms/path, cache per tick).
- Acceptance (QA, Treant, single-player bot game): 5 min bot-on. host.log shows `[nav] rescan obstacles>0`,
  `[nav] path … ms<5`, `treeWalking=true` at least once; hero leaves fountain and reaches a lane/camp; no
  "stationary > 2 s while move goal" occurrence after the first 20 s; `[order] ... fail` count 0; screenshot of
  Treant farming + QA_REPORT excerpt. Risk: nav blocks the hero where it should walk (conservative masks) — QA
  must report max stationary time.
- Deps: after task-5 and P0.C (one orders-nav item in flight).

**P0.2 — In-match tick latency: profile + kill the spikes** (board: `task-10`) — owner `loader-events`
- Files: `src/loader.lua` (profiler + hot paths), coordinate with `api-core` for `api.lua` profile calls.
- Current live state (20:1x Treant match after the earlier fixes): **~0.2 s typical tick, one 2.6 s spike observed**
  (down from the 7–13 s of the 02:45 run — evidence: host.log loop durations + Lead report). Remaining job is
  spike elimination and proof, not a rewrite.
- Add `[perf]` line per tick: `synth/onUpdate/onDraw/overlay ms, entities, nav ms`; find top cost; remove
  per-read `pump()`/`os.clock()` in api fast paths where safe, cache entity scans per tick, gate `nav.refresh`
  and `GameRules` lookups to once/tick, cap nav A* per tick.
- Acceptance (QA, Treant, single-player bot game): 120 consecutive ticks in match, host.log `[perf]` exposes each
  section; **p90 total tick < 300 ms, p99 < 500 ms, max < 1 s** and the 2.6 s spike is identified in `[perf]`
  (section + call) and gone; no callback errors, hero still moves. Risk: caching breaks correctness — reviewer
  must check cache invalidation; keep a `-DSAFE` fallback switch.
- Deps: after task-2 and P0-B2 (poll errors zero).

**P0.3 — Event payload contract v1: OnUnitAnimation / OnUnitAnimationEnd / OnEntityHurt / OnProjectile**
(board: `task-11`; Lead order sequences it BEFORE `task-10`, so ignore the stale `blocked_by task-10`) — owner `loader-events`
- Files: `src/loader.lua`.
- Implement per reference payloads (see evidence #4): attack castpoint from the unit's real attack point,
  `lag_compensation_time` from `NetChannel.GetAvgLatency()/2`, hurt `source` resolved from damage/attack state,
  attack projectile events by tracking units in attack animation + projectile spawn heuristics (speed from
  `NPC.GetAttackProjectileSpeed`, target from `FindFacingNPC`). Keep cost out of P0.2 budget.
- Acceptance (QA, Treant, single-player bot game): host.log `[ev] OnUnitAnimation unit=… castpoint=0.3x
  activity=…` ≥20/min in lane; `[ev] OnEntityHurt src=<name> tgt=<name> dmg=<n>` with source non-nil for
  ≥90% of events (exclude DoT); `[ev] OnProjectile` fires for ranged creeps/hero attacks; no
  `callback … error:` lines. Risk: false positives pollute last-hit predictions (QA must watch farm).
- Deps: `task-2` closed (no dependency on `task-10`; Lead order puts events first).

**P0.4 — Attack-timing APIs for last-hit parity** (board: `task-12`) — owner `api-core`
- Files: `src/api.lua`.
- Real offsets for `NPC.GetAttackAnimPoint` (C_DOTA_BaseNPC attack point/animation), `GetAttackTime`,
  `GetSecondsPerAttack` including attack-speed modifiers, `GetAttackProjectileSpeed` from KV
  (`gamedata/npc_units.json`/`npc_heroes.json` via `xhelpers`), verify `Hero.GetRecentDamage` field.
- Acceptance (QA, Treant, single-player bot game): `src/diag_attack_timing.lua` prints per-unit
  `{animPoint, attackTime, secondsPerAttack, projectileSpeed}`; Treant melee: animPoint in 0.2–0.7 and
  `GetSecondsPerAttack` matches client hero panel attack time (±0.05, screenshot); `[SelfPlay timing]` line from
  the bot appears once and its `base=` is not 0.45 constant; last-hit counter over 2 min ≥ 12/20 available
  creeps in self_play.log/QA. Risk: wrong field = worse last-hits; require before/after log comparison.
- Deps: after task-1.

**P0.5 — REMOVED: promoted to P0.C above (purchase/item order parity).**

### P1 — fidelity of the rest of the core API/events
**P1.1 — Humanizer.GetOrderQueue mirror** (owner `loader-events`) — files `loader.lua`.
  Manual-order detection itself moved to **P0.B**; this item only adds the queue mirror the scripts poll:
  expose `Humanizer.GetOrderQueue()` list of our issued orders (`player, orderType, targetIndex, position,
  abilityIndex, orderIssuer, unit, addTime, …`) so `creep_block.lua:130` sees its pending order and
  `last_hit`/`teamplay` paths behave. Acceptance (QA, Treant, single-player bot game): creep_block
  `blockNote` no longer says "finished" instantly; host.log `[hq] queue n=<n>` reflects issued orders.
**P1.2 — superseded by P0.A — do not queue separately.** Pause freeze/clock semantics are part of P0.A
  (`GameRules.IsPaused` must not use state==6; freeze `inGame` while paused).
**P1.3 — Player stats: GetTeamData deaths/assists + GetAssignedHero(p) + Players.*.**
  (owner `api-core`) files `api.lua`. Find real `DataTeamPlayer_t` deaths/assists offsets from
  `D:\hake\lotus\dumper\dota2_dump\client.dll.hpp` (`C_DOTA_DataNonSpectator`/`DataTeamPlayer_t`), fix
  `GetAssignedHero` to read the player's own hero handle.
  Acceptance (QA, Treant, bot game): HUD scoreboard (screenshot) vs `src/diag_teamdata.lua` output: kills/deaths/
  assists/networth/lasthits identical for all 10 players; win-chance panel shows non-zero loss/gain dots.
**P1.4 — Config persistence.** (owner `api-core`) files `api.lua`. Persist `Config.*` to
  `…\xYjGsPeqoWTEzbif\config.ini`/json, load on start.
  Acceptance (QA): set "Show win chance" off, reload via run.txt, switch still off (screenshot + log
  `[config] loaded N keys`); win model state survives reload (`self_play.log` shows no win-model reset).
**P1.5 — NPC/Hero real field semantics** (owner `api-core`) files `api.lua`: `GetStatesDuration` (map by
  `Enum.ModifierState` from modifier manager list), `HasScepter/HasShard`, `IsVisibleToEnemies` (needs vision
  source decision — see ARCH_DECISIONS), `GetBarriers`, `GetGoldBounty*`, `Hero.GetPrimaryAttribute`,
  `TalentIsLearned`, `GetLastVisibleTime`, `GetRecentDamage`, `NPC.GetAttackTime`.
  Acceptance (QA, Treant, bot game): `src/diag_npc_fields.lua` values sane for Treant + a lane creep + a tower
  (e.g. Treant str primary=2, tower bounty > 0, stun duration reported while rooted/stunned); no soft-stub
  `API missing:` for these names.
**P1.6 — World/Fog/latency**: `World.GetGroundZ` real terrain height (needs decision), `FogOfWar.IsPointVisible`
  from team vision, `NetChannel.GetAvgLatency` verified field, `Input.*` from native hooks.
  (owner `loader-events`+`api-core`) Acceptance: diag script prints ground Z at fountain/lane/rune (<50 u error
  vs hero Z), fog point visible/hidden toggles when enemy walks into vision; latency 20–80 ms plausible.
**P1.7 — Particle/linear-projectile callbacks** (teleport detection: `teleports.lua` needs `OnParticleCreate/
  Update*/Destroy` with `index,fullName,entity,entity_for_modifiers_id,controlPoint,position`).
  (owner `loader-events`) Acceptance (QA, Treant, bot game): enemy bot TPs to lane → `[ev] OnParticleCreate
  fullName=…teleport_end… controlPoint=0 position=…` and HUD marks a teleport; no callback errors.

### P2 — UI (does not block "bot plays"; Lead order: Lua first, native last)
**P2.1 — HUD/world-marker parity (Lua only; clip premise VOID)** (board: `task-13` after `task-4`) — owner `developer`
  files `src/overlay.lua`, `src/render.lua`. Scope: exact `TextSize` (route through `R11_TextWidthW`), HUD row
  layout/no overlap, world-marker ordering/clamping/off-screen/no-jitter, and no double draw between
  `loader.tick` and `drawOnly`. **`Render.PushClip/PopClip` is explicitly out of scope: 16.11 Self Play has 0
  PushClip/PopClip calls** — verified: the only callers anywhere are root-level cheat scripts
  (`dominator_autofarm.lua`, `LDfarmV1.7.lua`, `units_autofarm.lua`, 2 calls each), not Self Play; keep the
  no-op stubs.
  Acceptance (QA, Treant, bot game): screenshot HUD with win-chance bar and camp markers; zero clipped/overlapping
  text in `hud.lua` rows (host.log `[hud]` overlap diag count 0), markers stay on-screen and stable when the
  camera pans (2 consecutive screenshots); click-through outside menu = 0 unintended game clicks.
**P2.2 — ClickGUI parity polish** (owner `developer`, part of task-4) — dropdown outside-click, multiselect
  checkboxes, slider drag + keyboard, bind capture, scroll, tab switch, Del/Esc. Acceptance: screenshot each
  widget state + synthetic clicks; settings survive reload (P1.4).
**P2.3 — Native renderer (task-3)** — only after P2.1/P2.2 evidence and Lead go-ahead to rebuild+relaunch.
  Text atlas per-size quality, clip rects, no jitter. Acceptance: pixel screenshots vs original Umbrella
  (hud_cmds.txt / prior screenshots), 60 fps, overlay cost < 1 ms.

### P3 — do not start until told (untestable under single-player rule / needs Lead decision)
- `P3.1` Matchmaking/GC: protobuf, `GC.SendMessage/GetSteamID`, `NetChannel.SendNetMessage`, HTTP builds download,
  `matchmaking.lua`, `queue_account.lua`, `party_queue.lua`, `session.lua`, draft/party automation.
- `P3.2` External providers (`HTTP.Request`, download item builds) — keep switches OFF, no error HUD.
- `P3.3` Multi-account/VM farm wiring.

## Maintenance
- PM reports item done → architect: verify evidence links, mark item `DONE`/`REOPEN` here, queue next unblocked
  item on the board and message its owner + PM.
- Any architectural question (vision source, GridNav source, GC scope) → decision goes to `ARCH_DECISIONS.md`
  and the crew keeps moving; no waiting on the human.
- If an item makes the bot worse in a match: revert, record here, next item.