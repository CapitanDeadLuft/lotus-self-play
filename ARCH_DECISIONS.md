# ARCH_DECISIONS — Self Play port (architect)

Short records of calls made so the crew never blocks on a "how do we do X exactly?" question.
Format: decision → why (evidence) → consequence. Last updated 16.11.2026, architect.

## AD-1 — Test protocol: single-player bot game, Treant Protector only
Decision: every live acceptance run is **Игра против ботов → ОДИНОЧНАЯ**, bot hero **Treant Protector**
(`npc_dota_hero_treant`), QA-controlled Dota. Any other hero/mode is not evidence.
Why: Lead/PM hard rule; Treant's innate `MODIFIER_STATE_ALLOW_PATHING_THROUGH_TREES` exercises
`navigation.treeWalking` (the third `BuildPath` arg path), and his kit exercises heal/root/tree/slow branches
that generic heroes skip.
Consequence: acceptance criteria must name Treant + the exact log line/screenshot; matchmaking-dependent
features are untestable (see AD-5).

## AD-2 — Tick latency outranks purity; measure before optimizing
Decision: P0.2 (in-match `[perf]` profile, p90 tick < 300 ms) is a top-cycle item, not polish.
Why: `host.log` 02:45–02:53 Treant bot game shows `loader.tick()` at 7–13 s CPU (one 385 s stall); the whole
brain is `selfPlay.OnUpdate` (`Self Play.lua:1955`), so decisions are seconds stale. Menu-only runs show 0.0 s —
so cost lives in in-match API/nav/event paths, not in the driver.
Consequence: no new feature ships into the in-match path without a measured cost; profiler line format is fixed
(`[perf] synth=… update=… draw=… overlay=… navMs=…`) so QA can compare runs.

## AD-3 — GridNav source: entity-based A* + server-as-oracle learning; engine CGridNav = timeboxed spike only
Decision: ship `src/nav.lua` (A* over live obstacles: trees `ent_dota_tree` are in the entity list — logged,
buildings, map edge) and add "server as oracle": when a move order is active but the hero's displacement is
< 50 u over 1.5 s, mark the last path segment blocked and re-path. Do **not** call engine `CGridNav` functions in
this cycle.
Why: `CGridNavGameSystem` vtable is known (`vtables.hpp` client.dll 0x4906B68) but the dumper has **no** instance
or member offset for the nav grid (`offsets.json` = only dwEntityList/dwViewMatrix/dwLocalPlayerController;
`CGridNav` is not a schema class). Calling guessed vtable slots would crash Dota, and we cannot debug a crash
without human involvement. The server is authoritative for pathing anyway, and the entity A* is already live-test
ready. Tree entities are confirmed available (`ent_dota_tree` in host.log 04:21).
Consequence: nav parity is judged by "hero reaches destination / never permanently stuck", not by byte-identical
grid. If live QA shows >2 permanent stalls/5 min after AD-3 oracle, open a 1-hour spike for CGridNavGameSystem
singleton discovery (scan client.dll writable data for pointer whose vtable == clientBase+0x4906B68) — owner
`orders-nav`, Lead approval for the risk.

## AD-4 — Game clock: keep wall-anchored; do not chase CGlobalVars
Decision: `GameRules.GetGameTime` stays `m_flGameStartTime` (0x594, verified field) + `GetTickCount64` anchored,
plus real pause freeze and a sanity check against `m_flCreepSpawntime`/glyph cooldown stamps. No CGlobalVars rediscovery.
Why: dumper exports no `GlobalVars` symbol on this build (checked `offsets.json`, `important_offsets.hpp`,
`client.dll.hpp`, `server.dll.hpp`: zero hits); `m_flLastGameTime` 0x60C belongs to `CPointOrient`, not the rules
(false lead). Wall clock equals engine time except paused/stalled frames, and the only pauses in a bot game are
QA-triggered.
Consequence: if P1.2 QA shows |gt − HUD| > 0.5 s at two timestamps, escalate to a signature-scan spike; until then
this is good enough for last-hit (sub-0.1 s) timing.

**AD-4 AMENDMENT (16.11, 20:14 live match) — the problem is the API CONTRACT, not the anchor.** Umbrella's
`GetGameTime()` returns **absolute engine time**; scripts subtract `GetGameStartTime()` themselves
(`umbrella_api/gamerules.md` GetGameTime example: `ingame_timer = game_time - GameRules.GetGameStartTime()`;
`Self Play.lua:1850` does exactly that). Our implementation returned elapsed-since-horn in the anchored path and
a different-epoch value (unit+0x1ACC → 9072.1) in `estimateClock`. Live proof: `gt=175.75 < gs=236.37` (diag
20:12:20) is impossible for absolute time, and the bot's log stamp `[147:15]` = (9072.1−236.37)/60 while the HUD
showed 2:23. Corrected decision: anchored path returns `m_flGameStartTime + elapsed`; mid-match joins either get a
same-epoch growing gamerules stamp (pending discovery) or the documented sentinel — never a wrong-epoch number.
Verification requires a **new match entered from the lobby with the loop already running** (horn transition
anchors `m_flGameStartTime` 0→value); mid-match reload is not accepted as clock evidence.

## AD-12 — Catch-all widget/API methods that return truthy tables are a bug class
Decision: any catch-all `__index` that fabricates a method must return `nil` for unknown names, not a table/
function stub, **unless** the method is explicitly typed (bind switch → boolean, vector getter → Vector). Reviewer
must sweep every catch-all for `Get*/Is*/Can*/Has*/Should*` methods whose truthiness the scripts use in conditions.
Why (live incident 20:12–20:14): `src/menu.lua` catch-all returned a truthy table for `ui.pause:IsDown()`, so
`Self Play.lua:1860` hit the "Paused: manual control" early-return on every tick and the bot never left the
fountain — the single most visible defect in the whole port, caused by one truthy stub. The fix is in
`src/menu.lua:119-132` (`Widget:IsDown()` via `GetAsyncKeyState`); the sweep for siblings is part of P0.B.
Consequence: `api.lua` `softIndex` (typed defaults) and `loader.lua` `stubNS` must justify each fabricated
default; the reviewer records the sweep result in `REVIEW.md`.

## AD-5 — GC/protobuf/http/matchmaking: OUT OF SCOPE while the test rule is single-player
Decision: `GC`, `Protobuf`, `NetChannel.SendNetMessage`, `HTTP` stay nil-safe stubs; `matchmaking.lua`,
`queue_account.lua`, `party_queue.lua`, `session.lua` are not ported; bot's "download builds" switch stays OFF.
Why: these features need a real queue/GC connection, cannot be proven in a single-player bot game, and were listed
in the brief as known stubs. Spending cycles there produces untestable code (violates "no guesses as facts").
Consequence: no runtime errors may leak from these paths (`API missing:` / `attempt to index` = bug); revisit only
on explicit human request (farm automation), then it becomes a separate project with its own test protocol.

## AD-6 — Event synthesizer: polling in loader, exact payload contract, no optimistic fabrication
Decision: keep event synthesis in `loader.synthesize` (poll per tick; no native hooks — native change forces a
Dota relaunch which we cannot do casually). Payload contracts are fixed from the reference now:
`OnProjectile{source,target,moveSpeed,isAttack,ability,handle}`, `OnUnitAnimation{unit,castpoint,
lag_compensation_time}` (+sequenceName/activity), `OnUnitAnimationEnd{unit}`, `OnEntityHurt{source,target,damage,…}`,
`OnLinearProjectileCreate{source,velocity,origin,distance,handle}`, `OnParticle*{index,fullName,entity,
entity_for_modifiers_id,controlPoint,position}`, `OnPrepareUnitOrders{player,order,npc,identifier}`.
Why: `Self Play.lua:2192-2296`, `last_hit.lua:108-180`, `teleports.lua:9-43` consume exactly these fields; the
current synthesizer sends `source=nil`, constant `castpoint=0.3`, constant `lag=0`, no projectile/particle events.
Consequence: a fake-but-plausible payload is forbidden — if we cannot know the source, send nil and log `[ev]
unknown-source` once; `last_hit` already guards on missing source. Payload changes are reviewer-checked against
the reference call sites.

## AD-7 — No silent typed stubs on decision-critical APIs
Decision: an API used by gameplay logic must be either offset-backed or return a documented approximation and log
`[approx] <ns>.<fn>=<value>` **once** per session. Soft-stub defaults (`Get*`→0, `Is*`→false) are only acceptable
for cosmetic/HUD-only calls.
Why: `Entity/NPC/Hero/Player` use `softIndex` (`api.lua:915-948`) so a missing method silently returns 0/false —
worse than nil because the script keeps "working" with wrong data (e.g. `GetAttackAnimPoint` 0.45 constant,
`HasScepter` false, `GetStatesDuration` {}).
Consequence: reviewer rejects PRs adding silent stubs; QA greps host.log for `[approx]` and lists them in QA_REPORT.

## AD-8 — Manual orders: fix the address first, then trust the pause
Decision: `OnPrepareUnitOrders` synthesis must read the controller order vector correctly (`C_DOTAGAMEUNITORDERS`
is `CUtlVector` at ctrl+0x9A0: count at 0x9A0, data pointer at 0x9A8; first element orderType at data+0x2C) and
compare sequence (`ctrl+0x9B8`) against `orders.lastSeq` captured after each bot order. Payload order type is the
**element's** orderType, not the vector base + 0x2C.
Why: `loader.lua:427` currently reads `ctrl + 0x9A0 + 0x2C`, i.e. 44 bytes past the vector header — garbage.
Automated (bot) orders must never trigger the pause, or the bot stops itself; human synthetic click must trigger it.
Consequence: acceptance is a synthetic elevated right-click: `[ev] manual order seq=… type=1` + bot paused ≥2 s +
resumed; this is the only way to test "human clicked" inside a bot game.

## AD-9 — Lua-first UI, native last
Decision: HUD/ClickGUI fixes go through `overlay.lua`/`render.lua`/`menu.lua` (hot reload) before any
`render11.cpp`/`host.cpp` change; native rebuild requires Lead go-ahead and a QA relaunch window (kills the match).
Why: brief + protocol; native iteration costs a match and carries crash risk; RCmd list already carries text/rect/
clipable primitives, so most glitches are publishable in Lua.
Consequence: P2.1/P2.2 before P2.3; reviewer must confirm no RCmd layout drift with `render11.cpp` struct.

## AD-10 — Definition of done
Decision: an item is done only when (a) code compiles/`luajit loadfile` passes, (b) reviewer PASS in `REVIEW.md`,
(c) QA writes a log excerpt + (where visual) screenshot from a **Treant single-player bot game** into
`QA_REPORT.md`, (d) architect marks it DONE in PLAN.md. "It should work" is not done; a matching log line is.
Consequence: PM closes board items only with the QA evidence link; otherwise reopen.

## AD-11 — Priority rule for the rest of the port
Decision: rank by "can the bot act correctly right now": (1) act-at-all / act-in-time (tick latency, orders,
purchase), (2) act-correctly (navigation, last-hit timing, combat events), (3) decision inputs (stats/team data,
clock, vision), (4) UI parity, (5) queue automation. HUD cosmetics never block a P0.
Why: the human's complaint is "bot stands still" — latency/nav/purchase produce that directly; a wrong scoreboard
does not.
Consequence: if a P2 item and a P0 item need the same owner, P0 wins; PM sequences accordingly.