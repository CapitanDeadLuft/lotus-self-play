# API PARITY INVENTORY — 16.11 reference scripts vs `umbrella_api`

Generated: **2026-11-16 21:52** (v2 — reviewer adjudication applied) by `developer` (task-22). Inputs: `Self Play.lua` + `self_play/**/*.lua` = **129 files** under `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts`. Output: this doc only; no product source was modified.

## 0. Purpose

Inventory of **every** Lua-API function the 16.11 reference Self Play calls, so the port can be audited call-by-call against `D:\hake\lotus\umbrella_api\*.md`. Primary consumers: `api-core` (task-21 diag design) + `native-render` (review). This is the reference-side contract; the implementation state of our bridge is deliberately not asserted here.

### 0.1 Ownership framing (Lead adjudication, v2)

The parity baseline run (diag without loader shims) produced **loader-context artifacts**, not api defects: `MISSING(21)` and the FogOfWar errors happened because `Item`, `Modifier`, `World`, `GridNav` (and the other stub namespaces) are **loader.lua-owned shims**, and `Entity.GetRotation` was a diag **mis-tag** (the contract returns an `Angle`, not a number). The only genuinely api-owned defect in that baseline is `Entity.GetClassName`. Accordingly every row below carries an **Owner** column: `api.lua` = value/contract ownership, `loader.lua` = Umbrella shim/stub owned by loader-events. Cross-namespace doc hits are marked **non-authoritative**.

## 1. Method & heuristics (traceable)

- **Target tree**: `Self Play.lua` + `self_play/**/*.lua` (129 files).
- **Extraction (v2, three channels)**: per line, comment-only lines (`--…`) skipped; regex over `[A-Z]\w*\.[A-Za-z_]\w*` restricted to the 39 API namespaces actually used, then split by syntactic context:
  - **direct** = `NS.Fn(…)` call; **pcall** = `pcall(NS.Fn, …)`; **value-ref** = function referenced as a value (existence probes like `if not GridNav.CreateNpcMap then`, aliasing). The `Calls` column in §6 is `direct + pcall + value-ref`; §3 lists the early channels separately where they differ (e.g. **GridNav.CreateNpcMap/ReleaseNpcMap have direct sites in last_hit.lua plus pcall sites in navigation.lua:297/299/300** — the v1 doc under-reported these).
- **Doc mapping**: `## <sub>Fn</sub>` headings in `umbrella_api/*.md`; preferred doc per namespace. A citation from the preferred doc is authoritative. A same-name heading found only under a **different** namespace is marked `NON-AUTHORITATIVE (cross-ns)` and the row stays UNVERIFIED — it is never silently cited as semantics.
- **EARLY-GAME PATH** (explicit subset): function has ≥1 **call site in an early-lane module** or is in the curated core-lane query list. Early-lane modules: `last_hit, lane_rules, lane_choice, lane_spacing, lane_geometry, waves, creep_block, positioning, intent, field, shop, build_brain, consumables, tower_safety, support_policy, decide, catalog, navigation, awareness, planner, strategy, runes` (this **includes runes** for the 0:00 bounty-rune contest). Curated core-lane queries = the Entity/NPC/GridNav/GameRules/Player/Item/Ability queries listed in `§3` with a *(core-list)* note. Adjustments v2: `Player.GetTeamData/GetTeamPlayer` were **removed** from the early list — they are pre-game role/lane inputs (§3.2); `draft`, `couriers`, `inventory_cleanup`, `heroes/*` are documented in §3.2 as excluded from the baseline heuristic.
- **Tags**: `EARLY`, `EARLY+LATE` (also called outside lane phase), `LATE/OTHER`. `Early sites` counts only early-module call sites; a core-list row can be `EARLY` with 0 literal early-module sites — §4 shows both numbers.

## 2. Totals (v2 recount)

- Distinct API functions: **227** across **39** namespaces; total call references: **5639** = direct **5604** + pcall **9** + value-ref **26**.
- EARLY-GAME-PATH functions: **141** (EARLY 18 + EARLY+LATE 123 of the subset).
- Functions with UNVERIFIED SEMANTICS (no `umbrella_api` heading for their namespace): **26** — of those, 9 have a cross-namespace same-name heading only (NON-AUTHORITATIVE); namespace-doc-verified: **201**.

## 2.1 umbrella_api surfaces NOT called by the 16.11 tree (verified 0 matches, case-sensitive)

- `Particle`, `Protobuf`, `Event`, `Game`, `Localizer`/`GameLocalizer`, `Chrono`, `Color`, `Vector`, `Vec2`, `Executor`, `Buffer`, `Chat` — no call sites in `Self Play.lua`/`self_play/**`; out of scope for parity audit until a ported behaviour uses them.
- `Enum.*` is used throughout the tree for state/flow/type constants, but it is an enum table (not a function namespace) and is excluded from the function tables; enum-value parity is a separate audit item.
- Coverage statement: the **39 namespaces** in §2.2 are exactly the namespaces the 16.11 tree calls, so this inventory is complete for the reference behaviour.

## 2.2 Ownership summary (loader.lua shim vs api.lua value/contract)

| Owner | Namespaces | Functions | Calls |
|---|---|---|---|
| api.lua | Ability, Config, Engine, Entity, GameRules, Hero, Heroes, Log, NetChannel, NPC, Player, Players | 168 | 5294 |
| loader.lua | Abilities, Bottle, Couriers, Entities, GC, GridNav, HTTP, Humanizer, Input, Item, Menu, Modifier, NPCs, Panorama, PhysicalItem, PhysicalItems, PowerTreads, Render, Rune, Runes, TempTrees, Tower, Tree, Trees, World | 57 | 336 |
| api.lua + loader stub | FogOfWar, GlobalVars | 2 | 9 |

### Per-namespace summary

| # | Namespace | Functions | Calls | Owner | Doc | EARLY functions |
|---|---|---|---|---|---|---|
| 1 | `NPC` | 68 | 2377 | api.lua | npc.md | 58 |
| 2 | `Entity` | 17 | 1969 | api.lua | entity.md | 14 |
| 3 | `Ability` | 32 | 655 | api.lua | ability.md | 14 |
| 4 | `GridNav` | 4 | 108 | loader.lua | gridnav.md | 4 |
| 5 | `Hero` | 11 | 70 | api.lua | hero.md | 7 |
| 6 | `Item` | 10 | 70 | loader.lua | item.md | 8 |
| 7 | `Player` | 11 | 61 | api.lua | player.md | 5 |
| 8 | `GameRules` | 8 | 45 | api.lua | gamerules.md | 5 |
| 9 | `Config` | 6 | 36 | api.lua | config.md | 4 |
| 10 | `World` | 1 | 31 | loader.lua | —(none) | 1 |
| 11 | `Engine` | 8 | 28 | api.lua | engine.md | 1 |
| 12 | `NetChannel` | 2 | 23 | api.lua | —(none) | 1 |
| 13 | `Render` | 10 | 22 | loader.lua | render.md | 0 |
| 14 | `Modifier` | 6 | 22 | loader.lua | modifier.md | 1 |
| 15 | `GC` | 2 | 13 | loader.lua | —(none) | 0 |
| 16 | `Log` | 1 | 11 | api.lua | —(none) | 0 |
| 17 | `Players` | 2 | 10 | api.lua | players.md | 2 |
| 18 | `Heroes` | 2 | 9 | api.lua | heroes.md | 2 |
| 19 | `Tower` | 1 | 9 | loader.lua | —(none) | 1 |
| 20 | `Trees` | 1 | 8 | loader.lua | —(none) | 1 |
| 21 | `Couriers` | 2 | 8 | loader.lua | —(none) | 2 |
| 22 | `FogOfWar` | 1 | 7 | api.lua + loader stub | —(none) | 1 |
| 23 | `Panorama` | 1 | 6 | loader.lua | —(none) | 0 |
| 24 | `NPCs` | 2 | 5 | loader.lua | npcs.md | 0 |
| 25 | `Tree` | 1 | 5 | loader.lua | —(none) | 1 |
| 26 | `Runes` | 2 | 5 | loader.lua | —(none) | 2 |
| 27 | `Bottle` | 1 | 5 | loader.lua | —(none) | 1 |
| 28 | `HTTP` | 1 | 4 | loader.lua | —(none) | 1 |
| 29 | `Rune` | 1 | 3 | loader.lua | —(none) | 1 |
| 30 | `TempTrees` | 2 | 3 | loader.lua | —(none) | 0 |
| 31 | `GlobalVars` | 1 | 2 | api.lua + loader stub | —(none) | 0 |
| 32 | `Menu` | 2 | 2 | loader.lua | menu.md | 0 |
| 33 | `Humanizer` | 1 | 1 | loader.lua | humanizer.md | 1 |
| 34 | `PhysicalItems` | 1 | 1 | loader.lua | —(none) | 0 |
| 35 | `PhysicalItem` | 1 | 1 | loader.lua | —(none) | 0 |
| 36 | `Entities` | 1 | 1 | loader.lua | entities.md | 1 |
| 37 | `Input` | 1 | 1 | loader.lua | —(none) | 0 |
| 38 | `PowerTreads` | 1 | 1 | loader.lua | —(none) | 1 |
| 39 | `Abilities` | 1 | 1 | loader.lua | —(none) | 0 |

## 3. EARLY-GAME SUBSET (0:00–5:00 lane/creep/wave/last-hit/XP/gold/role)

Priority audit surface for parity: a wrong value here is visible in the first creep wave. **Early sites** = call sites in early-lane modules; **(core-list)** = tagged via the curated core-lane query list (executed by `helpers.scan/sample` from 0:00 even if its literal call sites live in core files).

| Function | Calls (d/p/v) | Early sites | Owners | umbrella_api semantics (doc:line) | Tag |
|---|---|---|---|---|---|
| `Entity.GetAbsOrigin` | 709 (709/0/0) | self_play/awareness.lua:102<br>self_play/awareness.lua:135<br>self_play/awareness.lua:184 | api.lua | ``Entity.GetAbsOrigin(entity):` [**`Vector`**](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)` (entity.md:144) | EARLY+LATE |
| `Entity.GetIndex` | 170 (169/0/1) | self_play/awareness.lua:20<br>self_play/awareness.lua:35<br>self_play/awareness.lua:35 | api.lua | ``Entity.GetIndex(entity):` **`integer`**` (entity.md:83) | EARLY+LATE |
| `Entity.IsSameTeam` | 201 (201/0/0) | self_play/awareness.lua:97<br>self_play/consumables.lua:45<br>self_play/creep_block.lua:172 | api.lua | ``Entity.IsSameTeam(entity1, entity2):` **`boolean`**` (entity.md:133) | EARLY+LATE |
| `NPC.GetAttackRange` | 146 (146/0/0) | self_play/awareness.lua:123<br>self_play/awareness.lua:187<br>self_play/awareness.lua:217 | api.lua | ``NPC.GetAttackRange(npc):` **`integer`**` (npc.md:516) | EARLY+LATE |
| `Entity.GetHealth` | 294 (294/0/0) | self_play/awareness.lua:53<br>self_play/awareness.lua:86<br>self_play/awareness.lua:282 | api.lua | ``Entity.GetHealth(entity):` **`integer`**` (entity.md:239) | EARLY+LATE |
| `Entity.IsAlive` | 164 (164/0/0) | self_play/awareness.lua:15<br>self_play/awareness.lua:99<br>self_play/awareness.lua:136 | api.lua | ``Entity.IsAlive(entity):` **`boolean`**` (entity.md:219) | EARLY+LATE |
| `Entity.IsEntity` | 154 (154/0/0) | self_play/awareness.lua:15<br>self_play/awareness.lua:97<br>self_play/awareness.lua:136 | api.lua | ``Entity.IsEntity(entity):` **`boolean`**` (entity.md:9) | EARLY+LATE |
| `NPC.GetMoveSpeed` | 103 (103/0/0) | self_play/awareness.lua:111<br>self_play/awareness.lua:123<br>self_play/awareness.lua:187 | api.lua | ``NPC.GetMoveSpeed(npc):` **`number`**` (npc.md:847) | EARLY+LATE |
| `NPC.GetAttackRangeBonus` | 89 (89/0/0) | self_play/awareness.lua:123<br>self_play/awareness.lua:187<br>self_play/awareness.lua:217 | api.lua | ``NPC.GetAttackRangeBonus(npc):` **`integer`**` (npc.md:526) | EARLY+LATE |
| `NPC.IsVisible` | 87 (87/0/0) | self_play/awareness.lua:15<br>self_play/consumables.lua:44<br>self_play/consumables.lua:243 | api.lua | ``NPC.IsVisible(npc):` **`boolean`**` (npc.md:165) | EARLY+LATE |
| `Entity.GetMaxHealth` | 133 (133/0/0) | self_play/awareness.lua:86<br>self_play/awareness.lua:282<br>self_play/consumables.lua:47 | api.lua | ``Entity.GetMaxHealth(entity):` **`integer`**` (entity.md:249) | EARLY+LATE |
| `NPC.IsIllusion` | 122 (122/0/0) | self_play/awareness.lua:97<br>self_play/consumables.lua:33<br>self_play/consumables.lua:45 | api.lua | ``NPC.IsIllusion(npc):` **`boolean`**` (npc.md:155) | EARLY+LATE |
| `Entity.IsDormant` | 86 (86/0/0) | self_play/awareness.lua:15<br>self_play/awareness.lua:148<br>self_play/consumables.lua:44 | api.lua | ``Entity.IsDormant(entity):` **`boolean`**` (entity.md:229) | EARLY+LATE |
| `GridNav.IsTraversable` | 85 (85/0/0) | self_play/awareness.lua:156<br>self_play/consumables.lua:112<br>self_play/creep_block.lua:78 | loader.lua | ``GridNav.IsTraversable(pos, [flag], [flag_excluded]):` **`boolean`**, **`integer`**` (gridnav.md:33) | EARLY+LATE |
| `NPC.HasModifier` | 114 (114/0/0) | self_play/awareness.lua:232<br>self_play/consumables.lua:48<br>self_play/consumables.lua:48 | api.lua | ``NPC.HasModifier(npc, name):` **`boolean`**` (npc.md:41) | EARLY+LATE |
| `NPC.GetUnitName` | 111 (111/0/0) | self_play/consumables.lua:34<br>self_play/creep_block.lua:254<br>self_play/lane_choice.lua:21 | api.lua | ``NPC.GetUnitName(npc):` **`string`**` (npc.md:1036) | EARLY+LATE |
| `NPC.GetItemByIndex` | 37 (37/0/0) | self_play/awareness.lua:77<br>self_play/consumables.lua:52<br>self_play/last_hit.lua:59 | api.lua | ``NPC.GetItemByIndex(npc, index):` [**`CItem`**](/api-v2.0/game-components/core/item.md) | **`nil`**` (npc.md:897) | EARLY+LATE |
| `NPC.GetHullRadius` | 29 (29/0/0) | self_play/creep_block.lua:87<br>self_play/creep_block.lua:87<br>self_play/creep_block.lua:306 | api.lua | ``NPC.GetHullRadius(npc):` **`number`**` (npc.md:660) | EARLY+LATE |
| `NPC.HasState` | 149 (149/0/0) | self_play/awareness.lua:45<br>self_play/awareness.lua:122<br>self_play/awareness.lua:149 | api.lua | ``NPC.HasState(npc, state):` **`boolean`**` (npc.md:110) | EARLY+LATE |
| `NPC.GetSecondsPerAttack` | 54 (54/0/0) | self_play/awareness.lua:124<br>self_play/awareness.lua:189<br>self_play/awareness.lua:231 | api.lua | ``NPC.GetSecondsPerAttack(npc, bIgnoreTempAttackSpeed):` **`number`**` (npc.md:1291) | EARLY+LATE |
| `NPC.IsRanged` | 29 (29/0/0) | self_play/creep_block.lua:197<br>self_play/creep_block.lua:235<br>self_play/creep_block.lua:262 | api.lua | ``NPC.IsRanged(npc):` **`boolean`**` (npc.md:195) | EARLY+LATE |
| `NPC.IsAttacking` | 92 (92/0/0) | self_play/awareness.lua:323<br>self_play/creep_block.lua:197<br>self_play/creep_block.lua:234 | api.lua | ``NPC.IsAttacking(npc):` **`boolean`**` (npc.md:446) | EARLY+LATE |
| `NPC.GetTrueDamage` | 81 (81/0/0) | self_play/awareness.lua:124<br>self_play/awareness.lua:189<br>self_play/awareness.lua:233 | api.lua | ``NPC.GetTrueDamage(npc):` **`number`**` (npc.md:877) | EARLY+LATE |
| `NPC.IsLaneCreep` | 49 (49/0/0) | self_play/creep_block.lua:358<br>self_play/creep_block.lua:359<br>self_play/field.lua:38 | api.lua | ``NPC.IsLaneCreep(npc):` **`boolean`**` (npc.md:215) | EARLY+LATE |
| `World.GetGroundZ` | 31 (31/0/0) | self_play/field.lua:78<br>self_play/lane_spacing.lua:142<br>self_play/last_hit.lua:344 | loader.lua | **UNVERIFIED** (no doc) | EARLY+LATE |
| `Ability.GetName` | 102 (102/0/0) | self_play/awareness.lua:47<br>self_play/consumables.lua:8<br>self_play/consumables.lua:54 | api.lua | ``Ability.GetName(ability):` **`string`**` (ability.md:253) | EARLY+LATE |
| `NPC.GetArmorDamageMultiplier` | 51 (51/0/0) | self_play/awareness.lua:62<br>self_play/awareness.lua:124<br>self_play/awareness.lua:189 | api.lua | ``NPC.GetArmorDamageMultiplier(npc):` **`number`**` (npc.md:567) | EARLY+LATE |
| `Item.GetCurrentCharges` | 27 (27/0/0) | self_play/consumables.lua:29<br>self_play/consumables.lua:29<br>self_play/consumables.lua:55 | loader.lua | ``Item.GetCurrentCharges(item):` **`integer`**` (item.md:149) | EARLY+LATE |
| `NPC.GetMana` | 78 (78/0/0) | self_play/awareness.lua:81<br>self_play/consumables.lua:129<br>self_play/consumables.lua:178 | api.lua | ``NPC.GetMana(npc):` **`number`**` (npc.md:952) | EARLY+LATE |
| `NPC.IsHero` | 103 (103/0/0) | self_play/last_hit.lua:90<br>self_play/last_hit.lua:213<br>self_play/last_hit.lua:214 | api.lua | ``NPC.IsHero(npc):` **`boolean`**` (npc.md:337) | EARLY+LATE |
| `NPC.GetMaxMana` | 38 (38/0/0) | self_play/consumables.lua:129<br>self_play/consumables.lua:178<br>self_play/consumables.lua:180 | api.lua | ``NPC.GetMaxMana(npc):` **`number`**` (npc.md:962) | EARLY+LATE |
| `Player.PrepareUnitOrders` | 26 (26/0/0) | self_play/consumables.lua:73<br>self_play/runes.lua:341<br>self_play/runes.lua:358 | api.lua | ``Player.PrepareUnitOrders(player, type, target, pos, ability, issuer, issuer_npc, [queue], [show_effects], [callback], [execute_fast], [identifier], [force_minimap]):` **`nil`**` (player.md:7) | EARLY+LATE |
| `Ability.GetCastRange` | 124 (124/0/0) | self_play/awareness.lua:64<br>self_play/consumables.lua:46<br>self_play/consumables.lua:90 | api.lua | ``Ability.GetCastRange(ability):` **`number`**` (ability.md:447) | EARLY+LATE |
| `NPC.FindFacingNPC` | 35 (35/0/0) | self_play/awareness.lua:323<br>self_play/intent.lua:27<br>self_play/last_hit.lua:90 | api.lua | ``NPC.FindFacingNPC(npc, ignoreNpc, [team_type], [angle], [distance]):` [**`CNPC`**](/api-v2.0/game-components/core/npc.md) | **`nil`**` (npc.md:823) | EARLY+LATE |
| `GameRules.GetGameTime` | 29 (29/0/0) | self_play/last_hit.lua:111<br>self_play/last_hit.lua:158<br>self_play/last_hit.lua:179 | api.lua | ``GameRules.GetGameTime():` **`number`**` (gamerules.md:57) | EARLY+LATE |
| `GridNav.BuildPath` | 16 (15/1/0) | self_play/awareness.lua:157<br>self_play/lane_geometry.lua:23<br>self_play/lane_spacing.lua:13 | loader.lua | ``GridNav.BuildPath(start, end_, [ignoreTrees], [npc_map]):` [**`Vector[]`**](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)` (gridnav.md:53) | EARLY+LATE |
| `NPC.IsInRangeOfShop` | 10 (10/0/0) | self_play/shop.lua:577<br>self_play/shop.lua:598<br>self_play/shop.lua:602 | api.lua | ``NPC.IsInRangeOfShop(npc, shop_type, [specific]):` **`boolean`**` (npc.md:1372) | EARLY+LATE |
| `NPC.GetTimeToFace` | 9 (9/0/0) | self_play/lane_spacing.lua:118<br>self_play/lane_spacing.lua:231<br>self_play/last_hit.lua:37 | api.lua | ``NPC.GetTimeToFace(npc, target):` **`number`**` (npc.md:790) | EARLY+LATE |
| `NPC.GetItem` | 51 (51/0/0) | self_play/consumables.lua:13<br>self_play/consumables.lua:225<br>self_play/runes.lua:60 | api.lua | ``NPC.GetItem(npc, name, [isReal]):` [**`CItem`**](/api-v2.0/game-components/core/item.md) | **`nil`**` (npc.md:17) | EARLY+LATE |
| `NPC.IsMeepoClone` | 13 (13/0/0) | self_play/consumables.lua:33<br>self_play/consumables.lua:45<br>self_play/lane_rules.lua:8 | api.lua | ``NPC.IsMeepoClone(npc):` **`boolean`**` (npc.md:357) | EARLY+LATE |
| `NPC.GetAttackSpeed` | 10 (10/0/0) | self_play/last_hit.lua:36<br>self_play/last_hit.lua:114<br>self_play/last_hit.lua:127 | api.lua | ``NPC.GetAttackSpeed(npc, [ignore_temp_attack_speed]):` **`number`**` (npc.md:639) | EARLY+LATE |
| `NPC.IsStunned` | 50 (50/0/0) | self_play/awareness.lua:227<br>self_play/awareness.lua:229<br>self_play/awareness.lua:258 | api.lua | ``NPC.IsStunned(npc):` **`boolean`**` (npc.md:466) | EARLY+LATE |
| `NPC.IsRunning` | 35 (35/0/0) | self_play/creep_block.lua:151<br>self_play/creep_block.lua:308<br>self_play/last_hit.lua:316 | api.lua | ``NPC.IsRunning(npc):` **`boolean`**` (npc.md:436) | EARLY+LATE |
| `NPC.GetAttackAnimPoint` | 9 (9/0/0) | self_play/last_hit.lua:34<br>self_play/last_hit.lua:112<br>self_play/last_hit.lua:127 | api.lua | ``NPC.GetAttackAnimPoint(npc):` **`number`** | **`nil`**` (npc.md:728) | EARLY+LATE |
| `Player.GetTotalGold` | 8 (8/0/0) | self_play/shop.lua:475<br>self_play/shop.lua:506<br>self_play/shop.lua:700 | api.lua | ``Player.GetTotalGold(player):` **`integer`**` (player.md:227) | EARLY+LATE |
| `Ability.GetLevel` | 83 (83/0/0) | self_play/awareness.lua:43<br>self_play/awareness.lua:47<br>self_play/intent.lua:43 | api.lua | ``Ability.GetLevel(ability):` **`integer`**` (ability.md:199) | EARLY+LATE |
| `Entity.IsNPC` | 16 (16/0/0) | self_play/last_hit.lua:202<br>self_play/last_hit.lua:231<br>self_play/last_hit.lua:235 | api.lua | ``Entity.IsNPC(entity):` **`boolean`**` (entity.md:19) | EARLY+LATE |
| `Hero.GetReplicatingOtherHeroModel` | 10 (10/0/0) | self_play/creep_block.lua:369<br>self_play/lane_rules.lua:9<br>self_play/lane_rules.lua:20 | api.lua | ``Hero.GetReplicatingOtherHeroModel(hero):` [**`CHero`**](/api-v2.0/game-components/core/hero.md) | **`nil`**` (hero.md:193) | EARLY+LATE |
| `NPC.GetTimeToFacePosition` | 6 (6/0/0) | self_play/creep_block.lua:94<br>self_play/creep_block.lua:107<br>self_play/creep_block.lua:388 | api.lua | ``NPC.GetTimeToFacePosition(npc, pos):` **`number`**` (npc.md:812) | EARLY+LATE |
| `NPC.IsChannellingAbility` | 58 (58/0/0) | self_play/creep_block.lua:217<br>self_play/lane_spacing.lua:219<br>self_play/last_hit.lua:694 | api.lua | ``NPC.IsChannellingAbility(npc):` **`boolean`**` (npc.md:412) | EARLY+LATE |
| `Ability.IsReady` | 27 (27/0/0) | self_play/intent.lua:43<br>self_play/lane_spacing.lua:40<br>self_play/shop.lua:365 | api.lua | ``Ability.IsReady(ability):` **`boolean`**` (ability.md:157) | EARLY+LATE |
| `NetChannel.GetAvgLatency` | 21 (21/0/0) | self_play/creep_block.lua:7<br>self_play/creep_block.lua:7<br>self_play/last_hit.lua:50 | api.lua | **UNVERIFIED** (no doc) | EARLY+LATE |
| `Couriers.GetLocal` | 7 (7/0/0) | self_play/shop.lua:23<br>self_play/shop.lua:356<br>self_play/shop.lua:566 | loader.lua | **UNVERIFIED — cross-ns lookalike heroes.md:54 is NON-AUTHORITATIVE** | EARLY+LATE |
| `Bottle.GetRuneType` | 5 (5/0/0) | self_play/consumables.lua:126<br>self_play/runes.lua:62<br>self_play/runes.lua:71 | loader.lua | **UNVERIFIED** (no doc) | EARLY+LATE |
| `GridNav.CreateNpcMap` | 4 (2/1/1) | self_play/last_hit.lua:554<br>self_play/last_hit.lua:567<br>self_play/navigation.lua:268 [value] | loader.lua | `\`GridNav.CreateNpcMap(\[excluded\_npcs], \[includeTempTrees], \[customCollisionSizes]):\` \[\*\*\`GridNavNpcMap\`\*\*]\(GridNavNpcMap.md)` (gridnav.md:7) | EARLY |
| `NPC.GetAbility` | 142 (142/0/0) | self_play/intent.lua:42<br>self_play/last_hit.lua:66<br>self_play/shop.lua:519 | api.lua | ``NPC.GetAbility(npc, name):` [**`CAbility`**](/api-v2.0/game-components/core/ability.md) | **`nil`**` (npc.md:930) | EARLY+LATE |
| `Hero.GetRecentDamage` | 42 (42/0/0) | self_play/consumables.lua:170<br>self_play/consumables.lua:239<br>self_play/shop.lua:381 | api.lua | ``Hero.GetRecentDamage(hero):` **`integer`**` (hero.md:143) | EARLY+LATE |
| `NPC.GetHealthRegen` | 23 (23/0/0) | self_play/consumables.lua:103<br>self_play/last_hit.lua:548<br>self_play/shop.lua:445 | api.lua | ``NPC.GetHealthRegen(npc):` **`number`**` (npc.md:982) | EARLY+LATE |
| `NPC.IsSilenced` | 18 (18/0/0) | self_play/awareness.lua:46<br>self_play/consumables.lua:196<br>self_play/lane_spacing.lua:58 | api.lua | ``NPC.IsSilenced(npc):` **`boolean`**` (npc.md:456) | EARLY+LATE |
| `Config.WriteString` | 11 (11/0/0) | self_play/build_brain.lua:342<br>self_play/shop.lua:330<br>self_play/shop.lua:662 | api.lua | ``Config.WriteString(config, key, value):` **`nil`**` (config.md:67) | EARLY+LATE |
| `Config.ReadString` | 10 (10/0/0) | self_play/build_brain.lua:337<br>self_play/shop.lua:66<br>self_play/shop.lua:647 | api.lua | ``Config.ReadString(config, key, [def]):` **`string`**` (config.md:31) | EARLY+LATE |
| `FogOfWar.IsPointVisible` | 7 (6/0/1) | self_play/awareness.lua:151<br>self_play/awareness.lua:165<br>self_play/runes.lua:150 | api.lua + loader stub | **UNVERIFIED** (no doc) | EARLY+LATE |
| `NPC.GetModifierProperty` | 7 (7/0/0) | self_play/last_hit.lua:413<br>self_play/last_hit.lua:531<br>self_play/last_hit.lua:612 | api.lua | ``NPC.GetModifierProperty(npc, property):` **`number`**` (npc.md:1394) | EARLY+LATE |
| `NPC.IsEntityInRange` | 7 (7/0/0) | self_play/last_hit.lua:392<br>self_play/last_hit.lua:543<br>self_play/last_hit.lua:655 | api.lua | ``NPC.IsEntityInRange(npc, npc2, range):` **`boolean`**` (npc.md:367) | EARLY+LATE |
| `Rune.GetRuneType` | 3 (3/0/0) | self_play/runes.lua:132<br>self_play/runes.lua:295<br>self_play/runes.lua:319 | loader.lua | **UNVERIFIED** (no doc) | EARLY |
| `Runes.Contains` | 3 (3/0/0) | self_play/runes.lua:143<br>self_play/runes.lua:284<br>self_play/runes.lua:287 | loader.lua | **UNVERIFIED — cross-ns lookalike entities.md:13 is NON-AUTHORITATIVE** | EARLY |
| `Hero.GetPrimaryAttribute` | 3 (2/0/1) | self_play/consumables.lua:227<br>self_play/intent.lua:34 [value]<br>self_play/intent.lua:35 | api.lua | ``Hero.GetPrimaryAttribute(hero):` [**`Enum.Attributes`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.attributes)` (hero.md:53) | EARLY |
| `GridNav.ReleaseNpcMap` | 3 (2/0/1) | self_play/last_hit.lua:599<br>self_play/navigation.lua:268 [value]<br>self_play/navigation.lua:300 | loader.lua | ``GridNav.ReleaseNpcMap(npc_map):` **`nil`**` (gridnav.md:23) | EARLY |
| `Ability.GetManaCost` | 72 (72/0/0) | self_play/awareness.lua:69<br>self_play/lane_spacing.lua:41 | api.lua | ``Ability.GetManaCost(ability):` **`number`**` (ability.md:528) | EARLY+LATE |
| `NPC.GetAbilityByIndex` | 27 (27/0/0) | self_play/awareness.lua:76<br>self_play/lane_spacing.lua:39 | api.lua | ``NPC.GetAbilityByIndex(npc, index):` [**`CAbility`**](/api-v2.0/game-components/core/ability.md) | **`nil`**` (npc.md:908) | EARLY+LATE |
| `NPC.GetMagicalArmorDamageMultiplier` | 25 (25/0/0) | self_play/awareness.lua:61<br>self_play/lane_spacing.lua:61 | api.lua | ``NPC.GetMagicalArmorDamageMultiplier(npc):` **`number`**` (npc.md:587) | EARLY+LATE |
| `Ability.IsHidden` | 24 (24/0/0) | self_play/awareness.lua:43<br>self_play/intent.lua:43 | api.lua | ``Ability.IsHidden(ability):` **`boolean`**` (ability.md:457) | EARLY+LATE |
| `Item.IsItemEnabled` | 17 (17/0/0) | self_play/awareness.lua:45<br>self_play/consumables.lua:226 | loader.lua | ``Item.IsItemEnabled(item):` **`boolean`**` (item.md:230) | EARLY+LATE |
| `NPC.IsStructure` | 17 (17/0/0) | self_play/last_hit.lua:310<br>self_play/support_policy.lua:33 | api.lua | ``NPC.IsStructure(npc):` **`boolean`**` (npc.md:225) | EARLY+LATE |
| `NPC.MoveTo` | 15 (15/0/0) | self_play/creep_block.lua:152<br>self_play/last_hit.lua:631 | api.lua | ``NPC.MoveTo(npc, position, [queue], [show], [callback], [executeFast], [identifier], [force_minimap]):` **`nil`**` (npc.md:1212) | EARLY+LATE |
| `NPC.IsTower` | 13 (13/0/0) | self_play/last_hit.lua:89<br>self_play/last_hit.lua:464 | api.lua | ``NPC.IsTower(npc):` **`boolean`**` (npc.md:235) | EARLY+LATE |
| `Ability.IsPassive` | 13 (13/0/0) | self_play/awareness.lua:43<br>self_play/lane_spacing.lua:40 | api.lua | ``Ability.IsPassive(ability, [from_static_data]):` **`boolean`**` (ability.md:70) | EARLY+LATE |
| `Item.GetCost` | 12 (12/0/0) | self_play/shop.lua:398<br>self_play/shop.lua:434 | loader.lua | ``Item.GetCost(item):` **`integer`**` (item.md:264) | EARLY+LATE |
| `Tower.GetAttackTarget` | 9 (8/0/1) | self_play/last_hit.lua:89<br>self_play/tower_safety.lua:21 | loader.lua | **UNVERIFIED** (no doc) | EARLY+LATE |
| `Trees.InRadius` | 8 (5/1/2) | self_play/field.lua:14 [value]<br>self_play/field.lua:15 [pcall] | loader.lua | **UNVERIFIED — cross-ns lookalike heroes.md:39 is NON-AUTHORITATIVE** | EARLY+LATE |
| `GameRules.GetGameStartTime` | 7 (5/0/2) | self_play/shop.lua:641 [value]<br>self_play/shop.lua:641 | api.lua | ``GameRules.GetGameStartTime():` **`number`**` (gamerules.md:35) | EARLY+LATE |
| `Config.ReadInt` | 7 (7/0/0) | self_play/build_brain.lua:330<br>self_play/shop.lua:67 | api.lua | ``Config.ReadInt(config, key, [def]):` **`integer`**` (config.md:7) | EARLY+LATE |
| `Config.WriteInt` | 6 (6/0/0) | self_play/build_brain.lua:336<br>self_play/shop.lua:331 | api.lua | ``Config.WriteInt(config, key, value):` **`nil`**` (config.md:43) | EARLY+LATE |
| `Ability.GetDamageType` | 6 (6/0/0) | self_play/awareness.lua:59<br>self_play/shop.lua:120 | api.lua | ``Ability.GetDamageType(ability):` [**`Enum.DamageTypes`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.damagetypes)` (ability.md:113) | EARLY+LATE |
| `Heroes.GetAll` | 6 (6/0/0) | self_play/shop.lua:98<br>self_play/strategy.lua:26 | api.lua | ``Heroes.GetAll():` [**`CHero[]`**](/api-v2.0/game-components/core/hero.md)` (heroes.md:23) | EARLY+LATE |
| `NPC.GetBountyXP` | 4 (4/0/0) | self_play/last_hit.lua:584<br>self_play/last_hit.lua:584 | api.lua | ``NPC.GetBountyXP(npc):` **`integer`**` (npc.md:1182) | EARLY+LATE |
| `HTTP.Request` | 4 (4/0/0) | self_play/build_brain.lua:320<br>self_play/shop.lua:317 | loader.lua | **UNVERIFIED** (no doc) | EARLY+LATE |
| `GameRules.GetMatchID` | 4 (2/0/2) | self_play/shop.lua:640 [value]<br>self_play/shop.lua:640 | api.lua | ``GameRules.GetMatchID():` **`integer`**` (gamerules.md:108) | EARLY+LATE |
| `Hero.GetRespawnTime` | 4 (4/0/0) | self_play/strategy.lua:15<br>self_play/strategy.lua:32 | api.lua | `\`Hero.GetRespawnTime(hero):\` \*\*\`number\`\*\*` (hero.md:29) | EARLY+LATE |
| `Entity.GetTreesInRadius` | 3 (3/0/0) | self_play/consumables.lua:115<br>self_play/consumables.lua:291 | api.lua | ``Entity.GetTreesInRadius(entity, radius, [active]):` [**`CTree[]`**](/api-v2.0/game-components/core/tree.md)` (entity.md:355) | EARLY+LATE |
| `NPC.HasShard` | 3 (3/0/0) | self_play/shop.lua:46<br>self_play/shop.lua:666 | api.lua | ``NPC.HasShard(npc):` **`boolean`**` (npc.md:1250) | EARLY+LATE |
| `Runes.GetAll` | 2 (2/0/0) | self_play/runes.lua:130<br>self_play/runes.lua:293 | loader.lua | **UNVERIFIED — cross-ns lookalike entities.md:7 is NON-AUTHORITATIVE** | EARLY |
| `Hero.GetLastMaphackPos` | 2 (2/0/0) | self_play/awareness.lua:102<br>self_play/strategy.lua:36 | api.lua | ``Hero.GetLastMaphackPos(hero):` [**`Vector`**](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | **`nil`**` (hero.md:243) | EARLY |
| `Entity.GetTempTreesInRadius` | 2 (2/0/0) | self_play/consumables.lua:88<br>self_play/consumables.lua:114 | api.lua | `\`Entity.GetTempTreesInRadius(entity, radius):\` \[\*\*\`CTree\[]\`\*\*]\(Tree.md)` (entity.md:383) | EARLY |
| `Hero.GetLastVisibleTime` | 2 (2/0/0) | self_play/awareness.lua:104<br>self_play/strategy.lua:37 | api.lua | ``Hero.GetLastVisibleTime(hero):` **`number`** | **`nil`**` (hero.md:253) | EARLY |
| `Item.GetStockCount` | 2 (2/0/0) | self_play/shop.lua:18<br>self_play/shop.lua:485 | loader.lua | `\`Item.GetStockCount(item\_id, \[team]):\` \*\*\`integer\`\*\*` (item.md:274) | EARLY |
| `Ability.GetCastPoint` | 56 (56/0/0) | self_play/awareness.lua:67 | api.lua | ``Ability.GetCastPoint(ability, [include_modifiers]):` **`number`**` (ability.md:209) | EARLY+LATE |
| `NPC.GetCurrentLevel` | 27 (27/0/0) | self_play/strategy.lua:136 | api.lua | ``NPC.GetCurrentLevel(npc):` **`number`**` (npc.md:1006) | EARLY+LATE |
| `Ability.GetCooldown` | 21 (21/0/0) | self_play/awareness.lua:70 | api.lua | ``Ability.GetCooldown(ability):` **`number`**` (ability.md:508) | EARLY+LATE |
| `NPC.IsCreep` | 21 (21/0/0) | self_play/strategy.lua:97 | api.lua | ``NPC.IsCreep(npc):` **`boolean`**` (npc.md:205) | EARLY+LATE |
| `NPC.IsNeutral` | 20 (20/0/0) | self_play/strategy.lua:97 | api.lua | ``NPC.IsNeutral(npc):` **`boolean`**` (npc.md:327) | EARLY+LATE |
| `NPC.GetModifier` | 18 (18/0/0) | self_play/runes.lua:165 | api.lua | ``NPC.GetModifier(npc, name):` [**`CModifier`**](/api-v2.0/game-components/core/modifier.md) | **`nil`**` (npc.md:52) | EARLY+LATE |
| `NPC.IsWaitingToSpawn` | 15 (15/0/0) | self_play/waves.lua:26 | api.lua | ``NPC.IsWaitingToSpawn(npc):` **`boolean`**` (npc.md:145) | EARLY+LATE |
| `Ability.GetDamage` | 14 (14/0/0) | self_play/awareness.lua:52 | api.lua | ``Ability.GetDamage(ability):` **`number`**` (ability.md:178) | EARLY+LATE |
| `NPC.IsFort` | 14 (14/0/0) | self_play/strategy.lua:153 | api.lua | ``NPC.IsFort(npc):` **`boolean`**` (npc.md:275) | EARLY+LATE |
| `Entity.GetRotation` | 14 (14/0/0) | self_play/last_hit.lua:45 | api.lua | ``Entity.GetRotation(entity):` [**`Angle`**](/api-v2.0/cheats-types-and-callbacks/classes/math/angle.md)` (entity.md:164) | EARLY+LATE |
| `NPC.GetBarriers` | 12 (11/0/1) | self_play/last_hit.lua:541 | api.lua | ``NPC.GetBarriers(npc):` **`{physical:{total:number, current:number}, magic:{total:number, current:number}, all:{total:number, current:number}}`** | **`nil`**` (npc.md:1322) | EARLY+LATE |
| `Ability.IsCastable` | 12 (12/0/0) | self_play/intent.lua:44 | api.lua | ``Ability.IsCastable(ability, [mana]):` **`boolean`**` (ability.md:230) | EARLY+LATE |
| `Ability.IsActivated` | 10 (10/0/0) | self_play/awareness.lua:44 | api.lua | ``Ability.IsActivated(ability):` **`boolean`**` (ability.md:467) | EARLY+LATE |
| `NPC.GetStatesDuration` | 8 (5/1/2) | self_play/awareness.lua:23 | api.lua | ``NPC.GetStatesDuration(npc, states, [only_active_states]):` **`table<Enum.ModifierState, number>`**` (npc.md:121) | EARLY+LATE |
| `Player.GetTeamPlayer` | 8 (4/3/1) | self_play/strategy.lua:175 | api.lua | ``Player.GetTeamPlayer(player, [output]):` **`{reliable_gold:integer, unreliable_gold:integer, starting_position:integer, totalearned_gold:integer, totalearned_xp:integer, shared_gold:integer…` (player.md:144) | EARLY+LATE |
| `NPC.IsBarracks` | 8 (8/0/0) | self_play/strategy.lua:154 | api.lua | ``NPC.IsBarracks(npc):` **`boolean`**` (npc.md:265) | EARLY+LATE |
| `NPC.GetTrueMaximumDamage` | 5 (5/0/0) | self_play/last_hit.lua:69 | api.lua | ``NPC.GetTrueMaximumDamage(npc):` **`number`**` (npc.md:887) | EARLY+LATE |
| `Tree.IsActive` | 5 (5/0/0) | self_play/consumables.lua:89 | loader.lua | **UNVERIFIED** (no doc) | EARLY+LATE |
| `NPC.HasScepter` | 4 (4/0/0) | self_play/shop.lua:48 | api.lua | ``NPC.HasScepter(npc):` **`boolean`**` (npc.md:1240) | EARLY+LATE |
| `NPC.GetManaRegen` | 4 (4/0/0) | self_play/shop.lua:449 | api.lua | ``NPC.GetManaRegen(npc):` **`number`**` (npc.md:972) | EARLY+LATE |
| `Player.AttackTarget` | 4 (4/0/0) | self_play/positioning.lua:172 | api.lua | ``Player.AttackTarget(player, issuer_npc, target, [queue], [push], [execute_fast], [identifier], [force_minimap]):` **`nil`**` (player.md:44) | EARLY+LATE |
| `Engine.GetCheatDirectory` | 3 (2/1/0) | self_play/build_brain.lua:285 | api.lua | ``Engine.GetCheatDirectory():` **`string`**` (engine.md:158) | EARLY+LATE |
| `Item.GetPlayerOwnerID` | 3 (3/0/0) | self_play/shop.lua:28 | loader.lua | ``Item.GetPlayerOwnerID(item):` **`integer`**` (item.md:254) | EARLY+LATE |
| `Item.IsSellable` | 3 (3/0/0) | self_play/shop.lua:720 | loader.lua | ``Item.IsSellable(item):` **`boolean`**` (item.md:79) | EARLY+LATE |
| `NPC.GetAttackProjectileSpeed` | 2 (2/0/0) | self_play/last_hit.lua:23 | api.lua | ``NPC.GetAttackProjectileSpeed(npc):` **`integer`** | **`nil`**` (npc.md:742) | EARLY+LATE |
| `NPC.GetGoldBountyMin` | 2 (2/0/0) | self_play/last_hit.lua:583 | api.lua | ``NPC.GetGoldBountyMin(npc):` **`integer`**` (npc.md:1192) | EARLY+LATE |
| `Ability.CastNoTarget` | 2 (2/0/0) | self_play/consumables.lua:233 | api.lua | ``Ability.CastNoTarget(ability, [queue], [push], [execute_fast], [identifier]):` **`nil`**` (ability.md:333) | EARLY+LATE |
| `Item.IsStackable` | 1 (1/0/0) | self_play/shop.lua:557 | loader.lua | ``Item.IsStackable(item):` **`boolean`**` (item.md:29) | EARLY |
| `PowerTreads.GetStats` | 1 (1/0/0) | self_play/consumables.lua:229 | loader.lua | **UNVERIFIED** (no doc) | EARLY |
| `Humanizer.GetOrderQueue` | 1 (1/0/0) | self_play/creep_block.lua:130 | loader.lua | ``Humanizer.GetOrderQueue():` **`{player: CPlayer, orderType: Enum.UnitOrder, targetIndex: integer, position: Vector, abilityIndex: integer, orderIssuer: Enum.PlayerOrderIssuer, unit: CNPC`**…` (humanizer.md:35) | EARLY |
| `Modifier.GetCreationTime` | 1 (1/0/0) | self_play/runes.lua:167 | loader.lua | ``Modifier.GetCreationTime(modifier):` **`number`**` (modifier.md:83) | EARLY |
| `Couriers.GetAll` | 1 (1/0/0) | self_play/shop.lua:40 | loader.lua | **UNVERIFIED — cross-ns lookalike entities.md:7 is NON-AUTHORITATIVE** | EARLY |
| `Item.IsCombineLocked` | 1 (1/0/0) | self_play/shop.lua:356 | loader.lua | ``Item.IsCombineLocked(item):` **`boolean`**` (item.md:169) | EARLY |
| `Entity.GetClassName` | 1 (1/0/0) | self_play/runes.lua:117 | api.lua | ``Entity.GetClassName(entity):` **`string`**` (entity.md:93) | EARLY |
| `Entities.GetAll` | 1 (1/0/0) | self_play/runes.lua:116 | loader.lua | ``Entities.GetAll():` [**`CEntity[]`**](/api-v2.0/game-components/core/entity.md)` (entities.md:7) | EARLY |
| `NPC.IsAncient` | 15 (15/0/0) | *(core-list)* e.g. self_play/active_items.lua:416 | api.lua | ``NPC.IsAncient(npc):` **`boolean`**` (npc.md:307) | EARLY+LATE |
| `Entity.GetTeamNum` | 11 (11/0/0) | *(core-list)* e.g. Self Play.lua:312 | api.lua | ``Entity.GetTeamNum(entity):` [**`Enum.TeamNum`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.teamnum)` (entity.md:123) | EARLY+LATE |
| `Player.HoldPosition` | 5 (5/0/0) | *(core-list)* e.g. Self Play.lua:681 | api.lua | ``Player.HoldPosition(player, issuer_npc, [queue], [push], [execute_fast], [identifier]):` **`nil`**` (player.md:29) | EARLY+LATE |
| `Players.GetLocal` | 5 (5/0/0) | *(core-list)* e.g. Self Play.lua:1835 | api.lua | ``Players.GetLocal():` [**`CPlayer`**](/api-v2.0/game-components/core/player.md) | **`nil`**` (players.md:39) | EARLY+LATE |
| `Players.GetAll` | 5 (5/0/0) | *(core-list)* e.g. Self Play.lua:271 | api.lua | ``Players.GetAll():` [**`CPlayer[]`**](/api-v2.0/game-components/core/player.md)` (players.md:23) | EARLY+LATE |
| `Heroes.GetLocal` | 3 (3/0/0) | *(core-list)* e.g. Self Play.lua:1835 | api.lua | ``Heroes.GetLocal():` [**`CHero`**](/api-v2.0/game-components/core/hero.md) | **`nil`**` (heroes.md:54) | EARLY+LATE |
| `Hero.GetPlayerID` | 2 (2/0/0) | *(core-list)* e.g. Self Play.lua:277 | api.lua | ``Hero.GetPlayerID(hero):` **`integer`**` (hero.md:183) | EARLY+LATE |
| `NPC.GetGoldBountyMax` | 1 (1/0/0) | *(core-list)* e.g. self_play/heroes/tinker_farming.lua:113 | api.lua | ``NPC.GetGoldBountyMax(npc):` **`integer`**` (npc.md:1202) | EARLY+LATE |
| `GameRules.GetGameState` | 1 (1/0/0) | *(core-list)* e.g. Self Play.lua:1833 | api.lua | ``GameRules.GetGameState():` [**`Enum.GameState`**](https://uczone.gitbook.io/api-v2.0/game-components/game-engine/pages/VwVljl88Qnl7u9hhqRdw#enum.gamestate)` (gamerules.md:13) | EARLY+LATE |
| `GameRules.IsPaused` | 1 (1/0/0) | *(core-list)* e.g. Self Play.lua:1832 | api.lua | ``GameRules.IsPaused():` **`boolean`**` (gamerules.md:76) | EARLY+LATE |

### 3.2 EARLY-ADJACENT inputs & deliberate heuristic exclusions (v2)

- **`draft` (EXCLUDED; pre-game role/lane setup)**: `draft.lua` runs at match start (hero/role/lane assignment via `Player.GetTeamData(...).lane_selection_flags` at draft.lua:118/133). It is not a 0:00–5:00 lane action, but it *decides* the role/lane that the early path then follows — `Player.GetTeamData` therefore appears in §4 with **0 early sites**; `Player.GetTeamPlayer`'s single early site is strategy.lua:175 (economy snapshot), not a lane action.
- **`runes` (INCLUDED in the early heuristic)**: the 0:00 bounty-rune contest is a genuine early action (`runes.lua`, `runes.observe`), so its module counts as early-lane.
- **`couriers` (EXCLUDED)**: courier/delivery logistics; it does not choose lane/creep/wave/last-hit/XP/gold/role actions in the first minutes.
- **`inventory_cleanup` (EXCLUDED)**: backpack/TP housekeeping; not lane-decision input.
- **`heroes/*` (EXCLUDED from the baseline heuristic)**: hero-selective tactics modules only act for that hero, so counting them would tag every hero-specific API call as "early". Separate per-hero audit is recommended where the QA hero differs — for Treant, review `self_play/heroes/treant.lua`, `heroes/common.lua`, `heroes/tactics.lua` in addition to §3.
- **`strategy`/`planner` (INCLUDED)**: both run from match start and shape laning assignments/priorities; they contain no separate API surface beyond what §3 lists.

## 4. Top-24 riskiest EARLY-GAME functions (20 + 4 adjudication additions)

Selection: early-path use × call volume × semantic subtlety × approximation risk in a schema/synthetic bridge. **Early sites** is literal early-module call-site count (0 = core-list/pre-game entry — explained in its reasoning). Doc gaps: §5.

| # | Function | Early sites / Calls | Risk reasoning |
|---|---|---|---|
| 1 | `NPC.FindFacingNPC` | 9 / 35 | attack-target detection for every lane creep/hero; a wrong facing cosine or range approximation corrupts last-hit, deny, aggro and trade logic from 0:00. Doc exists, but relies on exact NPC facing/attack-range semantics; highest-volume early combat oracle. |
| 2 | `NPC.GetTrueDamage` | 15 / 81 | damage number used by last-hit/deny and trade math; must include damage bonuses and be exact enough to decide kills/denies; any smoothing breaks last-hit timing. |
| 3 | `NPC.GetTrueMaximumDamage` | 1 / 5 | upper damage bound for last-hit prediction; wrong bound produces missed denies/last hits in the first wave. |
| 4 | `NPC.GetAttackAnimPoint` | 6 / 9 | attack wind-up; last_hit computes release = now + castpoint (last_hit.lua:34/112). A nil/0 or KV-vs-seconds unit mismatch shifts every last-hit prediction by the wind-up. |
| 5 | `NPC.GetSecondsPerAttack` | 18 / 54 | attack cadence for cycle prediction; depends on attack-speed formula (base + IAS + BAT), used across lane predictions. |
| 6 | `NPC.GetAttackSpeed` | 7 / 10 | attack speed feeds wind-up and cycles (last_hit.lua:36/114); unit/scale mismatch is a classic timing bug class. |
| 7 | `NPC.IsAttacking` | 17 / 92 | current-activity oracle used to confirm attacks before they land; an approximation that misses auto-attacks breaks wind-up confirmation and creep-aggro warnings. |
| 8 | `NPC.IsRunning` | 6 / 35 | movement state drives retreat/engage and wave-block timing; wrong state causes stop/go thrash in lane. |
| 9 | `NPC.GetModifierProperty` | 3 / 7 | creep deny percent (CREEP_DENY_PERCENT) is required by denyable() every tick in lane (Self Play.lua:1936); a missing property changes deny thresholds. |
| 10 | `NPC.HasState` | 18 / 149 | state oracle (rooted/stunned/etc.) built on modifier scanning; wrong enum mapping changes lane safety and last-hit availability. |
| 11 | `NPC.GetStatesDuration` | 1 / 8 | table keyed by Enum.ModifierState is consumed by combat/awareness; missing keys or nil table cause wrong "can I step in" decisions early. |
| 12 | `Entity.GetRotation` | 1 / 14 | facing/aim used by cast geometry and attack prediction (last_hit.lua:45 early). Contract is an Angle object, NOT a number — diag mis-tag in the parity baseline was a type-contract error, not a value defect. |
| 13 | `Entity.GetAbsOrigin` | 152 / 709 | every distance/time computation; must match engine position within the precision used for 100u/60u decisions. |
| 14 | `Entity.GetHealth` | 48 / 294 | last-hit/deny thresholds every tick; rounding/smoothing changes which creeps are kill-able. |
| 15 | `Entity.GetMaxHealth` | 29 / 133 | denominator for health-fraction rules (deny <50%); error flips deny decisions. |
| 16 | `GridNav.IsTraversable` | 23 / 85 | used on the lane path; our bridge approximates the engine grid with entity A*, so a wrong walkable cell can stop wave-blocking/lane movement (fountain obstacle class). |
| 17 | `GridNav.BuildPath` | 8 / 16 | path used for every lane movement; empty/partial paths cause "no safe route" holds; must include tree walking for Treant and the optional npc_map argument. |
| 18 | `GridNav.CreateNpcMap/ReleaseNpcMap` | 4 / 4 (combined) | last_hit.lua:554-599 builds an NPC map for attack prediction, navigation.lua:297/299/300 wraps both in pcall. Contract must be create->query->release with nil-on-unavailable; counted channels matter (see §3). |
| 19 | `Hero.GetRecentDamage` | 3 / 42 | drives lane-trade and retreat decisions; must be hero-scoped per doc, not a global damage delta. |
| 20 | `Player.GetTeamData/Player.GetTeamPlayer` | 1 / 12 (combined) | GetTeamData has **0 early sites** (PRE-GAME role/lane input: draft.lua:118/133 reads lane_selection_flags to assign role/lane; it shapes 0:00-5:00 behaviour but is not an early call — wrong lane flags produced the support-idle role-4 suspect). GetTeamPlayer has 1 early site via strategy.lua:175 — a broad economy snapshot taken in the strategy module, not a lane action either. |
| 21 | `NPC.GetArmorDamageMultiplier` | 13 / 51 | physical damage reduction multiplier used for last-hit math and lane trades (adjudication addition); wrong armor curve flips creep damage thresholds. |
| 22 | `Hero.GetCurrentXP` | 0 / 2 | XP read used for level-timing decisions (adjudication addition); a wrong value changes when the bot expects level-ups and talent/ability planning. |
| 23 | `GameRules.GetGameTime` | 8 / 29 | absolute clock used by every timing rule (adjudication addition); the earlier absolute-vs-epoch clock defect class makes this a must-verify contract at 0:00. |
| 24 | `Entity.IsDormant` | 26 / 86 | dormant filtering for entity scans (adjudication addition); wrong dormant semantics include hidden/enemy units or drop valid creeps, corrupting wave and target lists. |

## 5. UNVERIFIED SEMANTICS (no umbrella_api documentation for the namespace)

No `<sub>` heading exists under the expected namespace doc. Where a same-name heading exists under another namespace it is shown in the last column as **NON-AUTHORITATIVE**; do not use it as this function's contract.

| Function | Calls (d/p/v) | Call sites (up to 3) | Owner | Tag | Cross-ns lookalike (NON-AUTHORITATIVE) |
|---|---|---|---|---|---|
| `World.GetGroundZ` | 31 (31/0/0) | Self Play.lua:732<br>Self Play.lua:754<br>Self Play.lua:1140 | loader.lua | EARLY+LATE |  |
| `NetChannel.GetAvgLatency` | 21 (21/0/0) | Self Play.lua:1023<br>self_play/creep_block.lua:7<br>self_play/creep_block.lua:7 | api.lua | EARLY+LATE |  |
| `Log.Write` | 11 (11/0/0) | self_play/log.lua:81<br>self_play/log.lua:87<br>self_play/log.lua:89 | api.lua | LATE/OTHER |  |
| `Tower.GetAttackTarget` | 9 (8/0/1) | Self Play.lua:476<br>Self Play.lua:527<br>Self Play.lua:566 | loader.lua | EARLY+LATE |  |
| `GC.GetSteamID` | 8 (8/0/0) | self_play/party_queue.lua:72<br>self_play/party_queue.lua:109<br>self_play/party_queue.lua:162 | loader.lua | LATE/OTHER |  |
| `Trees.InRadius` | 8 (5/1/2) | self_play/field.lua:14 [value]<br>self_play/field.lua:15 [pcall]<br>self_play/heroes/hoodwink.lua:6 | loader.lua | EARLY+LATE | heroes.md:39 |
| `Couriers.GetLocal` | 7 (7/0/0) | self_play/inventory_cleanup.lua:60<br>self_play/inventory_cleanup.lua:95<br>self_play/recovery.lua:67 | loader.lua | EARLY+LATE | heroes.md:54 |
| `FogOfWar.IsPointVisible` | 7 (6/0/1) | self_play/awareness.lua:151<br>self_play/awareness.lua:165<br>self_play/detection.lua:90 | api.lua + loader stub | EARLY+LATE |  |
| `Panorama.GetPanelByName` | 6 (6/0/0) | self_play/draft.lua:253<br>self_play/matchmaking.lua:103<br>self_play/matchmaking.lua:133 | loader.lua | LATE/OTHER |  |
| `Bottle.GetRuneType` | 5 (5/0/0) | self_play/combat.lua:83<br>self_play/consumables.lua:126<br>self_play/runes.lua:62 | loader.lua | EARLY+LATE |  |
| `Tree.IsActive` | 5 (5/0/0) | self_play/consumables.lua:89<br>self_play/heroes/hoodwink.lua:6<br>self_play/heroes/hoodwink.lua:8 | loader.lua | EARLY+LATE |  |
| `GC.SendMessage` | 5 (5/0/0) | self_play/matchmaking.lua:17<br>self_play/party_queue.lua:26<br>self_play/queue_account.lua:117 | loader.lua | LATE/OTHER |  |
| `HTTP.Request` | 4 (4/0/0) | self_play/build_brain.lua:320<br>self_play/draft_data.lua:95<br>self_play/party_queue.lua:49 | loader.lua | EARLY+LATE |  |
| `Runes.Contains` | 3 (3/0/0) | self_play/runes.lua:143<br>self_play/runes.lua:284<br>self_play/runes.lua:287 | loader.lua | EARLY | entities.md:13 |
| `Rune.GetRuneType` | 3 (3/0/0) | self_play/runes.lua:132<br>self_play/runes.lua:295<br>self_play/runes.lua:319 | loader.lua | EARLY |  |
| `Runes.GetAll` | 2 (2/0/0) | self_play/runes.lua:130<br>self_play/runes.lua:293 | loader.lua | EARLY | entities.md:7 |
| `TempTrees.InRadius` | 2 (1/0/1) | self_play/ward_spots.lua:50 [value]<br>self_play/ward_spots.lua:51 | loader.lua | LATE/OTHER | heroes.md:39 |
| `NetChannel.SendNetMessage` | 2 (2/0/0) | self_play/neutral_items.lua:134<br>self_play/neutral_items.lua:156 | api.lua | LATE/OTHER |  |
| `GlobalVars.GetAbsFrameTime` | 2 (1/0/1) | self_play/party_queue.lua:225 [value]<br>self_play/party_queue.lua:225 | api.lua + loader stub | LATE/OTHER |  |
| `PhysicalItems.GetAll` | 1 (1/0/0) | self_play/roshan.lua:329 | loader.lua | LATE/OTHER | entities.md:7 |
| `PhysicalItem.GetItem` | 1 (1/0/0) | self_play/roshan.lua:331 | loader.lua | LATE/OTHER | npc.md:17 |
| `TempTrees.GetAll` | 1 (1/0/0) | self_play/heroes/hoodwink.lua:7 | loader.lua | LATE/OTHER | entities.md:7 |
| `Input.IsInputCaptured` | 1 (1/0/0) | Self Play.lua:1860 | loader.lua | LATE/OTHER |  |
| `Couriers.GetAll` | 1 (1/0/0) | self_play/shop.lua:40 | loader.lua | EARLY | entities.md:7 |
| `PowerTreads.GetStats` | 1 (1/0/0) | self_play/consumables.lua:229 | loader.lua | EARLY |  |
| `Abilities.AttemptToUpgrade` | 1 (1/0/0) | self_play/talents.lua:35 | loader.lua | LATE/OTHER |  |

## 6. Full inventory by namespace (all functions)

Doc citations are authoritative only when they come from the namespace's own doc; cross-ns lookalikes are marked NON-AUTHORITATIVE. `Calls` = direct/pcall/value-ref total.

### NPC — npc.md — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `NPC.HasState` | 149 (149/0/0) | Self Play.lua:555<br>Self Play.lua:652<br>Self Play.lua:653 | ``NPC.HasState(npc, state):` **`boolean`**` (npc.md:110) | EARLY+LATE |
| `NPC.GetAttackRange` | 146 (146/0/0) | Self Play.lua:488<br>Self Play.lua:577<br>Self Play.lua:619 | ``NPC.GetAttackRange(npc):` **`integer`**` (npc.md:516) | EARLY+LATE |
| `NPC.GetAbility` | 142 (142/0/0) | self_play/combat.lua:449<br>self_play/deward.lua:65<br>self_play/heroes/ancient_apparition.lua:7 | ``NPC.GetAbility(npc, name):` [**`CAbility`**](/api-v2.0/game-components/core/ability.md) | **`nil`**` (npc.md:930) | EARLY+LATE |
| `NPC.IsIllusion` | 122 (122/0/0) | Self Play.lua:280<br>Self Play.lua:312<br>Self Play.lua:423 | ``NPC.IsIllusion(npc):` **`boolean`**` (npc.md:155) | EARLY+LATE |
| `NPC.HasModifier` | 114 (114/0/0) | Self Play.lua:1013<br>Self Play.lua:1386<br>Self Play.lua:1750 | ``NPC.HasModifier(npc, name):` **`boolean`**` (npc.md:41) | EARLY+LATE |
| `NPC.GetUnitName` | 111 (111/0/0) | Self Play.lua:291<br>Self Play.lua:313<br>Self Play.lua:334 | ``NPC.GetUnitName(npc):` **`string`**` (npc.md:1036) | EARLY+LATE |
| `NPC.GetMoveSpeed` | 103 (103/0/0) | Self Play.lua:457<br>Self Play.lua:651<br>Self Play.lua:661 | ``NPC.GetMoveSpeed(npc):` **`number`**` (npc.md:847) | EARLY+LATE |
| `NPC.IsHero` | 103 (103/0/0) | Self Play.lua:423<br>Self Play.lua:431<br>Self Play.lua:479 | ``NPC.IsHero(npc):` **`boolean`**` (npc.md:337) | EARLY+LATE |
| `NPC.IsAttacking` | 92 (92/0/0) | Self Play.lua:601<br>Self Play.lua:862<br>Self Play.lua:870 | ``NPC.IsAttacking(npc):` **`boolean`**` (npc.md:446) | EARLY+LATE |
| `NPC.GetAttackRangeBonus` | 89 (89/0/0) | Self Play.lua:577<br>Self Play.lua:619<br>Self Play.lua:656 | ``NPC.GetAttackRangeBonus(npc):` **`integer`**` (npc.md:526) | EARLY+LATE |
| `NPC.IsVisible` | 87 (87/0/0) | Self Play.lua:248<br>Self Play.lua:409<br>self_play/active_items.lua:29 | ``NPC.IsVisible(npc):` **`boolean`**` (npc.md:165) | EARLY+LATE |
| `NPC.GetTrueDamage` | 81 (81/0/0) | Self Play.lua:431<br>Self Play.lua:478<br>Self Play.lua:576 | ``NPC.GetTrueDamage(npc):` **`number`**` (npc.md:877) | EARLY+LATE |
| `NPC.GetMana` | 78 (78/0/0) | self_play/active_items.lua:52<br>self_play/active_items.lua:78<br>self_play/active_items.lua:90 | ``NPC.GetMana(npc):` **`number`**` (npc.md:952) | EARLY+LATE |
| `NPC.IsChannellingAbility` | 58 (58/0/0) | Self Play.lua:704<br>Self Play.lua:1387<br>Self Play.lua:1774 | ``NPC.IsChannellingAbility(npc):` **`boolean`**` (npc.md:412) | EARLY+LATE |
| `NPC.GetSecondsPerAttack` | 54 (54/0/0) | Self Play.lua:880<br>Self Play.lua:1637<br>Self Play.lua:1693 | ``NPC.GetSecondsPerAttack(npc, bIgnoreTempAttackSpeed):` **`number`**` (npc.md:1291) | EARLY+LATE |
| `NPC.GetArmorDamageMultiplier` | 51 (51/0/0) | Self Play.lua:478<br>Self Play.lua:576<br>Self Play.lua:664 | ``NPC.GetArmorDamageMultiplier(npc):` **`number`**` (npc.md:567) | EARLY+LATE |
| `NPC.GetItem` | 51 (51/0/0) | Self Play.lua:1011<br>Self Play.lua:1339<br>Self Play.lua:1339 | ``NPC.GetItem(npc, name, [isReal]):` [**`CItem`**](/api-v2.0/game-components/core/item.md) | **`nil`**` (npc.md:17) | EARLY+LATE |
| `NPC.IsStunned` | 50 (50/0/0) | Self Play.lua:652<br>Self Play.lua:1916<br>Self Play.lua:1949 | ``NPC.IsStunned(npc):` **`boolean`**` (npc.md:466) | EARLY+LATE |
| `NPC.IsLaneCreep` | 49 (49/0/0) | Self Play.lua:363<br>Self Play.lua:417<br>Self Play.lua:427 | ``NPC.IsLaneCreep(npc):` **`boolean`**` (npc.md:215) | EARLY+LATE |
| `NPC.GetMaxMana` | 38 (38/0/0) | self_play/active_items.lua:81<br>self_play/active_items.lua:388<br>self_play/combat.lua:221 | ``NPC.GetMaxMana(npc):` **`number`**` (npc.md:962) | EARLY+LATE |
| `NPC.GetItemByIndex` | 37 (37/0/0) | self_play/awareness.lua:77<br>self_play/combat.lua:845<br>self_play/consumables.lua:52 | ``NPC.GetItemByIndex(npc, index):` [**`CItem`**](/api-v2.0/game-components/core/item.md) | **`nil`**` (npc.md:897) | EARLY+LATE |
| `NPC.IsRunning` | 35 (35/0/0) | Self Play.lua:366<br>Self Play.lua:736<br>Self Play.lua:1129 | ``NPC.IsRunning(npc):` **`boolean`**` (npc.md:436) | EARLY+LATE |
| `NPC.FindFacingNPC` | 35 (35/0/0) | Self Play.lua:1660<br>self_play/active_items.lua:135<br>self_play/awareness.lua:323 | ``NPC.FindFacingNPC(npc, ignoreNpc, [team_type], [angle], [distance]):` [**`CNPC`**](/api-v2.0/game-components/core/npc.md) | **`nil`**` (npc.md:823) | EARLY+LATE |
| `NPC.GetHullRadius` | 29 (29/0/0) | Self Play.lua:871<br>Self Play.lua:1040<br>self_play/base_defense.lua:318 | ``NPC.GetHullRadius(npc):` **`number`**` (npc.md:660) | EARLY+LATE |
| `NPC.IsRanged` | 29 (29/0/0) | self_play/base_defense.lua:367<br>self_play/combat.lua:148<br>self_play/combat.lua:149 | ``NPC.IsRanged(npc):` **`boolean`**` (npc.md:195) | EARLY+LATE |
| `NPC.GetAbilityByIndex` | 27 (27/0/0) | self_play/active_items.lua:40<br>self_play/active_items.lua:109<br>self_play/active_items.lua:335 | ``NPC.GetAbilityByIndex(npc, index):` [**`CAbility`**](/api-v2.0/game-components/core/ability.md) | **`nil`**` (npc.md:908) | EARLY+LATE |
| `NPC.GetCurrentLevel` | 27 (27/0/0) | self_play/combat.lua:378<br>self_play/combat.lua:445<br>self_play/combat.lua:490 | ``NPC.GetCurrentLevel(npc):` **`number`**` (npc.md:1006) | EARLY+LATE |
| `NPC.GetMagicalArmorDamageMultiplier` | 25 (25/0/0) | Self Play.lua:2214<br>self_play/active_items.lua:281<br>self_play/awareness.lua:61 | ``NPC.GetMagicalArmorDamageMultiplier(npc):` **`number`**` (npc.md:587) | EARLY+LATE |
| `NPC.GetHealthRegen` | 23 (23/0/0) | self_play/combat.lua:265<br>self_play/combat.lua:732<br>self_play/combat.lua:801 | ``NPC.GetHealthRegen(npc):` **`number`**` (npc.md:982) | EARLY+LATE |
| `NPC.IsCreep` | 21 (21/0/0) | Self Play.lua:363<br>Self Play.lua:428<br>self_play/active_items.lua:489 | ``NPC.IsCreep(npc):` **`boolean`**` (npc.md:205) | EARLY+LATE |
| `NPC.IsNeutral` | 20 (20/0/0) | Self Play.lua:428<br>self_play/combat.lua:521<br>self_play/domination.lua:41 | ``NPC.IsNeutral(npc):` **`boolean`**` (npc.md:327) | EARLY+LATE |
| `NPC.IsSilenced` | 18 (18/0/0) | self_play/active_items.lua:124<br>self_play/active_items.lua:173<br>self_play/active_items.lua:305 | ``NPC.IsSilenced(npc):` **`boolean`**` (npc.md:456) | EARLY+LATE |
| `NPC.GetModifier` | 18 (18/0/0) | Self Play.lua:1638<br>self_play/deward.lua:42<br>self_play/engagement.lua:53 | ``NPC.GetModifier(npc, name):` [**`CModifier`**](/api-v2.0/game-components/core/modifier.md) | **`nil`**` (npc.md:52) | EARLY+LATE |
| `NPC.IsStructure` | 17 (17/0/0) | Self Play.lua:422<br>Self Play.lua:430<br>Self Play.lua:846 | ``NPC.IsStructure(npc):` **`boolean`**` (npc.md:225) | EARLY+LATE |
| `NPC.IsRoshan` | 17 (17/0/0) | Self Play.lua:428<br>self_play/combat.lua:522<br>self_play/domination.lua:42 | ``NPC.IsRoshan(npc):` **`boolean`**` (npc.md:317) | LATE/OTHER |
| `NPC.IsAncient` | 15 (15/0/0) | self_play/active_items.lua:416<br>self_play/domination.lua:9<br>self_play/domination.lua:43 | ``NPC.IsAncient(npc):` **`boolean`**` (npc.md:307) | EARLY+LATE |
| `NPC.MoveTo` | 15 (15/0/0) | Self Play.lua:792<br>self_play/combat.lua:632<br>self_play/creep_block.lua:152 | ``NPC.MoveTo(npc, position, [queue], [show], [callback], [executeFast], [identifier], [force_minimap]):` **`nil`**` (npc.md:1212) | EARLY+LATE |
| `NPC.IsWaitingToSpawn` | 15 (15/0/0) | Self Play.lua:407<br>Self Play.lua:837<br>self_play/combat.lua:520 | ``NPC.IsWaitingToSpawn(npc):` **`boolean`**` (npc.md:145) | EARLY+LATE |
| `NPC.IsFort` | 14 (14/0/0) | Self Play.lua:1269<br>self_play/base_defense.lua:20<br>self_play/base_defense.lua:139 | ``NPC.IsFort(npc):` **`boolean`**` (npc.md:275) | EARLY+LATE |
| `NPC.IsMeepoClone` | 13 (13/0/0) | Self Play.lua:280<br>Self Play.lua:312<br>Self Play.lua:423 | ``NPC.IsMeepoClone(npc):` **`boolean`**` (npc.md:357) | EARLY+LATE |
| `NPC.IsTower` | 13 (13/0/0) | Self Play.lua:421<br>Self Play.lua:898<br>Self Play.lua:899 | ``NPC.IsTower(npc):` **`boolean`**` (npc.md:235) | EARLY+LATE |
| `NPC.IsTormentor` | 12 (12/0/0) | Self Play.lua:428<br>self_play/combat.lua:522<br>self_play/domination.lua:42 | ``NPC.IsTormentor(npc):` **`boolean`**` (npc.md:296) | LATE/OTHER |
| `NPC.GetBarriers` | 12 (11/0/1) | Self Play.lua:523<br>self_play/base_defense.lua:225<br>self_play/combat.lua:798 | ``NPC.GetBarriers(npc):` **`{physical:{total:number, current:number}, magic:{total:number, current:number}, all:{total:number, current:number}}`** | **`nil`**` (npc.md:1322) | EARLY+LATE |
| `NPC.GetAttackSpeed` | 10 (10/0/0) | self_play/engagement.lua:66<br>self_play/heroes/ancient_apparition.lua:71<br>self_play/heroes/common.lua:185 | ``NPC.GetAttackSpeed(npc, [ignore_temp_attack_speed]):` **`number`**` (npc.md:639) | EARLY+LATE |
| `NPC.IsInRangeOfShop` | 10 (10/0/0) | self_play/inventory_cleanup.lua:118<br>self_play/inventory_cleanup.lua:131<br>self_play/shop.lua:577 | ``NPC.IsInRangeOfShop(npc, shop_type, [specific]):` **`boolean`**` (npc.md:1372) | EARLY+LATE |
| `NPC.GetAttackAnimPoint` | 9 (9/0/0) | self_play/engagement.lua:52<br>self_play/heroes/ancient_apparition.lua:71<br>self_play/heroes/common.lua:184 | ``NPC.GetAttackAnimPoint(npc):` **`number`** | **`nil`**` (npc.md:728) | EARLY+LATE |
| `NPC.GetTimeToFace` | 9 (9/0/0) | self_play/engagement.lua:65<br>self_play/lane_spacing.lua:118<br>self_play/lane_spacing.lua:231 | ``NPC.GetTimeToFace(npc, target):` **`number`**` (npc.md:790) | EARLY+LATE |
| `NPC.IsBarracks` | 8 (8/0/0) | self_play/base_defense.lua:20<br>self_play/base_defense.lua:132<br>self_play/base_defense.lua:139 | ``NPC.IsBarracks(npc):` **`boolean`**` (npc.md:265) | EARLY+LATE |
| `NPC.GetStatesDuration` | 8 (5/1/2) | self_play/awareness.lua:23<br>self_play/combat.lua:751 [value]<br>self_play/combat.lua:751 | ``NPC.GetStatesDuration(npc, states, [only_active_states]):` **`table<Enum.ModifierState, number>`**` (npc.md:121) | EARLY+LATE |
| `NPC.IsEntityInRange` | 7 (7/0/0) | Self Play.lua:853<br>Self Play.lua:863<br>Self Play.lua:869 | ``NPC.IsEntityInRange(npc, npc2, range):` **`boolean`**` (npc.md:367) | EARLY+LATE |
| `NPC.GetModifierProperty` | 7 (7/0/0) | Self Play.lua:843<br>Self Play.lua:1936<br>self_play/engagement.lua:147 | ``NPC.GetModifierProperty(npc, property):` **`number`**` (npc.md:1394) | EARLY+LATE |
| `NPC.GetTimeToFacePosition` | 6 (6/0/0) | self_play/creep_block.lua:94<br>self_play/creep_block.lua:107<br>self_play/creep_block.lua:388 | ``NPC.GetTimeToFacePosition(npc, pos):` **`number`**` (npc.md:812) | EARLY+LATE |
| `NPC.IsLinkensProtected` | 5 (5/0/0) | self_play/active_items.lua:174<br>self_play/active_items.lua:216<br>self_play/combat.lua:151 | ``NPC.IsLinkensProtected(npc):` **`boolean`**` (npc.md:392) | LATE/OTHER |
| `NPC.GetModifiers` | 5 (4/0/1) | self_play/heroes/arc_warden.lua:32<br>self_play/heroes/arc_warden.lua:142 [value]<br>self_play/heroes/arc_warden.lua:143 | `\`poperty\_filter\` doesn\`t filter all modifiers every call, it uses already prefiltered list. {% endhint %} \`NPC.GetModifiers(npc, \[poperty\_filter]):\` \[\*\*\`CModifier\[]\`\*\*]\(Modi…` (npc.md:63) | LATE/OTHER |
| `NPC.GetTrueMaximumDamage` | 5 (5/0/0) | self_play/base_defense.lua:65<br>self_play/fight_sim.lua:268<br>self_play/jungle.lua:136 | ``NPC.GetTrueMaximumDamage(npc):` **`number`**` (npc.md:887) | EARLY+LATE |
| `NPC.GetManaRegen` | 4 (4/0/0) | self_play/heroes/tinker_farming.lua:341<br>self_play/heroes/tinker_farming.lua:392<br>self_play/recovery.lua:18 | ``NPC.GetManaRegen(npc):` **`number`**` (npc.md:972) | EARLY+LATE |
| `NPC.GetBountyXP` | 4 (4/0/0) | self_play/active_items.lua:418<br>self_play/heroes/arc_warden.lua:54<br>self_play/last_hit.lua:584 | ``NPC.GetBountyXP(npc):` **`integer`**` (npc.md:1182) | EARLY+LATE |
| `NPC.HasScepter` | 4 (4/0/0) | self_play/heroes/kez.lua:15<br>self_play/heroes/lone_druid.lua:83<br>self_play/heroes/lone_druid.lua:97 | ``NPC.HasScepter(npc):` **`boolean`**` (npc.md:1240) | EARLY+LATE |
| `NPC.HasShard` | 3 (3/0/0) | self_play/heroes/aim.lua:20<br>self_play/shop.lua:46<br>self_play/shop.lua:666 | ``NPC.HasShard(npc):` **`boolean`**` (npc.md:1250) | EARLY+LATE |
| `NPC.IsWard` | 3 (3/0/0) | Self Play.lua:431<br>self_play/heroes/invoker.lua:263<br>self_play/units.lua:68 | ``NPC.IsWard(npc):` **`boolean`**` (npc.md:347) | LATE/OTHER |
| `NPC.IsControllableByPlayer` | 3 (3/0/0) | self_play/units.lua:33<br>self_play/units.lua:62<br>self_play/units.lua:65 | ``NPC.IsControllableByPlayer(npc, playerId):` **`boolean`**` (npc.md:1405) | LATE/OTHER |
| `NPC.IsCourier` | 3 (3/0/0) | Self Play.lua:430<br>Self Play.lua:2166<br>self_play/units.lua:59 | ``NPC.IsCourier(npc):` **`boolean`**` (npc.md:185) | LATE/OTHER |
| `NPC.GetGoldBountyMin` | 2 (2/0/0) | self_play/last_hit.lua:583<br>self_play/map_farm.lua:82 | ``NPC.GetGoldBountyMin(npc):` **`integer`**` (npc.md:1192) | EARLY+LATE |
| `NPC.GetOwnerNPC` | 2 (1/0/1) | self_play/coordination.lua:29 [value]<br>self_play/coordination.lua:30 | ``NPC.GetOwnerNPC(npc):` [**`CNPC`**](/api-v2.0/game-components/core/npc.md) | **`nil`**` (npc.md:7) | LATE/OTHER |
| `NPC.GetAttackProjectileSpeed` | 2 (2/0/0) | self_play/engagement.lua:58<br>self_play/last_hit.lua:23 | ``NPC.GetAttackProjectileSpeed(npc):` **`integer`** | **`nil`**` (npc.md:742) | EARLY+LATE |
| `NPC.GetGoldBountyMax` | 1 (1/0/0) | self_play/heroes/tinker_farming.lua:113 | ``NPC.GetGoldBountyMax(npc):` **`integer`**` (npc.md:1202) | EARLY+LATE |
| `NPC.IsMirrorProtected` | 1 (1/0/0) | self_play/combat.lua:151 | ``NPC.IsMirrorProtected(npc):` **`boolean`**` (npc.md:402) | LATE/OTHER |
| `NPC.IsVisibleToEnemies` | 1 (1/0/0) | self_play/heroes/tinker.lua:60 | ``NPC.IsVisibleToEnemies(npc):` **`boolean`**` (npc.md:175) | LATE/OTHER |

### Entity — entity.md — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Entity.GetAbsOrigin` | 709 (709/0/0) | Self Play.lua:345<br>Self Play.lua:363<br>Self Play.lua:365 | ``Entity.GetAbsOrigin(entity):` [**`Vector`**](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)` (entity.md:144) | EARLY+LATE |
| `Entity.GetHealth` | 294 (294/0/0) | Self Play.lua:450<br>Self Play.lua:475<br>Self Play.lua:480 | ``Entity.GetHealth(entity):` **`integer`**` (entity.md:239) | EARLY+LATE |
| `Entity.IsSameTeam` | 201 (201/0/0) | Self Play.lua:279<br>Self Play.lua:408<br>Self Play.lua:477 | ``Entity.IsSameTeam(entity1, entity2):` **`boolean`**` (entity.md:133) | EARLY+LATE |
| `Entity.GetIndex` | 170 (169/0/1) | Self Play.lua:273<br>Self Play.lua:279<br>Self Play.lua:313 | ``Entity.GetIndex(entity):` **`integer`**` (entity.md:83) | EARLY+LATE |
| `Entity.IsAlive` | 164 (164/0/0) | Self Play.lua:244<br>Self Play.lua:1101<br>Self Play.lua:1321 | ``Entity.IsAlive(entity):` **`boolean`**` (entity.md:219) | EARLY+LATE |
| `Entity.IsEntity` | 154 (154/0/0) | Self Play.lua:244<br>Self Play.lua:273<br>Self Play.lua:277 | ``Entity.IsEntity(entity):` **`boolean`**` (entity.md:9) | EARLY+LATE |
| `Entity.GetMaxHealth` | 133 (133/0/0) | Self Play.lua:475<br>Self Play.lua:480<br>Self Play.lua:515 | ``Entity.GetMaxHealth(entity):` **`integer`**` (entity.md:249) | EARLY+LATE |
| `Entity.IsDormant` | 86 (86/0/0) | Self Play.lua:244<br>self_play/active_items.lua:29<br>self_play/awareness.lua:15 | ``Entity.IsDormant(entity):` **`boolean`**` (entity.md:229) | EARLY+LATE |
| `Entity.IsNPC` | 16 (16/0/0) | self_play/combat.lua:519<br>self_play/deward.lua:10<br>self_play/heroes/tinker_farming.lua:9 | ``Entity.IsNPC(entity):` **`boolean`**` (entity.md:19) | EARLY+LATE |
| `Entity.GetRotation` | 14 (14/0/0) | self_play/active_items.lua:176<br>self_play/combat.lua:625<br>self_play/combat.lua:773 | ``Entity.GetRotation(entity):` [**`Angle`**](/api-v2.0/cheats-types-and-callbacks/classes/math/angle.md)` (entity.md:164) | EARLY+LATE |
| `Entity.GetTeamNum` | 11 (11/0/0) | Self Play.lua:312<br>Self Play.lua:328<br>self_play/draft.lua:132 | ``Entity.GetTeamNum(entity):` [**`Enum.TeamNum`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.teamnum)` (entity.md:123) | EARLY+LATE |
| `Entity.GetField` | 5 (5/0/0) | self_play/objectives.lua:263<br>self_play/objectives.lua:263<br>self_play/objectives.lua:288 | ``Entity.GetField(entity, fieldName, [dbgPrint]):` **`any`**` (entity.md:448) | LATE/OTHER |
| `Entity.GetTreesInRadius` | 3 (3/0/0) | self_play/consumables.lua:115<br>self_play/consumables.lua:291<br>self_play/recovery.lua:45 | ``Entity.GetTreesInRadius(entity, radius, [active]):` [**`CTree[]`**](/api-v2.0/game-components/core/tree.md)` (entity.md:355) | EARLY+LATE |
| `Entity.GetOwner` | 3 (3/0/0) | self_play/heroes/earth_spirit.lua:13<br>self_play/heroes/ember_spirit.lua:23<br>self_play/heroes/ember_spirit.lua:37 | ``Entity.GetOwner(entity):` [**`CEntity`**](/api-v2.0/game-components/core/entity.md) | **`nil`**` (entity.md:259) | LATE/OTHER |
| `Entity.Get` | 3 (3/0/0) | self_play/heroes/tinker_farming.lua:145<br>self_play/teleports.lua:12<br>self_play/teleports.lua:16 | ``Entity.Get(index):` [**`CEntity`**](/api-v2.0/game-components/core/entity.md) | **`nil`**` (entity.md:59) | LATE/OTHER |
| `Entity.GetTempTreesInRadius` | 2 (2/0/0) | self_play/consumables.lua:88<br>self_play/consumables.lua:114 | `\`Entity.GetTempTreesInRadius(entity, radius):\` \[\*\*\`CTree\[]\`\*\*]\(Tree.md)` (entity.md:383) | EARLY |
| `Entity.GetClassName` | 1 (1/0/0) | self_play/runes.lua:117 | ``Entity.GetClassName(entity):` **`string`**` (entity.md:93) | EARLY |

### Ability — ability.md — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Ability.GetCastRange` | 124 (124/0/0) | self_play/active_items.lua:69<br>self_play/active_items.lua:169<br>self_play/active_items.lua:268 | ``Ability.GetCastRange(ability):` **`number`**` (ability.md:447) | EARLY+LATE |
| `Ability.GetName` | 102 (102/0/0) | self_play/active_items.lua:45<br>self_play/active_items.lua:90<br>self_play/active_items.lua:110 | ``Ability.GetName(ability):` **`string`**` (ability.md:253) | EARLY+LATE |
| `Ability.GetLevel` | 83 (83/0/0) | self_play/active_items.lua:41<br>self_play/active_items.lua:111<br>self_play/active_items.lua:337 | ``Ability.GetLevel(ability):` **`integer`**` (ability.md:199) | EARLY+LATE |
| `Ability.GetManaCost` | 72 (72/0/0) | self_play/active_items.lua:38<br>self_play/active_items.lua:46<br>self_play/active_items.lua:78 | ``Ability.GetManaCost(ability):` **`number`**` (ability.md:528) | EARLY+LATE |
| `Ability.GetCastPoint` | 56 (56/0/0) | self_play/awareness.lua:67<br>self_play/combat.lua:281<br>self_play/combat.lua:341 | ``Ability.GetCastPoint(ability, [include_modifiers]):` **`number`**` (ability.md:209) | EARLY+LATE |
| `Ability.IsReady` | 27 (27/0/0) | self_play/active_items.lua:88<br>self_play/active_items.lua:382<br>self_play/base_defense.lua:46 | ``Ability.IsReady(ability):` **`boolean`**` (ability.md:157) | EARLY+LATE |
| `Ability.IsHidden` | 24 (24/0/0) | self_play/active_items.lua:41<br>self_play/active_items.lua:88<br>self_play/active_items.lua:381 | ``Ability.IsHidden(ability):` **`boolean`**` (ability.md:457) | EARLY+LATE |
| `Ability.GetCooldown` | 21 (21/0/0) | self_play/active_items.lua:42<br>self_play/active_items.lua:111<br>self_play/awareness.lua:70 | ``Ability.GetCooldown(ability):` **`number`**` (ability.md:508) | EARLY+LATE |
| `Ability.GetToggleState` | 18 (18/0/0) | self_play/active_items.lua:153<br>self_play/combat.lua:653<br>self_play/combat.lua:827 | ``Ability.GetToggleState(ability):` **`boolean`**` (ability.md:487) | LATE/OTHER |
| `Ability.GetDamage` | 14 (14/0/0) | Self Play.lua:2212<br>self_play/active_items.lua:337<br>self_play/awareness.lua:52 | ``Ability.GetDamage(ability):` **`number`**` (ability.md:178) | EARLY+LATE |
| `Ability.IsPassive` | 13 (13/0/0) | self_play/active_items.lua:41<br>self_play/active_items.lua:382<br>self_play/active_items.lua:462 | ``Ability.IsPassive(ability, [from_static_data]):` **`boolean`**` (ability.md:70) | EARLY+LATE |
| `Ability.IsCastable` | 12 (12/0/0) | self_play/active_items.lua:90<br>self_play/active_items.lua:463<br>self_play/base_defense.lua:46 | ``Ability.IsCastable(ability, [mana]):` **`boolean`**` (ability.md:230) | EARLY+LATE |
| `Ability.GetLevelSpecialValueFor` | 12 (12/0/0) | self_play/heroes/aim.lua:58<br>self_play/heroes/arc_warden.lua:391<br>self_play/heroes/arc_warden.lua:406 | ``Ability.GetLevelSpecialValueFor(ability, name, [lvl]):` **`number`**` (ability.md:145) | LATE/OTHER |
| `Ability.GetBehavior` | 11 (11/0/0) | self_play/combat.lua:277<br>self_play/combat.lua:542<br>self_play/combat.lua:652 | ``Ability.GetBehavior(ability, [from_static_data]):` [**`Enum.AbilityBehavior`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.abilitybehavior)` (ability.md:59) | LATE/OTHER |
| `Ability.IsActivated` | 10 (10/0/0) | self_play/active_items.lua:41<br>self_play/active_items.lua:381<br>self_play/awareness.lua:44 | ``Ability.IsActivated(ability):` **`boolean`**` (ability.md:467) | EARLY+LATE |
| `Ability.IsUltimate` | 9 (9/0/0) | self_play/active_items.lua:47<br>self_play/combat.lua:468<br>self_play/combat.lua:537 | ``Ability.IsUltimate(ability):` **`boolean`**` (ability.md:29) | LATE/OTHER |
| `Ability.IsChannelling` | 7 (7/0/0) | Self Play.lua:1013<br>Self Play.lua:1014<br>self_play/combat.lua:297 | ``Ability.IsChannelling(ability):` **`boolean`**` (ability.md:242) | LATE/OTHER |
| `Ability.CanBeExecuted` | 6 (6/0/0) | Self Play.lua:2151<br>self_play/base_defense.lua:46<br>self_play/combat.lua:91 | ``Ability.CanBeExecuted(ability):` [**`Enum.AbilityCastResult`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.abilitycastresult)` (ability.md:313) | LATE/OTHER |
| `Ability.GetDamageType` | 6 (6/0/0) | Self Play.lua:2213<br>self_play/awareness.lua:59<br>self_play/combat.lua:579 | ``Ability.GetDamageType(ability):` [**`Enum.DamageTypes`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.damagetypes)` (ability.md:113) | EARLY+LATE |
| `Ability.Toggle` | 4 (4/0/0) | self_play/combat.lua:333<br>self_play/detection.lua:124<br>self_play/deward.lua:113 | ``Ability.Toggle(ability, [queue], [push], [execute_fast], [identifier]):` **`nil`**` (ability.md:378) | LATE/OTHER |
| `Ability.GetCurrentCharges` | 3 (3/0/0) | self_play/heroes/earth_spirit.lua:91<br>self_play/heroes/ember_spirit.lua:62<br>self_play/heroes/void_spirit.lua:40 | ``Ability.GetCurrentCharges(ability):` **`integer`**` (ability.md:620) | LATE/OTHER |
| `Ability.GetChannelStartTime` | 3 (3/0/0) | self_play/heroes/invoker.lua:120<br>self_play/heroes/tinker.lua:72<br>self_play/heroes/tinker.lua:78 | ``Ability.GetChannelStartTime(ability):` **`number`**` (ability.md:558) | LATE/OTHER |
| `Ability.IsInAbilityPhase` | 3 (3/0/0) | self_play/combat.lua:327<br>self_play/heroes/earth_spirit.lua:31<br>self_play/heroes/techies.lua:55 | ``Ability.IsInAbilityPhase(ability):` **`boolean`**` (ability.md:497) | LATE/OTHER |
| `Ability.SecondsSinceLastUse` | 3 (3/0/0) | self_play/active_items.lua:43<br>self_play/heroes/invoker.lua:679<br>self_play/heroes/rubick.lua:45 | ``Ability.SecondsSinceLastUse(ability):` **`number`**` (ability.md:167) | LATE/OTHER |
| `Ability.GetTargetTeam` | 2 (2/0/0) | self_play/combat.lua:137<br>self_play/combat.lua:696 | ``Ability.GetTargetTeam(ability, [from_static_data]):` [**`Enum.TargetTeam`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.targetteam)` (ability.md:81) | LATE/OTHER |
| `Ability.GetAutoCastState` | 2 (2/0/0) | self_play/combat.lua:698<br>self_play/heroes/huskar.lua:27 | ``Ability.GetAutoCastState(ability):` **`boolean`**` (ability.md:538) | LATE/OTHER |
| `Ability.CastPosition` | 2 (2/0/0) | self_play/recovery.lua:137<br>self_play/travel.lua:252 | ``Ability.CastPosition(ability, pos, [queue], [push], [execute_fast], [identifier], [force_minimap]):` **`nil`**` (ability.md:347) | LATE/OTHER |
| `Ability.CastNoTarget` | 2 (2/0/0) | self_play/consumables.lua:233<br>self_play/heroes/invoker.lua:356 | ``Ability.CastNoTarget(ability, [queue], [push], [execute_fast], [identifier]):` **`nil`**` (ability.md:333) | EARLY+LATE |
| `Ability.GetTargetType` | 1 (1/0/0) | self_play/combat.lua:136 | ``Ability.GetTargetType(ability, [from_static_data]):` [**`Enum.TargetType`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.targettype)` (ability.md:92) | LATE/OTHER |
| `Ability.CanBeUpgraded` | 1 (1/0/0) | self_play/combat.lua:457 | ``Ability.CanBeUpgraded(ability):` **`boolean`**` (ability.md:416) | LATE/OTHER |
| `Ability.GetTargetFlags` | 1 (1/0/0) | self_play/combat.lua:135 | ``Ability.GetTargetFlags(ability):` [**`Enum.TargetFlags`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.targetflags)` (ability.md:103) | LATE/OTHER |
| `Ability.ToggleMod` | 1 (1/0/0) | self_play/combat.lua:334 | ``Ability.ToggleMod(ability, [queue], [push], [execute_fast], [identifier]):` **`nil`**` (ability.md:392) | LATE/OTHER |

### GridNav — gridnav.md — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `GridNav.IsTraversable` | 85 (85/0/0) | Self Play.lua:370<br>Self Play.lua:748<br>Self Play.lua:755 | ``GridNav.IsTraversable(pos, [flag], [flag_excluded]):` **`boolean`**, **`integer`**` (gridnav.md:33) | EARLY+LATE |
| `GridNav.BuildPath` | 16 (15/1/0) | Self Play.lua:764<br>Self Play.lua:814<br>self_play/awareness.lua:157 | ``GridNav.BuildPath(start, end_, [ignoreTrees], [npc_map]):` [**`Vector[]`**](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)` (gridnav.md:53) | EARLY+LATE |
| `GridNav.CreateNpcMap` | 4 (2/1/1) | self_play/last_hit.lua:554<br>self_play/last_hit.lua:567<br>self_play/navigation.lua:268 [value] | `\`GridNav.CreateNpcMap(\[excluded\_npcs], \[includeTempTrees], \[customCollisionSizes]):\` \[\*\*\`GridNavNpcMap\`\*\*]\(GridNavNpcMap.md)` (gridnav.md:7) | EARLY |
| `GridNav.ReleaseNpcMap` | 3 (2/0/1) | self_play/last_hit.lua:599<br>self_play/navigation.lua:268 [value]<br>self_play/navigation.lua:300 | ``GridNav.ReleaseNpcMap(npc_map):` **`nil`**` (gridnav.md:23) | EARLY |

### Hero — hero.md — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Hero.GetRecentDamage` | 42 (42/0/0) | Self Play.lua:535<br>Self Play.lua:1780<br>self_play/active_items.lua:122 | ``Hero.GetRecentDamage(hero):` **`integer`**` (hero.md:143) | EARLY+LATE |
| `Hero.GetReplicatingOtherHeroModel` | 10 (10/0/0) | Self Play.lua:280<br>self_play/creep_block.lua:369<br>self_play/fights.lua:111 | ``Hero.GetReplicatingOtherHeroModel(hero):` [**`CHero`**](/api-v2.0/game-components/core/hero.md) | **`nil`**` (hero.md:193) | EARLY+LATE |
| `Hero.GetRespawnTime` | 4 (4/0/0) | self_play/recovery.lua:467<br>self_play/recovery.lua:480<br>self_play/strategy.lua:15 | `\`Hero.GetRespawnTime(hero):\` \*\*\`number\`\*\*` (hero.md:29) | EARLY+LATE |
| `Hero.GetPrimaryAttribute` | 3 (2/0/1) | self_play/consumables.lua:227<br>self_play/intent.lua:34 [value]<br>self_play/intent.lua:35 | ``Hero.GetPrimaryAttribute(hero):` [**`Enum.Attributes`**](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.attributes)` (hero.md:53) | EARLY |
| `Hero.GetCurrentXP` | 2 (1/0/1) | self_play/value.lua:47 [value]<br>self_play/value.lua:47 | ``Hero.GetCurrentXP(hero):` **`integer`**` (hero.md:9) | LATE/OTHER |
| `Hero.GetLastMaphackPos` | 2 (2/0/0) | self_play/awareness.lua:102<br>self_play/strategy.lua:36 | ``Hero.GetLastMaphackPos(hero):` [**`Vector`**](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | **`nil`**` (hero.md:243) | EARLY |
| `Hero.GetLastVisibleTime` | 2 (2/0/0) | self_play/awareness.lua:104<br>self_play/strategy.lua:37 | ``Hero.GetLastVisibleTime(hero):` **`number`** | **`nil`**` (hero.md:253) | EARLY |
| `Hero.GetPlayerID` | 2 (2/0/0) | Self Play.lua:277<br>Self Play.lua:335 | ``Hero.GetPlayerID(hero):` **`integer`**` (hero.md:183) | EARLY+LATE |
| `Hero.GetAbilityPoints` | 1 (1/0/0) | self_play/combat.lua:425 | ``Hero.GetAbilityPoints(hero):` **`integer`**` (hero.md:19) | LATE/OTHER |
| `Hero.GetStrength` | 1 (1/0/0) | self_play/heroes/morphling.lua:11 | ``Hero.GetStrength(hero):` **`number`**` (hero.md:63) | LATE/OTHER |
| `Hero.TalentIsLearned` | 1 (1/0/0) | self_play/combat.lua:381 | ``Hero.TalentIsLearned(hero, talent):` **`boolean`**` (hero.md:203) | LATE/OTHER |

### Item — item.md — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Item.GetCurrentCharges` | 27 (27/0/0) | self_play/active_items.lua:319<br>self_play/active_items.lua:393<br>self_play/combat.lua:82 | ``Item.GetCurrentCharges(item):` **`integer`**` (item.md:149) | EARLY+LATE |
| `Item.IsItemEnabled` | 17 (17/0/0) | self_play/active_items.lua:88<br>self_play/awareness.lua:45<br>self_play/base_defense.lua:45 | ``Item.IsItemEnabled(item):` **`boolean`**` (item.md:230) | EARLY+LATE |
| `Item.GetCost` | 12 (12/0/0) | self_play/inventory_cleanup.lua:21<br>self_play/inventory_cleanup.lua:24<br>self_play/inventory_cleanup.lua:43 | ``Item.GetCost(item):` **`integer`**` (item.md:264) | EARLY+LATE |
| `Item.GetPlayerOwnerID` | 3 (3/0/0) | self_play/inventory_cleanup.lua:63<br>self_play/inventory_cleanup.lua:77<br>self_play/shop.lua:28 | ``Item.GetPlayerOwnerID(item):` **`integer`**` (item.md:254) | EARLY+LATE |
| `Item.GetSecondaryCharges` | 3 (3/0/0) | self_play/objectives.lua:134<br>self_play/vision.lua:22<br>self_play/vision.lua:30 | ``Item.GetSecondaryCharges(item):` **`integer`**` (item.md:159) | LATE/OTHER |
| `Item.IsSellable` | 3 (3/0/0) | self_play/inventory_cleanup.lua:24<br>self_play/inventory_cleanup.lua:76<br>self_play/shop.lua:720 | ``Item.IsSellable(item):` **`boolean`**` (item.md:79) | EARLY+LATE |
| `Item.GetStockCount` | 2 (2/0/0) | self_play/shop.lua:18<br>self_play/shop.lua:485 | `\`Item.GetStockCount(item\_id, \[team]):\` \*\*\`integer\`\*\*` (item.md:274) | EARLY |
| `Item.IsCombineLocked` | 1 (1/0/0) | self_play/shop.lua:356 | ``Item.IsCombineLocked(item):` **`boolean`**` (item.md:169) | EARLY |
| `Item.IsStackable` | 1 (1/0/0) | self_play/shop.lua:557 | ``Item.IsStackable(item):` **`boolean`**` (item.md:29) | EARLY |
| `Item.RequiresCharges` | 1 (1/0/0) | self_play/combat.lua:86 | ``Item.RequiresCharges(item):` **`boolean`**` (item.md:89) | LATE/OTHER |

### Player — player.md — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Player.PrepareUnitOrders` | 26 (26/0/0) | self_play/combat.lua:127<br>self_play/combat.lua:313<br>self_play/combat.lua:338 | ``Player.PrepareUnitOrders(player, type, target, pos, ability, issuer, issuer_npc, [queue], [show_effects], [callback], [execute_fast], [identifier], [force_minimap]):` **`nil`**` (player.md:7) | EARLY+LATE |
| `Player.GetTeamPlayer` | 8 (4/3/1) | Self Play.lua:1985<br>self_play/hud.lua:216 [pcall]<br>self_play/recovery.lua:468 | ``Player.GetTeamPlayer(player, [output]):` **`{reliable_gold:integer, unreliable_gold:integer, starting_position:integer, totalearned_gold:integer, totalearned_xp:integer, shared_gold:integer…` (player.md:144) | EARLY+LATE |
| `Player.GetTotalGold` | 8 (8/0/0) | self_play/recovery.lua:69<br>self_play/recovery.lua:494<br>self_play/shop.lua:475 | ``Player.GetTotalGold(player):` **`integer`**` (player.md:227) | EARLY+LATE |
| `Player.HoldPosition` | 5 (5/0/0) | Self Play.lua:681<br>self_play/heroes/common.lua:134<br>self_play/inventory_cleanup.lua:183 | ``Player.HoldPosition(player, issuer_npc, [queue], [push], [execute_fast], [identifier]):` **`nil`**` (player.md:29) | EARLY+LATE |
| `Player.AttackTarget` | 4 (4/0/0) | Self Play.lua:856<br>Self Play.lua:877<br>self_play/heroes/common.lua:179 | ``Player.AttackTarget(player, issuer_npc, target, [queue], [push], [execute_fast], [identifier], [force_minimap]):` **`nil`**` (player.md:44) | EARLY+LATE |
| `Player.GetTeamData` | 4 (3/1/0) | self_play/draft.lua:118<br>self_play/draft.lua:133<br>self_play/draft.lua:178 | ``Player.GetTeamData(player):` **`{selected_hero_id:integer, kills:integer, assists:integer, deaths:integer, streak:integer, respawnTime:integer, selected_hero_variant:integer, lane_selection…` (player.md:123) | LATE/OTHER |
| `Player.GetAssignedHero` | 2 (1/0/1) | Self Play.lua:272 [value]<br>Self Play.lua:272 | ``Player.GetAssignedHero(player):` [**`CHero`**](/api-v2.0/game-components/core/hero.md) | **`nil`**` (player.md:237) | LATE/OTHER |
| `Player.GetPlayerID` | 1 (1/0/0) | Self Play.lua:334 | ``Player.GetPlayerID(player):` **`integer`**` (player.md:61) | LATE/OTHER |
| `Player.GetPlayerNeutralInfo` | 1 (1/0/0) | self_play/neutral_items.lua:116 | ``Player.GetPlayerNeutralInfo(player):` **`nil`** | **`{acquired_madstone:integer, current_madstone:integer, trinket_choices:integer[], enhancement_choices:integer[], selected_trinkets:intege…` (player.md:155) | LATE/OTHER |
| `Player.GetQueryUnit` | 1 (1/0/0) | self_play/talents.lua:4 | ``Player.GetQueryUnit(player):` [**`CNPC`**](/api-v2.0/game-components/core/npc.md) | **`nil`**` (player.md:247) | LATE/OTHER |
| `Player.GetSelectedUnits` | 1 (1/0/0) | Self Play.lua:2169 | ``Player.GetSelectedUnits(player):` [**`CNPC[]`**](/api-v2.0/game-components/core/npc.md)` (player.md:175) | LATE/OTHER |

### GameRules — gamerules.md — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `GameRules.GetGameTime` | 29 (29/0/0) | Self Play.lua:338<br>Self Play.lua:1801<br>Self Play.lua:1846 | ``GameRules.GetGameTime():` **`number`**` (gamerules.md:57) | EARLY+LATE |
| `GameRules.GetGameStartTime` | 7 (5/0/2) | Self Play.lua:346<br>Self Play.lua:346<br>Self Play.lua:1849 | ``GameRules.GetGameStartTime():` **`number`**` (gamerules.md:35) | EARLY+LATE |
| `GameRules.GetMatchID` | 4 (2/0/2) | self_play/shop.lua:640 [value]<br>self_play/shop.lua:640<br>self_play/win_model.lua:50 [value] | ``GameRules.GetMatchID():` **`integer`**` (gamerules.md:108) | EARLY+LATE |
| `GameRules.GetBadGlyphCD` | 1 (0/0/1) | self_play/siege.lua:369 [value] | ``GameRules.GetBadGlyphCD():` **`number`**` (gamerules.md:130) | LATE/OTHER |
| `GameRules.GetGameMode` | 1 (1/0/0) | self_play/draft.lua:251 | ``GameRules.GetGameMode():` [**`Enum.GameMode`**](https://uczone.gitbook.io/api-v2.0/game-components/game-engine/pages/VwVljl88Qnl7u9hhqRdw#enum.gamemode)` (gamerules.md:19) | LATE/OTHER |
| `GameRules.GetGameState` | 1 (1/0/0) | Self Play.lua:1833 | ``GameRules.GetGameState():` [**`Enum.GameState`**](https://uczone.gitbook.io/api-v2.0/game-components/game-engine/pages/VwVljl88Qnl7u9hhqRdw#enum.gamestate)` (gamerules.md:13) | EARLY+LATE |
| `GameRules.GetGoodGlyphCD` | 1 (0/0/1) | self_play/siege.lua:369 [value] | ``GameRules.GetGoodGlyphCD():` **`number`**` (gamerules.md:120) | LATE/OTHER |
| `GameRules.IsPaused` | 1 (1/0/0) | Self Play.lua:1832 | ``GameRules.IsPaused():` **`boolean`**` (gamerules.md:76) | EARLY+LATE |

### Config — config.md — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Config.WriteString` | 11 (11/0/0) | self_play/build_brain.lua:342<br>self_play/draft.lua:78<br>self_play/draft.lua:84 | ``Config.WriteString(config, key, value):` **`nil`**` (config.md:67) | EARLY+LATE |
| `Config.ReadString` | 10 (10/0/0) | self_play/build_brain.lua:337<br>self_play/draft.lua:66<br>self_play/party_queue.lua:12 | ``Config.ReadString(config, key, [def]):` **`string`**` (config.md:31) | EARLY+LATE |
| `Config.ReadInt` | 7 (7/0/0) | Self Play.lua:99<br>Self Play.lua:100<br>self_play/build_brain.lua:330 | ``Config.ReadInt(config, key, [def]):` **`integer`**` (config.md:7) | EARLY+LATE |
| `Config.WriteInt` | 6 (6/0/0) | Self Play.lua:101<br>self_play/build_brain.lua:336<br>self_play/draft_data.lua:325 | ``Config.WriteInt(config, key, value):` **`nil`**` (config.md:43) | EARLY+LATE |
| `Config.ReadFloat` | 1 (1/0/0) | self_play/localization.lua:53 | ``Config.ReadFloat(config, key, [def]):` **`number`**` (config.md:19) | LATE/OTHER |
| `Config.WriteFloat` | 1 (1/0/0) | self_play/localization.lua:62 | ``Config.WriteFloat(config, key, value):` **`nil`**` (config.md:55) | LATE/OTHER |

### World — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `World.GetGroundZ` | 31 (31/0/0) | Self Play.lua:732<br>Self Play.lua:754<br>Self Play.lua:1140 | **UNVERIFIED** | EARLY+LATE |

### Engine — engine.md — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Engine.IsInGame` | 8 (8/0/0) | Self Play.lua:1823<br>Self Play.lua:1831<br>self_play/camera.lua:5 | ``Engine.IsInGame():` **`boolean`**` (engine.md:7) | LATE/OTHER |
| `Engine.RunScript` | 5 (5/0/0) | self_play/draft.lua:275<br>self_play/session.lua:11<br>self_play/talents.lua:24 | ``Engine.RunScript(script, [contextPanel]):` **`boolean`**` (engine.md:30) | LATE/OTHER |
| `Engine.ExecuteCommand` | 4 (4/0/0) | Self Play.lua:2349<br>self_play/camera.lua:9<br>self_play/camera.lua:15 | ``Engine.ExecuteCommand(command):` **`nil`**` (engine.md:50) | LATE/OTHER |
| `Engine.IsInLobby` | 4 (4/0/0) | self_play/matchmaking.lua:105<br>self_play/matchmaking.lua:143<br>self_play/party_queue.lua:155 | ``Engine.IsInLobby():` **`boolean`**` (engine.md:227) | LATE/OTHER |
| `Engine.GetCheatDirectory` | 3 (2/1/0) | self_play/build_brain.lua:285<br>self_play/draft_data.lua:36<br>self_play/log.lua:13 [pcall] | ``Engine.GetCheatDirectory():` **`string`**` (engine.md:158) | EARLY+LATE |
| `Engine.CanAcceptMatch` | 2 (2/0/0) | self_play/matchmaking.lua:123<br>self_play/matchmaking.lua:127 | ``Engine.CanAcceptMatch():` **`boolean`**` (engine.md:146) | LATE/OTHER |
| `Engine.AcceptMatch` | 1 (1/0/0) | self_play/matchmaking.lua:128 | ``Engine.AcceptMatch(state):` **`nil`**` (engine.md:176) | LATE/OTHER |
| `Engine.GetHeroNameByID` | 1 (1/0/0) | self_play/draft.lua:180 | ``Engine.GetHeroNameByID(heroID):` **`string`** | **`nil`**` (engine.md:272) | LATE/OTHER |

### NetChannel — (no namespace doc in umbrella_api) — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `NetChannel.GetAvgLatency` | 21 (21/0/0) | Self Play.lua:1023<br>self_play/creep_block.lua:7<br>self_play/creep_block.lua:7 | **UNVERIFIED** | EARLY+LATE |
| `NetChannel.SendNetMessage` | 2 (2/0/0) | self_play/neutral_items.lua:134<br>self_play/neutral_items.lua:156 | **UNVERIFIED** | LATE/OTHER |

### Render — render.md — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Render.FilledRect` | 3 (3/0/0) | self_play/hud.lua:256<br>self_play/hud.lua:257<br>self_play/hud.lua:299 | ``Render.FilledRect(start, end_, color, [rounding], [flags]):` **`nil`**` (render.md:7) | LATE/OTHER |
| `Render.LoadFont` | 3 (3/0/0) | Self Play.lua:171<br>self_play/hud.lua:28<br>self_play/hud.lua:29 | ``Render.LoadFont(fontName, [fontFlag], [weight]):` **`integer`**` (render.md:173) | LATE/OTHER |
| `Render.ScreenSize` | 3 (3/0/0) | self_play/hud.lua:239<br>self_play/hud.lua:278<br>self_play/hud.lua:359 | ``Render.ScreenSize():` [**`Vec2`**](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)` (render.md:222) | LATE/OTHER |
| `Render.Text` | 3 (3/0/0) | Self Play.lua:2307<br>self_play/hud.lua:37<br>self_play/hud.lua:38 | ``Render.Text(font, fontSize, text, pos, color):` **`nil`**` (render.md:185) | LATE/OTHER |
| `Render.TextSize` | 3 (3/0/0) | self_play/hud.lua:35<br>self_play/hud.lua:43<br>self_play/hud.lua:45 | ``Render.TextSize(font, fontSize, text):` [**`Vec2`**](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)` (render.md:228) | LATE/OTHER |
| `Render.WorldToScreen` | 3 (3/0/0) | self_play/hud.lua:322<br>self_play/hud.lua:330<br>self_play/hud.lua:333 | ``Render.WorldToScreen(pos):` [**`Vec2`**](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md), **`boolean`**` (render.md:199) | LATE/OTHER |
| `Render.Circle` | 1 (1/0/0) | self_play/hud.lua:324 | ``Render.Circle(pos, radius, color, [thickness], [startDeg], [percentage], [rounded], [segments]):` **`nil`**` (render.md:90) | LATE/OTHER |
| `Render.FilledCircle` | 1 (1/0/0) | self_play/hud.lua:336 | ``Render.FilledCircle(pos, radius, color, [startDeg], [percentage], [segments]):` **`nil`**` (render.md:107) | LATE/OTHER |
| `Render.Line` | 1 (1/0/0) | self_play/hud.lua:335 | ``Render.Line(start, end_, color, [thickness]):` **`nil`**` (render.md:65) | LATE/OTHER |
| `Render.Rect` | 1 (1/0/0) | self_play/hud.lua:300 | ``Render.Rect(start, end_, color, [rounding], [flags], [thickness]):` **`nil`**` (render.md:21) | LATE/OTHER |

### Modifier — modifier.md — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Modifier.GetDieTime` | 9 (9/0/0) | Self Play.lua:1639<br>self_play/engagement.lua:54<br>self_play/fight_sim.lua:218 | ``Modifier.GetDieTime(modifier):` **`number`**` (modifier.md:125) | LATE/OTHER |
| `Modifier.GetStackCount` | 5 (4/0/1) | self_play/heroes/lion.lua:9 [value]<br>self_play/heroes/lion.lua:9<br>self_play/heroes/primal_beast.lua:45 | ``Modifier.GetStackCount(modifier):` **`integer`**` (modifier.md:135) | LATE/OTHER |
| `Modifier.GetName` | 4 (3/0/1) | self_play/heroes/arc_warden.lua:33<br>self_play/heroes/arc_warden.lua:142 [value]<br>self_play/heroes/arc_warden.lua:144 | ``Modifier.GetName(modifier):` **`string`**` (modifier.md:7) | LATE/OTHER |
| `Modifier.GetCaster` | 2 (2/0/0) | self_play/deward.lua:43<br>self_play/heroes/arc_warden.lua:33 | ``Modifier.GetCaster(modifier):` [**`CEntity`**](/api-v2.0/game-components/core/entity.md) | **`nil`**` (modifier.md:370) | LATE/OTHER |
| `Modifier.GetCreationTime` | 1 (1/0/0) | self_play/runes.lua:167 | ``Modifier.GetCreationTime(modifier):` **`number`**` (modifier.md:83) | EARLY |
| `Modifier.GetState` | 1 (1/0/0) | self_play/heroes/invoker.lua:95 | ``Modifier.GetState(modifier):` **`number`**, **`number`**` (modifier.md:380) | LATE/OTHER |

### GC — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `GC.GetSteamID` | 8 (8/0/0) | self_play/party_queue.lua:72<br>self_play/party_queue.lua:109<br>self_play/party_queue.lua:162 | **UNVERIFIED** | LATE/OTHER |
| `GC.SendMessage` | 5 (5/0/0) | self_play/matchmaking.lua:17<br>self_play/party_queue.lua:26<br>self_play/queue_account.lua:117 | **UNVERIFIED** | LATE/OTHER |

### Log — (no namespace doc in umbrella_api) — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Log.Write` | 11 (11/0/0) | self_play/log.lua:81<br>self_play/log.lua:87<br>self_play/log.lua:89 | **UNVERIFIED** | LATE/OTHER |

### Players — players.md — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Players.GetAll` | 5 (5/0/0) | Self Play.lua:271<br>self_play/draft.lua:131<br>self_play/draft.lua:177 | ``Players.GetAll():` [**`CPlayer[]`**](/api-v2.0/game-components/core/player.md)` (players.md:23) | EARLY+LATE |
| `Players.GetLocal` | 5 (5/0/0) | Self Play.lua:1835<br>self_play/draft.lua:116<br>self_play/draft.lua:127 | ``Players.GetLocal():` [**`CPlayer`**](/api-v2.0/game-components/core/player.md) | **`nil`**` (players.md:39) | EARLY+LATE |

### Heroes — heroes.md — Owner: api.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Heroes.GetAll` | 6 (6/0/0) | Self Play.lua:276<br>Self Play.lua:311<br>Self Play.lua:440 | ``Heroes.GetAll():` [**`CHero[]`**](/api-v2.0/game-components/core/hero.md)` (heroes.md:23) | EARLY+LATE |
| `Heroes.GetLocal` | 3 (3/0/0) | Self Play.lua:1835<br>self_play/camera.lua:5<br>self_play/matchmaking.lua:134 | ``Heroes.GetLocal():` [**`CHero`**](/api-v2.0/game-components/core/hero.md) | **`nil`**` (heroes.md:54) | EARLY+LATE |

### Tower — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Tower.GetAttackTarget` | 9 (8/0/1) | Self Play.lua:476<br>Self Play.lua:527<br>Self Play.lua:566 | **UNVERIFIED** | EARLY+LATE |

### Trees — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Trees.InRadius` | 8 (5/1/2) | self_play/field.lua:14 [value]<br>self_play/field.lua:15 [pcall]<br>self_play/heroes/hoodwink.lua:6 | **UNVERIFIED** — cross-ns lookalike heroes.md:39 NON-AUTHORITATIVE | EARLY+LATE |

### Couriers — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Couriers.GetLocal` | 7 (7/0/0) | self_play/inventory_cleanup.lua:60<br>self_play/inventory_cleanup.lua:95<br>self_play/recovery.lua:67 | **UNVERIFIED** — cross-ns lookalike heroes.md:54 NON-AUTHORITATIVE | EARLY+LATE |
| `Couriers.GetAll` | 1 (1/0/0) | self_play/shop.lua:40 | **UNVERIFIED** — cross-ns lookalike entities.md:7 NON-AUTHORITATIVE | EARLY |

### FogOfWar — (no namespace doc in umbrella_api) — Owner: api.lua + loader stub

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `FogOfWar.IsPointVisible` | 7 (6/0/1) | self_play/awareness.lua:151<br>self_play/awareness.lua:165<br>self_play/detection.lua:90 | **UNVERIFIED** | EARLY+LATE |

### Panorama — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Panorama.GetPanelByName` | 6 (6/0/0) | self_play/draft.lua:253<br>self_play/matchmaking.lua:103<br>self_play/matchmaking.lua:133 | **UNVERIFIED** | LATE/OTHER |

### NPCs — npcs.md — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `NPCs.GetAll` | 3 (3/0/0) | Self Play.lua:405<br>self_play/travel.lua:187<br>self_play/win_model.lua:156 | ``NPCs.GetAll([filter]):` [**`CNPC[]`**](/api-v2.0/game-components/core/npc.md)` (npcs.md:23) | LATE/OTHER |
| `NPCs.InRadius` | 2 (2/0/0) | self_play/objectives.lua:24<br>self_play/objectives.lua:194 | ``NPCs.InRadius(pos, radius, teamNum, teamType, [omitIllusions], [omitDormant]):` [**`CNPC[]`**](/api-v2.0/game-components/core/npc.md)` (npcs.md:61) | LATE/OTHER |

### Tree — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Tree.IsActive` | 5 (5/0/0) | self_play/consumables.lua:89<br>self_play/heroes/hoodwink.lua:6<br>self_play/heroes/hoodwink.lua:8 | **UNVERIFIED** | EARLY+LATE |

### Runes — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Runes.Contains` | 3 (3/0/0) | self_play/runes.lua:143<br>self_play/runes.lua:284<br>self_play/runes.lua:287 | **UNVERIFIED** — cross-ns lookalike entities.md:13 NON-AUTHORITATIVE | EARLY |
| `Runes.GetAll` | 2 (2/0/0) | self_play/runes.lua:130<br>self_play/runes.lua:293 | **UNVERIFIED** — cross-ns lookalike entities.md:7 NON-AUTHORITATIVE | EARLY |

### Bottle — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Bottle.GetRuneType` | 5 (5/0/0) | self_play/combat.lua:83<br>self_play/consumables.lua:126<br>self_play/runes.lua:62 | **UNVERIFIED** | EARLY+LATE |

### HTTP — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `HTTP.Request` | 4 (4/0/0) | self_play/build_brain.lua:320<br>self_play/draft_data.lua:95<br>self_play/party_queue.lua:49 | **UNVERIFIED** | EARLY+LATE |

### Rune — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Rune.GetRuneType` | 3 (3/0/0) | self_play/runes.lua:132<br>self_play/runes.lua:295<br>self_play/runes.lua:319 | **UNVERIFIED** | EARLY |

### TempTrees — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `TempTrees.InRadius` | 2 (1/0/1) | self_play/ward_spots.lua:50 [value]<br>self_play/ward_spots.lua:51 | **UNVERIFIED** — cross-ns lookalike heroes.md:39 NON-AUTHORITATIVE | LATE/OTHER |
| `TempTrees.GetAll` | 1 (1/0/0) | self_play/heroes/hoodwink.lua:7 | **UNVERIFIED** — cross-ns lookalike entities.md:7 NON-AUTHORITATIVE | LATE/OTHER |

### GlobalVars — (no namespace doc in umbrella_api) — Owner: api.lua + loader stub

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `GlobalVars.GetAbsFrameTime` | 2 (1/0/1) | self_play/party_queue.lua:225 [value]<br>self_play/party_queue.lua:225 | **UNVERIFIED** | LATE/OTHER |

### Menu — menu.md — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Menu.Create` | 1 (1/0/0) | Self Play.lua:88 | ``Menu.Create(firstTabName, sectionName, secondTabName, thirdTabName, groupTabName):` [**`CMenuGroup`**](/api-v2.0/cheats-types-and-callbacks/classes/menu/cmenugroup.md)` (menu.md:24) | LATE/OTHER |
| `Menu.Find` | 1 (1/0/0) | self_play/localization.lua:107 | ``Menu.Find(firstTabName, sectionName, secondTabName, thirdTabName, groupTabName, widgetName, attachmentName, widgetInGearName):` [**`CMenuSwitch`**](/api-v2.0/cheats-types-and-callbacks/clas…` (menu.md:7) | LATE/OTHER |

### Humanizer — humanizer.md — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Humanizer.GetOrderQueue` | 1 (1/0/0) | self_play/creep_block.lua:130 | ``Humanizer.GetOrderQueue():` **`{player: CPlayer, orderType: Enum.UnitOrder, targetIndex: integer, position: Vector, abilityIndex: integer, orderIssuer: Enum.PlayerOrderIssuer, unit: CNPC`**…` (humanizer.md:35) | EARLY |

### PhysicalItems — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `PhysicalItems.GetAll` | 1 (1/0/0) | self_play/roshan.lua:329 | **UNVERIFIED** — cross-ns lookalike entities.md:7 NON-AUTHORITATIVE | LATE/OTHER |

### PhysicalItem — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `PhysicalItem.GetItem` | 1 (1/0/0) | self_play/roshan.lua:331 | **UNVERIFIED** — cross-ns lookalike npc.md:17 NON-AUTHORITATIVE | LATE/OTHER |

### Entities — entities.md — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Entities.GetAll` | 1 (1/0/0) | self_play/runes.lua:116 | ``Entities.GetAll():` [**`CEntity[]`**](/api-v2.0/game-components/core/entity.md)` (entities.md:7) | EARLY |

### Input — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Input.IsInputCaptured` | 1 (1/0/0) | Self Play.lua:1860 | **UNVERIFIED** | LATE/OTHER |

### PowerTreads — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `PowerTreads.GetStats` | 1 (1/0/0) | self_play/consumables.lua:229 | **UNVERIFIED** | EARLY |

### Abilities — (no namespace doc in umbrella_api) — Owner: loader.lua

| Function | Calls (d/p/v) | Call sites (up to 3) | Semantics (doc:line) | Tag |
|---|---|---|---|---|
| `Abilities.AttemptToUpgrade` | 1 (1/0/0) | self_play/talents.lua:35 | **UNVERIFIED** | LATE/OTHER |

## 7. Traceability & regeneration

- Every row derives from the scan in §1; call sites are `path:line` relative to the scripts root (`Self Play.lua` or `self_play/...`), with `[pcall]`/`[value]` markers where the reference is not a direct call.
- Doc citations are heading lines in `D:\hake\lotus\umbrella_api\`; the quoted semantics string is the signature line below that heading. Cross-ns matches are explicitly marked and must not be used as contracts.
- Owner column reflects the Lead adjudication (§0.1): `api.lua` = value/contract ownership; `loader.lua` = Umbrella shim/stub owned by loader-events — the parity baseline's MISSING/FogOfWar findings are loader-context artifacts, not api defects.
- The inventory is static (reference scripts, 16.11 as installed). Early-path module list and core-list are written in §1/§3.2 so a reviewer can challenge/refine them; adding a module re-tags rows mechanically (regeneration script logic described here).


