# Umbrella globals
Reference for the Lua globals the Umbrella runtime provides beyond the [official API](https://uczone.gitbook.io/api-v2.0): Umbrella's internal libraries, trackers and helpers. Everything covered by the official API is left out.

---
## Contents

1. [Before you start](#before-you-start)
2. [LIB_DAMAGE_PREDICTION](#lib_damage_prediction)
3. [Meta](#meta)
4. [Roshan](#roshan)
5. [JungleCampsManager](#junglecampsmanager)
6. [LaneGroupsManager](#lanegroupsmanager)
7. [LaneCreepsManager](#lanecreepsmanager)
8. [JungleCreepsManager](#junglecreepsmanager)
9. [LinearProjectilesManager](#linearprojectilesmanager)
10. [TargetProjectiles](#targetprojectiles)
11. [KV_LIB](#kv_lib)
12. [ConvarManager](#convarmanager)
13. [ZHelpers](#zhelpers)
14. [LIB_HEROES_DATA](#lib_heroes_data)
15. [LIB_RENDER](#lib_render)
16. [CallbacksManager](#callbacksmanager)
17. [XHelpers](#xhelpers)
18. [Icons](#icons)
19. [UnsafeFeaturesEnabled](#unsafefeaturesenabled)
20. [AbilitiesSystem](#abilitiessystem)
21. [g_logger](#g_logger)
22. [Statistics](#statistics)
23. [Notification](#notification)
24. [COURIERS_MAPHACK_DATA](#couriers_maphack_data)
25. [KeyValues](#keyvalues)
26. [RenderTarget and rt_handle_t](#rendertarget-and-rt_handle_t)
27. [Utils](#utils)
28. [KV](#kv)
29. [DODGER_SLEEPS](#dodger_sleeps)
30. [UserInfo](#userinfo)
31. [db](#db)
32. [ProfileChanger](#profilechanger)
33. [Load](#load)
34. [pr, log and profile](#pr-log-and-profile)
35. [_VERSION](#_version)
36. [Undocumented engine functions](#undocumented-engine-functions)
37. [Undocumented enums](#undocumented-enums)

---

## Before you start

### Reading the signatures

```lua
Roshan:get_hp() -> number
ZHelpers.get_status_resistance(npc: CNPC) -> number
```

- A signature written with `:` is a method and has to be called with `:`. Calling it with a dot fails with `attempt to index a nil value (local 'self')`. A signature written with `.` is a plain function.
- `name?` marks an optional argument.
- `CNPC`, `CEntity`, `CAbility`, `Vector`, `Vec2`, `Angle` and `Color` are the official docs' types. Anything else is a plain Lua type.
- Parameter names are the libraries' own. Where a function's internal name for a parameter isn't known, the parameter is described instead.
- Where only part of a signature is known, it's written that way: `ZHelpers.position_clamp(_, my_pos, ...)` means the second argument is `my_pos`.
- Functions starting with `_` or `__`, `init`, and functions that add, remove or update a library's internal records are not listed. They exist for the library itself, and calling them corrupts state that Umbrella's own features read.

### When you can call what

Most of these libraries are filled in by Umbrella's own callbacks. At the top level of your script (load time), many of them are still empty:

| Global | At load time | Inside `OnUpdate` / `OnDraw` |
|---|---|---|
| `Meta`, `KV_LIB`, `ConvarManager`, `Utils`, `Icons`, `XHelpers`, `TargetProjectiles` | works | works |
| `LIB_HEROES_DATA.get()` and the helpers | works | works |
| `Roshan` | returns defaults: position `(0, 0, 0)`, health `6000` | real values |
| `JungleCampsManager`, `JungleCreepsManager` | empty; spawn numbers are `-1` | filled in |
| `LaneGroupsManager`, `LaneCreepsManager` | empty; spawn number is `0` | filled in |
| `LIB_DAMAGE_PREDICTION` | every table empty, including `my_units_info` | filled in |
| `LIB_RENDER` drawing functions | fail | `OnDraw` only |
| Anything that touches `Particle.*`, e.g. `XVectorTargetManager` | fails with `Don't call Particle.* API outside of callbacks` | works |

Set things up at load time if you like, but read game state from callbacks.

---

## LIB_DAMAGE_PREDICTION

Predicts the damage that is about to hit a unit: auto attacks in their wind-up, projectiles in the air, targeted spell projectiles, spells being cast at the unit, damage-over-time modifiers, and around forty hero-specific effects (Sun Strike, Call Down, March of the Machines, Echo Slam and so on). It also keeps live tables of who is attacking whom. The library comes from `6_damage_prediction.lua` (revision 502).

`LIB_DAMAGE_PREDICTION` is an instance of a class: the methods and data tables sit on its metatable's `__index`, so `pairs(LIB_DAMAGE_PREDICTION)` shows almost nothing. Index fields directly, or iterate `getmetatable(LIB_DAMAGE_PREDICTION).__index`.

**Availability:** callbacks only. At load time every table is empty and `my_units_info[hero]` is `nil`.

### Getting the incoming damage on a unit

```lua
local dp = LIB_DAMAGE_PREDICTION

local function incoming(target)
  dp:begin_outgoing(target, Entity.GetHealth(target), Entity.GetMaxHealth(target))
  dp:collect_attacks(target, true)
  dp:collect_predictions(target)
  dp:collect_projectiles(target)
  dp:collect_ability_projectiles(target)
  dp:collect_ability_animations(target)
  dp:collect_modifiers(target)
  return dp.targets[target]
end

function script.OnUpdate()
  local creep = --[[ some lane creep ]] nil
  if not creep then return end
  local prediction = incoming(creep)
  local now = GameRules.GetGameTime()
  local hpIn = prediction.hp
  for _, hit in ipairs(prediction.attacks) do
    if hit.time_to_damage and hit.time_to_damage <= now + 0.5 then
      hpIn = hpIn - hit.damage
    end
  end
  -- hpIn is the creep's health half a second from now
end
```

A full pass isn't cheap. Run it at most once per frame per unit and reuse the result.

#### `begin_outgoing`

```lua
LIB_DAMAGE_PREDICTION:begin_outgoing(target: CNPC, hp: number, max_hp: number) -> Prediction
```

Starts a fresh prediction for `target` and stores it in `LIB_DAMAGE_PREDICTION.targets[target]`. The `hp` you pass is the starting health. You can pass your own corrected value instead of the live health.

| Parameter | Type | Meaning |
|---|---|---|
| `target` | `CNPC` | the unit receiving the damage |
| `hp` | `number` | starting health |
| `max_hp` | `number` | maximum health |

Returns the new `Prediction`, for example `{ hp = 332, max_hp = 550, attacks = {}, modifiers = {}, outgoing_policy = "outgoing_exact", outgoing_hp_unknown = false, begin_count = 1, frame_seq = 0 }`.

#### `begin`

```lua
LIB_DAMAGE_PREDICTION:begin(target: CNPC) -> Prediction
```

Same as `begin_outgoing`, but without health values and without `outgoing_policy`. Use `begin_outgoing` unless you have a reason not to.

#### Collectors

```lua
LIB_DAMAGE_PREDICTION:collect_attacks(target: CNPC, true)
LIB_DAMAGE_PREDICTION:collect_predictions(target: CNPC)
LIB_DAMAGE_PREDICTION:collect_projectiles(target: CNPC)
LIB_DAMAGE_PREDICTION:collect_ability_projectiles(target: CNPC)
LIB_DAMAGE_PREDICTION:collect_ability_animations(target: CNPC)
LIB_DAMAGE_PREDICTION:collect_modifiers(target: CNPC)
```

Each collector appends entries to `targets[target].attacks` and returns nothing. Call `begin_outgoing` first: the collectors add to the prediction it creates. Pass `true` as the second argument of `collect_attacks`, as Umbrella's own scripts do.

| Collector | What it adds |
|---|---|
| `collect_attacks` | auto attacks currently winding up on the target, from heroes, creeps and towers |
| `collect_predictions` | attacks expected soon from units already locked onto the target |
| `collect_projectiles` | attack projectiles in flight |
| `collect_ability_projectiles` | targeted spell projectiles; the 93 known ones are listed in `target_proj_table` |
| `collect_ability_animations` | spells being cast at the target |
| `collect_modifiers` | damage over time and delayed damage from modifiers on the target |
| `collect_aura_event_dots` | aura ticks such as Freezing Field or Bedlam |
| `collect_attack_dot_persist` | lingering on-attack damage over time |
| `collect_reflected_damage` | damage returned by Blade Mail and similar |
| `collect_self_attack_cost` | health a unit spends on its own attacks |

Hero- and item-specific collectors, all taking `(target)`:

| Collector | Collector |
|---|---|
| `collect_abyssal_underlord_pit_of_malice` | `collect_kez_grapple_strike` |
| `collect_arc_warden_spark_wraith` | `collect_largo_frogstomp` |
| `collect_beastmaster_hawk_dive` | `collect_medusa_gorgon_grasp` |
| `collect_bloodseeker_blood_rite` | `collect_monkey_king_primal_spring` |
| `collect_centaur_hoof_stomp_windup` | `collect_razor_plasma_field` |
| `collect_dawnbreaker_fire_wreath` | `collect_sandking_sand_storm` |
| `collect_dawnbreaker_solar_guardian_land` | `collect_slark_dark_pact_onset` |
| `collect_dawnbreaker_solar_guardian_pulses` | `collect_snapfire_firesnap_cookie` |
| `collect_dawnbreaker_solar_guardian_after_land` | `collect_snapfire_mortimer_kisses` |
| `collect_disruptor_static_storm` | `collect_snapfire_spit_creep` |
| `collect_earthshaker_echo_slam` | `collect_storm_static_remnant` |
| `collect_faceless_void_time_walk_land` | `collect_tinker_deploy_turrets` |
| `collect_gyrocopter_call_down` | `collect_tinker_march` |
| `collect_gyrocopter_homing_missile` | `collect_tinker_turret_missiles` |
| `collect_invoker_sun_strike` | `collect_visage_stone_form` |
| `collect_item_fallen_sky_land` | `collect_void_spirit_aether_remnant` |
| `collect_item_meteor_hammer` | `collect_void_spirit_dissimilate` |
| `collect_kez_echo_slash_echo` | `collect_winter_wyvern_splinter_blast` |
| `collect_kez_falcon_echo` | `collect_wisp_spirits` |

#### `predict`

```lua
LIB_DAMAGE_PREDICTION:predict(target: CNPC, opts?: table) -> Prediction
```

Runs the library's own complete pass. It needs a prior `begin_outgoing` for the same target; without one it fails with `attempt to perform arithmetic on a nil value (local 'final_hp')`. The fields of `opts` are unknown, and passing `{}` behaves the same as passing nothing.

#### Other prediction functions

```lua
LIB_DAMAGE_PREDICTION:filter_dead_attacks(target: CNPC)
LIB_DAMAGE_PREDICTION:loss_spread(target: CNPC) -> number
LIB_DAMAGE_PREDICTION:target_have_bm(target: CNPC) -> boolean
```

- `filter_dead_attacks` removes entries whose attacker has died.
- `loss_spread` returns a small integer, the spread of the predicted health loss.
- `target_have_bm` is `true` when the target reflects damage (Blade Mail and the like).

`hp_loss` also exists, but it takes an internal damage record, not something you can build from a script.

#### `Prediction`

| Field | Type | Meaning |
|---|---|---|
| `hp`, `max_hp` | `number` | the values passed to `begin_outgoing` |
| `attacks` | `Attack[]` | everything the collectors found |
| `modifiers` | `userdata[]` | the target's modifiers that were considered |
| `outgoing_policy` | `string` | `"outgoing_exact"` when exact outgoing damage is supported |
| `outgoing_hp_unknown` | `boolean` | |
| `need_tower_calc` | `boolean` | |
| `begin_count` | `number` | how many times this target was started this frame |
| `frame_seq` | `number` | the library's frame counter; `0` before its first update |

#### `Attack`

| Field | Type | Meaning |
|---|---|---|
| `attacker` | `CNPC` | the unit dealing the damage |
| `damage` | `number` | expected damage after armor and modifiers |
| `max_damage` | `number` | upper bound, `damage + delta_damage` |
| `delta_damage` | `number` | the attacker's damage spread |
| `time_to_damage` | `number` | game time the damage lands; compare with `GameRules.GetGameTime()` |
| `anim_time` | `number` | game time the wind-up ends |
| `type` | `integer` | one of `attack_types` below |
| `is_tower` | `boolean` | a tower shot |
| `is_risk` | `boolean` | the hit might still be cancelled |

`LIB_DAMAGE_PREDICTION.attack_types`: `predict` 1, `predictproj` 2, `anim` 3, `animproj` 4, `proj` 5, `predict_move` 6, `modifier` 7, `multi_attack` 8, `external` 9, `ability_proj` 10, `on_attack_dot` 11, `reflect` 12, `ability_anim` 13, `self_attack` 14. `attack_type_to_name` maps the numbers back to names.

### Who is attacking whom

The library keeps these tables current on its own. They're keyed by the unit handle, not the entity index.

| Table | Contents |
|---|---|
| `unit_attack[unit]` | the attack `unit` is making right now: `{ target, time_to_damage, start_anim_time, castpoint, refresh_time, is_tower, consistent_attack, anim_rec }` |
| `unit_animations[unit]` | the current attack or cast animation: `{ name, start_time, final_time, castpoint, is_hero, is_ranged, is_tower }` |
| `unit_ability_casts[unit]` | spell cast animations in progress |
| `who_attack_unit[unit]` | array of units attacking `unit` |
| `attacked_by_tower[unit]` | set while a tower is shooting `unit` |
| `my_units` | array of units the local player controls |
| `my_units_info[unit]` | `{ ref, pos, damage, attack_range, attack_point, between_attack_time, movespeed, is_ranged, compensation_pos, compensation_forward }` |
| `observed_ability_damage[victim][source][ability]` | `{ dmg, last_cast_at, last_time }`, damage measured from real hits after resistances |
| `targets[unit]` | the last `Prediction` built for `unit` |

`unit_animations` names are animation names such as `"attack2"` or `"creep_bad_siege_attack"`.

```lua
function script.OnUpdate()
  local dp = LIB_DAMAGE_PREDICTION
  local me = Heroes.GetLocal()

  for attacker, swing in pairs(dp.unit_attack) do
    if swing.target == me then
      local landsIn = swing.time_to_damage - GameRules.GetGameTime()
    end
  end

  if dp.attacked_by_tower[me] then
    -- a tower is shooting us
  end
end
```

### Damage and timing math

```lua
LIB_DAMAGE_PREDICTION:calculate_damage(attacker: CNPC, target: CNPC, base_damage?: number) -> number
LIB_DAMAGE_PREDICTION:mitigate_damage(attacker: CNPC, target: CNPC, damage: number) -> number
LIB_DAMAGE_PREDICTION:get_bonus_damage(attacker: CNPC, target: CNPC, attacker_damage: number) -> number
LIB_DAMAGE_PREDICTION:calculate_range_attack_time(attacker: CNPC, target: CNPC) -> number
LIB_DAMAGE_PREDICTION:rotate_time_to_attack(unit: CNPC, target_pos: Vector) -> number, number
LIB_DAMAGE_PREDICTION:time_to_deal_damage(attacker_info: table, target: CNPC) -> number
LIB_DAMAGE_PREDICTION:calculate_need_go(attacker_info: table, target: CNPC) -> boolean, number, number
LIB_DAMAGE_PREDICTION:calculate_unit_weight(info: table) -> number
LIB_DAMAGE_PREDICTION:committed_attack_damage(attacker: CNPC, target: CNPC) -> number?
```

| Function | Returns |
|---|---|
| `calculate_damage` | one attack's damage on `target` after attack type, armor type and armor. Without `base_damage` it uses the attacker's own damage. Arc Warden against a melee creep: `46.4` |
| `mitigate_damage` | `damage` after the target's reductions; `100` became `72.6` against the same creep |
| `get_bonus_damage` | extra or missing damage compared with `attacker_damage` |
| `calculate_range_attack_time` | wind-up plus projectile flight time in seconds. It doesn't account for distance to walk, so a far target gives a large number (`9.8` at fountain range) |
| `rotate_time_to_attack` | turn time in seconds, then the angle to turn in degrees |
| `time_to_deal_damage` | when the attacker's damage would land; needs the attacker's `my_units_info` record |
| `calculate_need_go` | whether the attacker has to move first, a number, then the attack range; also needs the `my_units_info` record |
| `calculate_unit_weight` | an internal priority weight for a `my_units_info` record |
| `committed_attack_damage` | damage of an attack that is already committed, or `nil` |

`time_to_deal_damage`, `calculate_need_go` and `calculate_unit_weight` take `LIB_DAMAGE_PREDICTION.my_units_info[unit]`, not the unit, and that record only exists for units you control, once the library has updated.

```lua
function script.OnUpdate()
  local dp = LIB_DAMAGE_PREDICTION
  local me, creep = Heroes.GetLocal(), --[[ target ]] nil
  if not creep then return end
  local perHit = dp:calculate_damage(me, creep)
  local info = dp.my_units_info[me]
  if info then
    local mustWalk, _, range = dp:calculate_need_go(info, creep)
  end
end
```

```lua
LIB_DAMAGE_PREDICTION:aa_committed(unit: CNPC) -> string, any
LIB_DAMAGE_PREDICTION:imp_committed(unit: CNPC) -> string, any
LIB_DAMAGE_PREDICTION:supports_outgoing_exact(unit: CNPC) -> boolean
LIB_DAMAGE_PREDICTION:supports_exact_ability(...) -> boolean
```

`aa_committed` reports whether an auto attack is already locked in, and `imp_committed` does the same for an instant-attack modifier. The first return value is a status string: `"absent"` when nothing is committed, `"unknown"` when there's no data. `supports_outgoing_exact` tells you whether exact outgoing damage can be computed for the unit.

The remaining timing functions (`calculate_attack_point`, `calculate_attack_speed`, `get_proj_speed`, `find_rotation_angle`, `find_target`, `units_get_info`) work on internal records and return placeholders (`0`, `20`, `nil`) when given a unit. For a real unit, use the official `NPC.GetAttackAnimPoint`, `NPC.GetAttackProjectileSpeed`, `NPC.GetTimeToFacePosition` and `NPC.GetLastAttackTime`.

### Data tables

| Field | Contents |
|---|---|
| `target_proj_table[hash]` | 93 targeted projectiles: `{ ability, damage_kv \| custom_damage, damage_type }` |
| `bonus_damage_modifiers` | 55 modifiers that change attack damage |
| `target_bonus_damage_modifiers` | 6 modifiers on the target that change incoming attack damage |
| `modifier_custom_damage` | damage rules for 57 modifiers |
| `modifier_custom_die_time` | expiry rules for 14 modifiers |
| `modifier_custom_logic` | 6 special-cased modifiers |
| `reflect_handlers` | Blade Mail, Centaur Return, Spectre Dispersion, Chipped Vest, the miniboss reflect |
| `aura_event_dots` | Freezing Field, Bedlam, Rocket Barrage, Omnislash, Lunar Orbit, Unleash, Gyroshell, Nimbus |
| `towers_converter[name]` | tower unit names (`npc_dota_goodguys_tower1_mid`, ...) mapped to a generic tower class |
| `debug` | 35 boolean switches (`dp_panel`, `visualize_attackers`, `damage_debug`, `proj_time_trace`, ...), all off |

Effect trackers: `homing_missiles`, `hawk_dives`, `echo_slam_scenes`, `sun_strike_thinkers`, `static_storm_thinkers`, `blood_rite_thinkers`, `pit_of_malice_thinkers`, `sand_storm_casters`, `call_down_strikes`, `turret_missiles`, `march_machines`, `gorgon_grasp_zones`, `frogstomp_zones`, `death_anchor_casts`, `pending_ability_projectiles`.

---

## Meta

Hero statistics by rank bracket: win rate, pick rate, per-role data, matchups and synergies. The data is built into the client, and lookups return immediately without an HTTP request.

**Availability:** load time and callbacks. The data loads in the background, so check `IsReady()` first.

```lua
Meta.IsReady() -> boolean
Meta.IsFailed() -> boolean
Meta.GetHeroInfo(hero_id: integer, bracket: string) -> { win_rate: number, pick_rate: number }
Meta.GetRolesData(role_id: integer, bracket: string) -> { [hero_id]: { win_rate: number, pick_rate: number } }
Meta.GetVsHero(hero_id: integer, enemy_id: integer, bracket: string) -> number
Meta.GetWithHero(hero_id: integer, ally_id: integer, bracket: string) -> number
```

| Parameter | Values |
|---|---|
| `hero_id`, `enemy_id`, `ally_id` | standard Dota hero IDs (`Engine.GetHeroIDByName("npc_dota_hero_arc_warden")` is `113`) |
| `bracket` | `"all"`, `"herald"`, `"guardian"`, `"crusader"`, `"archon"`, `"legend"`, `"ancient"`, `"divine"`, `"immortal"`; anything else raises `failed to find specified bracket` |
| `role_id` | position 1 to 5; anything else raises `role_id must be in range [1, 5]` |

- `IsReady()` is `true` once the data has loaded. `IsFailed()` is `true` if loading failed; stop querying in that case.
- `GetHeroInfo` gives win and pick rate in percent. Arc Warden, all brackets: `{ win_rate = 50.0, pick_rate = 5.1 }`; Immortal: `{ win_rate = 52.3, pick_rate = 4.4 }`.
- `GetRolesData` gives every hero's numbers in that role (127 entries), keyed by hero ID.
- `GetVsHero` is how many percentage points better or worse `hero_id` does against `enemy_id`. Arc Warden against Anti-Mage: `-1.06`.
- `GetWithHero` is the synergy with an ally, in percentage points. Arc Warden with Anti-Mage: `+0.57`.

```lua
local function draftScore(heroId, enemyIds, allyIds, bracket)
  if not Meta.IsReady() then return nil end
  local score = Meta.GetHeroInfo(heroId, bracket).win_rate
  for _, id in ipairs(enemyIds) do score = score + Meta.GetVsHero(heroId, id, bracket) end
  for _, id in ipairs(allyIds) do score = score + Meta.GetWithHero(heroId, id, bracket) end
  return score
end

local function bestCarries(bracket, count)
  local list = {}
  for heroId, stats in pairs(Meta.GetRolesData(1, bracket)) do
    if stats.pick_rate > 0.5 then list[#list + 1] = { id = heroId, win = stats.win_rate } end
  end
  table.sort(list, function(a, b) return a.win > b.win end)
  return { table.unpack(list, 1, count) }
end
```

---

## Roshan

Roshan tracker. It keeps last-known values while Roshan is out of vision and predicts his position while he walks between pits.

**Availability:** callbacks. At load time it returns placeholders: position `(0, 0, 0)` and health `6000`.

| Method | Returns |
|---|---|
| `Roshan:is_alive() -> boolean` | whether he's alive |
| `Roshan:is_visible() -> boolean` | whether he's in vision |
| `Roshan:is_moving() -> boolean` | whether he's walking between pits |
| `Roshan:is_under_attack() -> boolean` | whether he's taking damage |
| `Roshan:get_entity() -> CNPC?` | his unit, or `nil` while out of vision |
| `Roshan:get_hp() -> number` | last known health |
| `Roshan:get_position() -> Vector` | current or predicted position |
| `Roshan:get_current_location() -> integer` | current pit ID; `-1` until he has been seen |
| `Roshan:get_time_till_next_move() -> number` | seconds until he walks to the other pit |
| `Roshan:get_die_time() -> number` | game time of the last kill, or `-1` |
| `Roshan:get_state() -> integer` | internal state ID |
| `Roshan:get_angle() -> number` | facing yaw in degrees |
| `Roshan:get_turn_rate() -> number` | turn rate |
| `Roshan:get_roshan_dps() -> number` | damage per second he's taking right now |

| Field | Meaning |
|---|---|
| `TOP_POSITION`, `BOT_POSITION`, `MID_POSITION` | the pits and the walking route |
| `predicted_position`, `cached_position`, `cached_angle` | last computed values |
| `damage_log` | recent hits on him, dropped after `damage_log_time` (4 s) |
| `initial_move_time`, `interval_after_initial` | the pit schedule: first move at 900 s, then every 300 s |
| `base_movespeed` | 270 |
| `throw_*` | rock-throw constants |
| `unsafe_features_enabled` | same as `UnsafeFeaturesEnabled()` |

For his live health, the official `Entity.GetRoshanHealth()` works while unsafe features are on. `Entity.GetRoshanEntityIndex()` (undocumented, see below) gives his entity index even while he's out of vision.

```lua
function script.OnUpdate()
  if not Roshan:is_alive() then
    local deadFor = GameRules.GetGameTime() - Roshan:get_die_time()
    return
  end
  if not Roshan:is_visible() and Roshan:get_time_till_next_move() < 30 then
    local pit = Roshan:get_position()
  end
  if Roshan:is_under_attack() then
    local dps = Roshan:get_roshan_dps()
    local secondsToKill = dps > 0 and Roshan:get_hp() / dps or math.huge
  end
end
```

---

## JungleCampsManager

Tracks all neutral camps: spawn boxes, creeps, stack counts, gold and whether a camp is farmed.

**Availability:** callbacks. At load time `camps` is empty and both spawn numbers are `-1`.

```lua
JungleCampsManager:get_by_index(index: integer) -> Camp?
JungleCampsManager:get_camp_by_creep(neutral: CNPC) -> Camp?
JungleCampsManager.get_current_spawn_number() -> number
JungleCampsManager:get_previous_spawn_number() -> number
JungleCampsManager.get_possible_neutral_groups(camp_neutrals: table) -> table
JungleCampsManager.get_guaranteed_missing_neutrals(camp_neutrals: table) -> string[]
JungleCampsManager.get_neutral_groups(definitions: table) -> table
JungleCampsManager.get_neutral_group_neutrals(group) -> table
JungleCampsManager.get_neutral_group_main_icon(group) -> string
```

- `get_by_index` looks up a camp by its `index_`.
- `get_camp_by_creep` returns the camp a neutral creep belongs to.
- `get_current_spawn_number` and `get_previous_spawn_number` count neutral spawns (one a minute). Note the mixed call styles.
- The group helpers work on lists of neutral unit names and group definitions, such as a camp's `predicted_names_by_state.alive`. They're what the manager uses to work out which creeps a camp holds. Their exact input format wasn't confirmed.

Data: `camps` (array of `Camp`), `creep_to_camp` (neutral `CNPC` to `Camp`), `non_attached_creeps`, `already_deleted_creeps`.

### `Camp`

| Field | Type | Meaning |
|---|---|---|
| `index_` | `integer` | camp ID |
| `ref` | `Camp` | the engine camp object, for the official `Camp.*` functions |
| `team_` | `integer` | 2 Radiant side, 3 Dire side |
| `camp_type` | `integer` | 0 small, 1 medium, 2 large, 3 ancient |
| `position_` | `Vector` | camp centre (`position_string_` is the same as text) |
| `box` | `{ min: Vector, max: Vector }` | spawn box; any unit inside blocks the spawn |
| `is_farmed_` | `boolean` | cleared and waiting for the next spawn |
| `flooded_`, `cleared_notified` | `boolean` | |
| `creeps_all`, `creeps_alive`, `creeps_alive_predicted` | `CNPC[]` | |
| `stacks` | `table` | one record per stack |
| `stacks_cache` | `{ count, invisible_count, calculated_spawn_time }` | stack count, including stacks inferred out of vision |
| `get_gold_bounty_cache` | `{ creeps_count, value, value_string }` | estimated gold in the camp |
| `predicted_names_by_state`, `resolved_groups_by_state` | `{ alive = {...}, waiting = {...} }` | which neutrals the camp holds now and after the next spawn |
| `maximal_distance_in_camp` | `number` | 450 |

The official `Camp.GetKnownStackCount` and `Camp.IsKnownClear` cover stack count and cleared state. This manager adds gold estimates, predicted spawns and creeps out of vision.

```lua
function script.OnUpdate()
  local myTeam = Entity.GetTeamNum(Heroes.GetLocal())
  local best, bestGold
  for _, camp in ipairs(JungleCampsManager.camps) do
    if camp.team_ == myTeam and not camp.is_farmed_ then
      local gold = camp.get_gold_bounty_cache.value or 0
      if not bestGold or gold > bestGold then best, bestGold = camp, gold end
    end
  end
  if best then
    local where, stacks = best.position_, best.stacks_cache.count
  end
end
```

---

## LaneGroupsManager

Groups lane creeps into waves per lane. That includes waves in the fog, and waves that haven't spawned or been seen yet, which are predicted from the spawn timer.

**Availability:** callbacks. At load time every list is empty.

```lua
LaneGroupsManager:get_group_by_creep(creep: CNPC) -> LaneGroup?
LaneGroupsManager:get_group_by_index(index: integer) -> LaneGroup?
```

| List | Contents |
|---|---|
| `all_groups` | every wave |
| `groups_ally`, `groups_enemy` | by side |
| `groups_invisible_enemy` | enemy waves out of vision |
| `visible_ally`, `visible_enemy`, `invisible_enemy` | by visibility |
| `w2s_ally`, `w2s_enemy` | predicted waves not spawned or seen yet |
| `groups_by_index_ally`, `groups_by_index_enemy` | keyed by `index_` |
| `creep_to_group` | creep `CNPC` to its wave |

Settings: `merge_distance` (800, waves closer than this merge into one), `merge_groups_update_tick` (30).

### `LaneGroup`

| Field | Type | Meaning |
|---|---|---|
| `index_` | `integer` | wave ID |
| `is_ally_` | `boolean` | |
| `lane` | `integer` | 1 top, 2 middle, 3 bottom |
| `type_` | `integer` | wave kind; 3 and 4 seen, meaning not worked out |
| `position_` | `Vector` | wave centre |
| `creeps` | `CreepRecord[]` | see [LaneCreepsManager](#lanecreepsmanager) |
| `creeps_refs` | `CNPC[]` | the creeps |
| `lane_path` | `Vector[]` | the wave's route |
| `lane_bounds` | `Vector[]` | the lane's outline |
| `get_gold_bounty_cache` | `{ creeps_count, value, value_string }` | gold in the wave |
| `meeting_time_cache`, `path` | `table` | internal |

```lua
function script.OnUpdate()
  for _, wave in ipairs(LaneGroupsManager.invisible_enemy) do
    if wave.lane == 2 then
      local where = wave.position_
      local size = #wave.creeps_refs
      local gold = wave.get_gold_bounty_cache.value
    end
  end
end
```

---

## LaneCreepsManager

Every lane creep the client has seen, with spawn times.

**Availability:** callbacks for the lists. `get_first_spawn_time()` already works at load time; `get_spawn_number()` returns `0` until the manager updates.

```lua
LaneCreepsManager:get(creep: CNPC) -> CreepRecord?
LaneCreepsManager:get_spawn_number(spawn_time?: number) -> number
LaneCreepsManager.get_first_spawn_time() -> number
LaneCreepsManager:is_lane_creep(npc: CNPC) -> boolean
```

- `get` returns a creep's record, or `nil` for anything that isn't a tracked lane creep.
- `get_spawn_number` counts the waves spawned so far, or up to `spawn_time` if given.
- `get_first_spawn_time` is the game time of the first wave.
- `is_lane_creep` has to be called with `:`. With a dot it returns `false` for everything.

| Field | Contents |
|---|---|
| `list`, `list_ally`, `list_enemy` | `CreepRecord[]` |
| `list_by_lane`, `list_by_lane_ally`, `list_by_lane_enemy` | `[lane]` to `CreepRecord[]` |
| `map_by_ref`, `map_by_ref_ally`, `map_by_ref_enemy` | `CNPC` to `CreepRecord` |
| `creeps_spawn_interval` | 30 |

### `CreepRecord`

| Field | Type | Meaning |
|---|---|---|
| `ref` | `CNPC` | the creep |
| `index_` | `integer` | entity index |
| `team_` | `integer` | |
| `lane` | `integer` | 1 top, 2 middle, 3 bottom |
| `lane_path`, `lane_bounds` | `Vector[]` | |
| `spawn_time` | `number` | game time the wave spawned |
| `creation_time` | `number` | game time the client first saw the creep |
| `marked_dead` | `boolean` | |

```lua
function script.OnUpdate()
  local nextWaveAt = LaneCreepsManager.get_first_spawn_time()
    + LaneCreepsManager:get_spawn_number() * LaneCreepsManager.creeps_spawn_interval
  for _, record in ipairs(LaneCreepsManager.list_by_lane_enemy[3] or {}) do
    if not record.marked_dead then
      local creep = record.ref
    end
  end
end
```

---

## JungleCreepsManager

Every neutral creep, including ones in fog, with the health it had when last seen.

**Availability:** callbacks. At load time the spawn number is `-1`.

```lua
JungleCreepsManager:get(creep: CNPC) -> NeutralRecord?
JungleCreepsManager.get_spawn_number(time?: number) -> number
JungleCreepsManager.is_neutral_creep(npc: CNPC) -> boolean
```

Data: `list` (`NeutralRecord[]`), `map_by_ref`, `stacked_count_cache` (entity index to stack count), `first_spawn_time`, `spawn_interval` (60).

### `NeutralRecord`

| Field | Meaning |
|---|---|
| `ref`, `index_` | the creep and its entity index |
| `visible_` | currently in vision |
| `marked_dead`, `flooded_` | |
| `creation_time_`, `creation_number_` | when it appeared, and in which spawn |
| `dormant_spawn` | spawned while out of vision |
| `dormant_health`, `dormant_max_health` | health when last seen |
| `dormant_health_delta` | health change measured while out of vision |

```lua
function script.OnUpdate()
  for _, creep in ipairs(JungleCreepsManager.list) do
    if not creep.marked_dead and not creep.visible_ then
      local lastKnownHp = creep.dormant_health
    end
  end
end
```

---

## LinearProjectilesManager

Tracks skillshots in flight. Besides the engine's own linear projectiles, it creates entries from particles for abilities the engine doesn't report. Those are listed in `fake_on_particle`: Celestial Hammer, Enchant Totem's leap, Bushwhack, Frogstomp, Fire Spirits and Blast Off.

**Availability:** load time and callbacks.

```lua
LinearProjectilesManager:get_list() -> Projectile[]
LinearProjectilesManager:get_by_name(name: string) -> Projectile[]
LinearProjectilesManager:get_by_handle(handle: integer) -> Projectile?
```

- `get_list` returns everything in flight; it's empty when nothing is.
- `get_by_name` returns the projectiles with that particle/projectile name, or an empty table.
- `get_by_handle` returns one projectile, or `nil`.

Data: `projectiles_list`, `projectiles_by_name`, `projectiles_by_handle`, `fake_on_particle`.

```lua
function script.OnUpdate()
  for _, projectile in ipairs(LinearProjectilesManager:get_by_name("hoodwink_bushwhack_projectile")) do
    -- a Bushwhack is in the air
  end
end
```

---

## TargetProjectiles

Homing projectiles in flight: attack projectiles and targeted spells.

**Availability:** load time and callbacks.

```lua
TargetProjectiles.GetAll() -> TargetProjectile[]
```

### `TargetProjectile`

| Field | Type | Meaning |
|---|---|---|
| `handle` | `integer` | projectile handle |
| `source` | `CNPC` | who fired it |
| `target` | `CNPC` | who it's flying at |
| `attack` | `boolean` | an auto-attack projectile, as opposed to a spell |
| `current_position` | `Vector` | where it is now |
| `target_position` | `Vector` | where the target is |
| `speed`, `original_speed` | `number` | current and initial speed |
| `dodgeable` | `boolean` | can be disjointed |
| `evaded` | `boolean` | already dodged |
| `expire_time`, `max_impact_time` | `number` | `0` for ordinary attacks |

```lua
function script.OnUpdate()
  local me = Heroes.GetLocal()
  for _, p in ipairs(TargetProjectiles.GetAll()) do
    if p.target == me and not p.attack and p.dodgeable then
      local eta = (p.target_position - p.current_position):Length2D() / p.speed
    end
  end
end
```

---

## KV_LIB

Reads the game's KeyValues files: abilities, items, units and heroes. The loaded files are in `KV_LIB.loaded_kvs` (`items`, `neutral_items`, `npc_abilities`, `npc_heroes`, `npc_units`).

**Availability:** load time and callbacks.

| Method | Returns |
|---|---|
| `KV_LIB:GetKV(name: string) -> table` | a whole file. `GetKV("npc_heroes").DOTAHeroes` has 130 entries; `GetKV("items").DOTAAbilities` holds the items |
| `KV_LIB:GetUnitKV(unit_name: string) -> table` | a hero's KV merged with its base (106 keys). **Heroes only:** creeps and Roshan raise `bad argument #1 to 'merge_hm'` |
| `KV_LIB:GetHeroAttribute(hero_name: string) -> string` | e.g. `"DOTA_ATTRIBUTE_ALL"` |
| `KV_LIB:HeroIDToName(hero_id: integer) -> string?` | `113` → `"npc_dota_hero_arc_warden"` |
| `KV_LIB:GetAbilityKVS(name: string) -> table` | every special value of an ability, each as `{ value = "...", <talent> = "..." }` |
| `KV_LIB:GetAbilitySpecialKeys(name: string) -> string[]` | the special value names |
| `KV_LIB:GetAbilitySpecialKeyValues(name: string) -> table` | the raw ability block: `AbilityBehavior`, `AbilityCooldown`, `AbilityCastPoint`, `AbilityManaCost`, ... |
| `KV_LIB:GetAbilitySpecialValue(name: string, key: string) -> string` | all levels as one string, e.g. `"15 30 45 60"` |
| `KV_LIB:GetAbilityBehavior(name: string) -> integer` | behavior bitmask (`8` for a unit-target spell) |
| `KV_LIB:HasAbilityBehavior(name: string, behavior: integer) -> boolean` | `behavior` must be an `Enum.AbilityBehavior` number; a string raises a bitwise-operation error |
| `KV_LIB:GetAbilityCastAnimation(name: string) -> integer` | activity ID (`1510` is `ACT_DOTA_CAST_ABILITY_1`) |
| `KV_LIB:IsItemNeutral(name: string) -> boolean` | `item_trusty_shovel` true, `item_tango` false |
| `KV_LIB:IsItemAllowedInBackpack(name: string) -> boolean` | `item_tango` true, `item_aegis` false |
| `KV_LIB:GetFacetNameFromID(hero_name: string, facet_id: integer) -> string?` | |
| `KV_LIB:GetFacetDataFromID(hero_name: string, facet_id: integer) -> table?` | |
| `KV_LIB:GetFacetDataFromName(hero_name: string, facet_name: string) -> table?` | |

The facet lookups take the full hero name; a hero ID or a short name raises an error. They return `nil` for facets missing from the loaded KV data.

`GetAbilityKVS` keeps talent and Scepter modifiers next to each value. For Flux it returns, among others, `damage_per_second = { value = "15 30 45 60", special_bonus_scepter = "+50%" }` and `AbilityCastRange = { value = "500 600 700 800", special_bonus_unique_arc_warden_5 = "200" }`.

```lua
local function perLevel(abilityName, key)
  local out = {}
  for v in KV_LIB:GetAbilitySpecialValue(abilityName, key):gmatch("%S+") do out[#out + 1] = tonumber(v) end
  return out
end

local slow = perLevel("crystal_maiden_crystal_nova", "movespeed_slow")   -- { -20, -30, -40, -50 }

local isPoint = KV_LIB:HasAbilityBehavior("crystal_maiden_crystal_nova",
  Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT)
```

---

## ConvarManager

Typed, cached access to console variables.

**Availability:** load time and callbacks.

| Method | Returns |
|---|---|
| `ConvarManager:get(name: string) -> { name, ref }` | the convar record (`ref` is the official `ConVar` object); `{}` if the convar doesn't exist |
| `ConvarManager:get_float(name: string) -> number` | `dota_roshan_initial_move_timer` → `899` |
| `ConvarManager:get_int(name: string) -> integer` | for a float convar this is the raw bit pattern (`fps_max` = 300.0 → `1133903872`) |
| `ConvarManager:get_bool(name: string) -> boolean` | |
| `ConvarManager:get_string(name: string) -> string` | **crashes the game for non-string convars.** Only use it on convars you know are strings |
| `ConvarManager:set_float(name, value)`, `set_int`, `set_bool`, `set_string` | change the convar |

Every convar you look up is cached in `ConvarManager.convars[name]`.

```lua
local spawnInterval = ConvarManager:get_float("dota_neutral_spawn_interval")
local exists = ConvarManager:get("dota_roshan_initial_move_timer").ref ~= nil
```

---

## ZHelpers

Small combat helpers from the built-in `!_ZHelpers` script. All are plain functions.

**Availability:** load time and callbacks.

| Function | Returns |
|---|---|
| `ZHelpers.ability_is_ready(ability: CAbility, ...) -> boolean, table` | readiness, and a table of reasons it isn't ready. The third argument is a menu widget (`ui_combo`) |
| `ZHelpers.get_attack_phase_left_time(npc: CNPC) -> number` | wind-up time left on the current attack |
| `ZHelpers.get_attack_cooldown_left_time(npc: CNPC) -> number` | time until the next attack can start |
| `ZHelpers.get_status_resistance(npc: CNPC) -> number` | 0 to 1 |
| `ZHelpers.get_duration_amp(npc: CNPC) -> number` | multiplier on debuff durations it applies; `1` normally |
| `ZHelpers.get_thinkers() -> CNPC[]` | live thinker units (Ice Path, Macropyre, ...) |
| `ZHelpers.is_attack_activity(activity: integer) -> boolean` | whether an `Enum.GameActivity` value is an attack |

These are only partly known:

```lua
ZHelpers.get_order_caster(_, order_data: table) -> CNPC
ZHelpers.get_predicted_spell_duration(_, _, _, base_duration: number) -> number
ZHelpers.is_in_aoe_area(_, check_position: Vector, _, radius_like: number, ...) -> boolean
ZHelpers.is_in_linear_area(_, _, _, direction: Vector, ...) -> boolean
ZHelpers.position_clamp(_, my_pos: Vector, ...) -> Vector
ZHelpers.can_hit_target_from_to(..., range: number, start_position: Vector, ...) -> boolean
ZHelpers.is_enemy_near(position: Vector, ...) -> boolean
```

Underscores mark arguments without a known name. `get_order_caster` takes the order table that `OnPrepareUnitOrders` receives, as its second argument. `is_enemy_near`'s second argument is not a radius: `1200` raises an error.

| Field | Contents |
|---|---|
| `cliff_positions` | 6 `Vector`s on cliffs |
| `particles_map` | radius-ring particle styles: `Dota`, `Dotted`, `Dust`, `Fade`, `Fade Dynamic`, `Fog`, `Solid`, `Solid Glow`, each a `.vpcf` path |
| `menu_scale_table`, `menu_scale_table_string` | menu scale steps 75 to 200 |

```lua
function script.OnUpdate()
  local me = Heroes.GetLocal()
  if ZHelpers.get_attack_phase_left_time(me) > 0 then return end   -- mid-swing, don't interrupt
  local ready, reasons = ZHelpers.ability_is_ready(NPC.GetAbilityByIndex(me, 0))
end

local ringParticle = ZHelpers.particles_map["Solid Glow"]
```

---

## LIB_HEROES_DATA

The framework behind Umbrella's built-in hero scripts: a cached record of your hero, shared menu widgets, and a table of 99 helper functions. It comes from `1_heroes_data_system.lua`.

**Availability:** load time and callbacks.

| Function | Returns |
|---|---|
| `LIB_HEROES_DATA.get() -> HeroData, HeroData, table` | your hero's record, a second record, and a helpers table |
| `LIB_HEROES_DATA.get_helpers() -> Helpers` | the helper functions below |
| `LIB_HEROES_DATA.get_controlled_hero() -> CNPC?` | the hero a built-in hero script is controlling, or `nil` |
| `LIB_HEROES_DATA.get_target(my_data: HeroData, unit_find_range_ui) -> CNPC?` | a hero script's combo target. Needs that script's range widget, so it isn't usable from your own script |
| `LIB_HEROES_DATA.fountain()` | returns nothing outside hero scripts; use the `fountains` field |
| `LIB_HEROES_DATA.cast_is_in_flight(ability: CAbility) -> boolean` | whether a cast of that ability is still in progress |
| `LIB_HEROES_DATA.local_hero_name() -> string` | `"npc_dota_hero_arc_warden"` |
| `LIB_HEROES_DATA.multibox_enabled() -> boolean` | |

### `HeroData`

| Field | Meaning |
|---|---|
| `ref` | the hero |
| `unit_name`, `id`, `player_id`, `player_ref`, `team` | identity (`id` is the entity index) |
| `hp`, `maxhp`, `mana`, `max_mana`, `mana_regen`, `hull` | current values |
| `pos`, `pos_draw` | position, and the position to draw at |
| `ability` | abilities by slot |
| `ability_by_name` | abilities by name, including talents and seasonal abilities |
| `aspect_ability`, `aspect_ability_by_name`, `aspect_id` | facet abilities |
| `talents` | |
| `courier`, `hud_unit`, `selected_units`, `new_query_unit_panel` | |
| `_last_update_time` | game time of the last refresh |

### Other fields

| Field | Contents |
|---|---|
| `heroes`, `enemies`, `teammates`, `my_hero` | hero lists |
| `npcs_by_name`, `entity_list`, `entity_list_by_classname` | entity indexes |
| `items`, `item_by_slot` | your items |
| `fountains` | `{ my = { pos, ref }, enemy = { pos, ref }, list }` |
| `teleport_time`, `teleport_time_by_entity` | teleport tracking |
| `ui` | shared menu widgets of the hero scripts |
| `match_id`, `ping`, `dota_time`, `curtime`, `clock_time`, `tickcount` | |

```lua
local data = LIB_HEROES_DATA.get()
local flux = data.ability_by_name["arc_warden_flux"]
local home = LIB_HEROES_DATA.fountains.my.pos
```

### Helpers

```lua
local helpers = LIB_HEROES_DATA.get_helpers()
```

**State checks.** Each takes `(npc: CNPC)` and returns a boolean:

| | | |
|---|---|---|
| `is_stunned` | `is_hexed` | `is_silenced` |
| `is_rooted` | `is_disarmed` | `is_taunted` |
| `is_doomed` | `is_bkb` | `is_magic_immune` |
| `is_attack_immune` | `is_invulnerable` | `is_out_of_game` |
| `is_untargetable` | `is_untargetable_to_ally` | `is_untargetable_to_enemy` |
| `is_unselectable` | `is_nonrootable` | `is_nonslowable` |
| `is_no_hp_bar` | `is_interactable` | `can_move` |
| `can_attack` | `can_attack_in_ghost` | `has_aeon` |
| `linken_sphere` | `mirror_shield` | `interrupt_ability_check` |
| `aghanim` | `shard` | |

`is_day_time()` and `is_local_hero_hud()` take no arguments.

**Durations.** Each takes `(npc: CNPC)` and returns the seconds left, or `0`: `stun_duration`, `hex_duration`, `root_duration`, `silence_duration`, `taunt_duration`, `ghost_duration`, `astral_duration`, `tornado_duration`, `bkb_duration`, `control_duration` (any disable), `modifier_duration`.

```lua
function script.OnUpdate()
  local target = --[[ an enemy hero ]] nil
  if not target then return end
  if helpers.is_stunned(target) or helpers.is_hexed(target) then
    local left = helpers.control_duration(target)
    -- chain your own disable so it starts as this one ends
  end
end
```

**Unit values.**

| Function | Returns |
|---|---|
| `helpers.get_move_speed(npc) -> number` | |
| `helpers.get_attack_range(npc) -> number` | `116` for a melee creep |
| `helpers.blind_amount(npc) -> number, number` | |
| `helpers.hero_damage_amp(npc) -> number?` | |
| `helpers.special_hero_reduce_damage(npc) -> number?` | |
| `helpers.medusa_shield(npc) -> number?` | |
| `helpers.get_aftershock_range(npc) -> number` | |
| `helpers.last_rotation_time(npc) -> number, Vector` | time of the last turn, and the facing direction |
| `helpers.attribute(hero) -> number` | heroes only; anything else raises an error |
| `helpers.value(ability, ...) -> number` | an ability special value; the first argument must be an ability |
| `helpers.attributes` | a table, not a function |

**Geometry.**

| Function | Returns |
|---|---|
| `helpers.dist_to(vector_1, vector_2) -> number` | 3D distance |
| `helpers.dist_to_2d(vector_1, vector_2) -> number` | distance ignoring height |
| `helpers.to_angle(input: Vector) -> Angle` | the direction as an angle; `(500, 0, 0)` gave `Angle(0, 90, 0)`, so yaw is measured from the +Y axis |
| `helpers.normalize_yaw(yaw) -> number` | into -180..180 (`270` → `-90`) |
| `helpers.closest_point_on_line(start_point, end_point, point) -> Vector` | the point on the segment closest to `point`, with `z = 0` |
| `helpers.find_segment_intersection(a1, a2, b1, b2) -> { x, y }?` | where two segments cross, as a 2D table |
| `helpers.find_intersection_ray_to_circle(origin, direction, sphereCenter, radius) -> Vector?` | the first point where a ray enters a circle |
| `helpers.is_in_polygon(point, points_table) -> boolean, number[]` | whether `point` is inside, plus its distance to each vertex |
| `helpers.calculate_average_point(positions) -> Vector` | the centre of a list of positions |
| `helpers.vector_mult(vec1, vec2) -> number` | the 2D cross product `x1 * y2 - y1 * x2` (`(1,2) × (2,2)` = `-2`) |
| `helpers.math_clamp(value, min, max) -> number` | |
| `helpers.math_round(what, step) -> number` | rounds `what` to a multiple of `step`; `step` is required |
| `helpers.get_sign(value) -> number` | `-1`, `0` or `1` |
| `helpers.rotate_time(npc, position) -> number, number` | turn time in seconds, and the angle in degrees |
| `helpers.get_path_distance(from: Vector, to: Vector) -> number` | walking distance; `0` when no path is built, so check the result |

```lua
local a, b = Vector(0, 0, 0), Vector(1000, 0, 0)
local onLine = helpers.closest_point_on_line(a, b, Vector(400, 300, 0))   -- (400, 0, 0)
local cross = helpers.find_segment_intersection(a, b, Vector(500, -100, 0), Vector(500, 100, 0))   -- { x = 500, y = 0 }
```

**Partly known.**

| Function | What's known |
|---|---|
| `helpers.projectile_travel_time(..., distance, projectile_speed)` | needs a distance and a projectile speed; `projectile_speed` is not the first or second argument |
| `helpers.spec_armor(damage, count)` | the first argument is a damage number |
| `helpers.etherials(npc, damage) -> number` | `damage` after the Ethereal amplification on `npc`; unchanged when there's none |
| `helpers.predict_pos(npc, time, ...)` | also needs a move speed it doesn't look up on its own |
| `helpers.calc_safe_pos(pos, other: Vector, ...)` | needs a second position |
| `helpers.skill_cast_time(ability) -> number, boolean` | |
| `helpers.homing_projectile_time(projectile, ...)` | takes a projectile record |
| `helpers.is_basic_dispeling`, `is_strong_dispeling`, `is_dispeling_buffs` | take a `modifiers` argument, but not as the first parameter |
| `helpers.is_ghosted(npc, ...)`, `helpers.item_slot_is_active(...)` | take a `mod_path` argument, not as the second parameter |
| `helpers.point_in_aoe_skill_area(entity, ...)`, `helpers.point_in_linear_skill_area(entity, ...)` | the first argument is an entity |
| `helpers.find_best_point`, `find_box_point(spot, ...)`, `find_average_point`, `scan_average_point`, `generate_combinations`, `generate_combinations_with_element` | the pieces behind aiming an area spell at the most heroes |
| `helpers.predict_magic_damage`, `predict_physic_damage`, `predict_pure_damage`, `amplify` | need the context of a built-in hero script and fail without it. Use `LIB_DAMAGE_PREDICTION:mitigate_damage` instead |
| `helpers.get_combo_units`, `auto_stack`, `blink_to_mod`, `override_my_data`, `delay_call`, `delay_call_ex` | used by hero scripts; `get_combo_units` and `auto_stack` issue orders |

---

## LIB_RENDER

Umbrella's drawing and UI library (`1_render_lib.lua`), used by its built-in scripts. For your own drawing, the official `Render.*` API is documented and easier to use. `LIB_RENDER` is mainly useful for its theme, icon paths and hitboxes.

**Availability:** drawing functions only inside `OnDraw`.

| Function | Returns |
|---|---|
| `LIB_RENDER.world_to_screen(pos: Vector) -> Vec2, boolean` | screen position, and whether it's on screen |
| `LIB_RENDER.in_bounds(pos_1: Vec2, pos_2: Vec2) -> boolean` | whether the cursor is inside the rectangle |
| `LIB_RENDER.in_bounds_coordinates(...) -> boolean` | the same with plain numbers |
| `LIB_RENDER.is_visible(top_left: Vec2, bot_right: Vec2) -> boolean` | whether the rectangle is on screen |
| `LIB_RENDER.get_hero_icon_path(hero_name: string) -> string` | `"panorama/images/heroes/icons/<name>..."` |
| `LIB_RENDER.get_ability_icon_path(name: string) -> string` | `"panorama/images/spellicons/<name>..."` |
| `LIB_RENDER.get_player_color(player_slot: integer) -> Color` | the slot's player colour |
| `LIB_RENDER.theme() -> table` | current menu colours: `primary_widgets_text`, `active_widgets_text`, `outline`, `group_background`, `group_outline`, `slider_background`, `slider_grab`, `combo_frame`, `keybind_background`, `healthbar_self`, ... |
| `LIB_RENDER.button_hitbox(...) -> Hitbox` | a clickable area |
| `LIB_RENDER.drag_hitbox(...) -> Hitbox` | a draggable area |

A `Hitbox` has `func` (on click), `release_func`, `on_frame`, `on_key_event_once`, `disable_condition`, `disable_func`, `override_key_code`, `key_code`, `block_dota_input`, `last_usage_time`, `tick`, `type` and `delete`. Drag hitboxes also have `edit_pos`. Call `hitbox.delete()` when your script unloads.

Drawing functions and their named parameters:

| Function | Known parameters |
|---|---|
| `text` | `pos` (fourth); probably font, size and text first |
| `line_arrowed` | `start` |
| `blur` | `pos_1`, `pos_2` |
| `simple_int_ind` | `cur_num`, `max_num` |
| `render_skill_indicator` | `name`, `abil_name` |
| `skill_cooldown_icon`, `get_opacity_modulator` | `image_size` |
| `particle_position_cast` | `value` |
| `triagle`, `filled_triagle` (sic) | a table of three points first |

Other functions: `line`, `circle`, `filled_circle`, `glow_circle`, `gradient_circle`, `filled_rect`, `outline_rect`, `gradient`, `glow`, `text_size`, `font`, `image`, `image_size`, `load_image`, `localizer`, `clip`, `pop_clip`, `centered_notification`, `side_notification`, `chat_notification`, `hud_error`, `emit_sound`, `draw_hero_indicator`, `set_need_update_ind`, `set_need_update_ind_add`, `calculate_value`, `calculate_value_no_clamp`, `math_clamp`, `inventory_slot_update`, `remove_inventory_slot`, `add_item_to_inventory_bind_change`, `items_to_inventory_change`, `clone`, `clone_c`.

| Field | Contents |
|---|---|
| `scale` | UI scale (`1.0`) |
| `screen_size` | screen size |
| `cursos_pos` (sic), `cursor_pos_world` | cursor on screen and in the world |
| `default_font`, `default_font_awesome` | font handles |
| `anim_values` | animation state of the built-in panels, keyed by name |
| `easings` | 4 easing curves |
| `hitbox_array`, `skill_ind_data`, `skill_ind_names` | |

```lua
function script.OnDraw()
  local theme = LIB_RENDER.theme()
  local screen, onScreen = LIB_RENDER.world_to_screen(Entity.GetAbsOrigin(Heroes.GetLocal()))
  if onScreen then
    Render.FilledRect(screen - Vec2(40, 10), screen + Vec2(40, 10), theme.group_background, 4)
  end
end
```

---

## CallbacksManager

The dispatcher behind every engine callback. `CallbacksManager.OnUpdate`, `CallbacksManager.OnDraw` and so on run the handlers of every script registered for that event, so don't call them yourself.

**Availability:** load time and callbacks.

```lua
CallbacksManager:get_callbacks_count(name: string) -> integer
CallbacksManager:get_callback_priority_by_identifier(identifier: string) -> number
```

- `get_callbacks_count` is the number of handlers registered for an event: `CallbacksManager:get_callbacks_count("OnUpdate")` was `64`. Called with a dot it returns `0`.
- `get_callback_priority_by_identifier` returns `inf` for unknown identifiers.

| Field | Contents |
|---|---|
| `callbacks[slot]` | handler functions for each event slot (67 slots) |
| `callbacks_count[slot]`, `callbacks_priorities[slot]` | counts and priorities |
| `callbacks_identifiers[slot]` | `{ identifier = handler }` |
| `update_callbacks`, `destroy_callbacks` | handlers added through `set_update_callback` / `set_destroy_callback` |
| `menu_callbacks` | `{ widget = handler }` |
| `load_count` | number of script loads since the game started |

`set`, `unset`, `set_update_callback`, `set_destroy_callback` and the `__dispatch*` functions register and remove handlers.

`callbacks_identifiers` shows every built-in feature that is running: `KillStealer`, `Orbwalker`, `ProcastDamage`, `dodger`, `auto_disabler`, `AutoStacker`, `CreepBlocker`, `IllusionController`, `ItemsManager`, `RoshanMonitor`, `Snatcher`, `BottleTracker`, `FailSwitch`, `bodyblocker`, `tranquil_helper`, `XPMaphack`, `AurasMaphack`, `CouriersMaphack`, `LaneCreepsMaphack`, `RoshanMaphack`, `x_script_ward_helper`, `x_script_betterui`, `Watermark` and more.

```lua
local function runningFeatures()
  local found = {}
  for _, slot in pairs(CallbacksManager.callbacks_identifiers) do
    for identifier in pairs(slot) do found[identifier] = true end
  end
  return found
end

if runningFeatures().dodger then
  -- Umbrella's Dodger is on; leave dodging to it
end
```

---

## XHelpers

The xlib shared library (`8_xlib_bundled.lua`): 33 modules with 461 functions. Every function is listed under [All XHelpers functions](#all-xhelpers-functions).

**Availability:** load time and callbacks.

### Top-level functions

| Function | Returns |
|---|---|
| `XHelpers.GetBuildInfo()` | `{ name = "public", pretty_name = "Public" }` |
| `XHelpers.IsDev()`, `IsClientSide()`, `IsBetaOrOverride()`, `IsFirstLoad()` | `false` on a normal build |
| `XHelpers.GetScriptList()` | `{ "WardHelper", "Watermark", "MuteChatWheel", "FailSwitch", "BetterUI", "ProfileChanger", "AutoStacker" }` |
| `XHelpers.GetModuleList()` | the 33 module names (`JSON`, `protobuf`, `xkeyvalues`, `XLazyTable`, `cachetools`, `XLocalizer`, `XHTTP`, `xutil`, `xkv`, `XAbility`, `XItem`, `XNPC`, `XEntity`, `XPlayer`, `XHero`, `XModifier`, `XGridNav`, `XPanorama`, `XMiniMap`, `XInput`, `XRune`, `XTree`, ...) |
| `XHelpers.GetScript(name)` | a running xlib script's table |
| `XHelpers.GetModule(name)` | a module; `GetModule("XNPC") == XHelpers.XNPC` |
| `XHelpers.UpdateTick()` | xlib's tick counter |
| `XHelpers.BaseScript`, `AddScript`, `AddModule`, `EmitCallback`, `GetCallbacks`, `WrapCallbacks` | xlib's script framework |

`XHelpers.is_serverside` is `true`. `XHelpers.protobuf` and `XHelpers.XVectorTargetManager` are the same tables as the globals `protobuf` and `XVectorTargetManager`.

### Modules

| Module | Functions | Area |
|---|---|---|
| `XAbility` | 135 | AoE radii, projectile speeds, dispel and fear data |
| `XNPC` | 103 | unit state, attacks, ranges, immunities |
| `xkv`, `xutil` | 20 each | KeyValues; miscellaneous |
| `XHero`, `XItem` | 16 each | |
| `XPlayer` | 13 | player and selection |
| `xmath` | 12 | |
| `XGridNav` | 11 | pathing |
| `XLocalizer` | 10 | names and ability owners |
| `XInput`, `XRender` | 9 each | |
| `JSON` | 2 | `:encode`, `:decode`; must be called with `:` |

### Reading another script

`GetScript` returns the table of a running xlib script, including its menu widgets and data. Ward Helper's, for example, has `positions_observer`, `positions_sentry_camp_block`, `ui` and `callbacks_manager_id = "x_script_ward_helper"`. Its spot lists are empty until the script has loaded its data for the map.

```lua
local json = XHelpers.JSON:encode({ a = 1, b = { 2, 3 } })   -- '{"a":1,"b":[2,3]}'
local back = XHelpers.JSON:decode(json)

local clock = XHelpers.xutil:GameTimeToDotaTime(GameRules.GetGameTime())   -- same as GameRules.GetDOTATime()

local wards = XHelpers.GetScript("WardHelper")
local spots = wards and wards.positions_observer
```

### All XHelpers functions

Arguments are positional. In the object modules the first argument is the object the module works on (`npc` for `XNPC`, `ability` for `XAbility`, and so on); the rest are numbered. **Calls** lists the engine functions a helper uses, which says a lot about what it does. **Returns** shows the returned expression where it's short.

#### `XHelpers`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.AddModule(arg1, arg2)` |  | log |
| `XHelpers.AddScript(arg1, arg2)` |  | log |
| `XHelpers.BaseScript(arg1)` | `XHelpers.WrapCallbacks(arg1)` | log |
| `XHelpers.EmitCallback(arg1, ...)` |  |  |
| `XHelpers.GetBuildInfo()` | `{ name = (internal), pretty_name = (internal)[(internal)] or (internal) }` |  |
| `XHelpers.GetCallbacks(arg1)` | `(internal)` | table.Filter |
| `XHelpers.GetModule(arg1)` | `XHelpers[arg1]` |  |
| `XHelpers.GetModuleList()` | `table.CopyShallow((internal))` | table.CopyShallow |
| `XHelpers.GetScript(arg1)` | `(internal)[arg1]` |  |
| `XHelpers.GetScriptList()` | `table.Keys((internal))` | table.Keys |
| `XHelpers.IsBetaOrOverride()` | `true` |  |
| `XHelpers.IsClientSide()` |  |  |
| `XHelpers.IsDev()` | `self.is_dev()` |  |
| `XHelpers.IsFirstLoad()` | `(internal)` |  |
| `XHelpers.UpdateTick()` | `(internal)` |  |
| `XHelpers.WrapCallbacks(arg1, arg2)` |  |  |

#### `XHelpers.Timers`

Data: `last_think`, `last_think_time`, `timers`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.Timers:CreateTimer(arg1, arg2, arg3)` | `-1` | log |
| `XHelpers.Timers.GetRemainingTime(...)` |  | 2 functions share this name; arguments vary |
| `XHelpers.Timers:HandleEventError(arg1, arg2, arg3)` |  | log |
| `XHelpers.Timers:RemoveTimer(arg1)` |  |  |
| `XHelpers.Timers:RemoveTimers(arg1)` |  |  |
| `XHelpers.Timers:Think()` |  | GameRules.GetGameTime |

#### `XHelpers.XAbility`

Per-ability function tables (callbacks keyed by ability name): `aoe_radiuses` (5), `aoe_target_types` (1), `dispel_enemy_types` (1), `fear_durations` (2), `linear_projectile_lengths` (4), `linear_projectile_speeds` (4), `normalization` (28), `on_attack_slow` (3), `radiuses` (3), `root_durations` (2), `silence_durations` (4), `start_widths` (2), `stun_durations` (7), `taunt_durations` (2), `true_sight_radiuses` (1).

Data: `AbilityCastType`, `aoe_radiuses`, `aoe_target_abilities`, `aoe_target_flags`, `aoe_target_triggers_aoe`, `aoe_target_types`, `aoe_team_types`, `bash_durations`, `cast_ranges`, `cast_types`, `disables_ignoring_status_resistance`, `dispel_enemy_types`, `double_tap_target_to_position_abilities`, `end_widths`, `fear_durations`, `hex_durations`, `immunity_types`, `impact_delays`, `invoker_crafts`, `linear_projectile_accelerations`, `linear_projectile_destroys_on_hit`, `linear_projectile_lengths`, `linear_projectile_speeds`, `max_cast_ranges`, `min_cast_ranges`, `mute_durations`, `normalization`, `not_debuff_immune_cast_abilities`, `not_debuff_immune_pierce_abilities`, `not_morphable_abilities`, `not_planar_pocket_triggering_abilities`, `not_refreshable_abilities`, `not_stealable_abilities`, `on_attack_slow`, `on_attack_slow_durations`, `radiuses`, `root_durations`, `silence_durations`, `start_widths`, `stun_durations`, `taunt_durations`, `tracking_projectile_accelerations`, `tracking_projectile_speeds`, `true_sight_affects_wards`, `true_sight_radiuses`.

| Function                                                                       | Returns                                              | Calls                                                                                                                     |
| ------------------------------------------------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `XHelpers.XAbility:CanBeCrafted(ability)`                                      | `false`                                              | Ability.GetLevel, Ability.GetName, Ability.GetOwner, Ability.IsHidden, NPC.GetAbility                                     |
| `XHelpers.XAbility:CanCastOnDebuffImmune(ability, arg2)`                       |                                                      |                                                                                                                           |
| `XHelpers.XAbility:Cast(ability, arg2, arg3, arg4, arg5, arg6, arg7, arg8)`    |                                                      | Ability.GetBehavior, Ability.GetOwner, Ability.IsHidden, Entity.GetOrigin, Player.PrepareUnitOrders, Players.GetLocal ... |
| `XHelpers.XAbility.Craft(ability, arg2, arg3, arg4)`                           |                                                      | Ability.GetCooldown, Ability.GetName, Ability.GetOwner, Ability.IsHidden, NPC.GetAbility                                  |
| `XHelpers.XAbility:DisableIgnoresStatusResistance(ability, arg2)`              |                                                      |                                                                                                                           |
| `XHelpers.XAbility:ExecuteAbility(ability, arg2, arg3)`                        |                                                      | Ability.GetOwner, Entity.GetIndex                                                                                         |
| `XHelpers.XAbility:GetAOERadius(ability, arg2)`                                | `Ability.GetLevelSpecialValueFor(ability, "aoe")`    | Ability.GetLevelSpecialValueFor                                                                                           |
| `XHelpers.XAbility:GetBashDuration(ability, arg2)`                             | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetChargeRestoreTime(ability, arg2)`                        |                                                      | Ability.GetLevel, Ability.GetName, Ability.GetOwner                                                                       |
| `XHelpers.XAbility:GetCooldownTime(ability, arg2)`                             |                                                      | Ability.GetLevel, Ability.GetName, Ability.GetOwner                                                                       |
| `XHelpers.XAbility:GetDisableDuration(ability, arg2)`                          |                                                      |                                                                                                                           |
| `XHelpers.XAbility:GetDisableDurationToTarget(ability, arg2, arg3, arg4)`      | `0, 0`                                               | Ability.GetCastPoint, Ability.GetLevelSpecialValueFor, Ability.GetName, Ability.GetOwner, Angle, Entity.GetOrigin ...     |
| `XHelpers.XAbility:GetEffectiveCastRange(ability, arg2)`                       | `Ability.GetCastRange(ability)`                      | Ability.GetCastRange, Ability.GetOwner, NPC.GetCastRangeBonus                                                             |
| `XHelpers.XAbility:GetEffectiveCooldown(ability)`                              |                                                      | Ability.GetCooldown, Ability.GetName, Ability.GetOwner, Ability.IsHidden, NPC.GetAbility                                  |
| `XHelpers.XAbility:GetEndWidth(ability, arg2)`                                 | `self:GetStartWidth(ability, arg2)`                  |                                                                                                                           |
| `XHelpers.XAbility:GetEnemyDispelType(ability, arg2)`                          |                                                      |                                                                                                                           |
| `XHelpers.XAbility:GetFearDuration(ability, arg2)`                             | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetHexDuration(ability, arg2)`                              | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetImmunityType(ability)`                                   | `Ability.GetImmunityType(ability)`                   | Ability.GetImmunityType                                                                                                   |
| `XHelpers.XAbility:GetImpactDelay(ability, arg2)`                              | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetLinearProjectileAcceleration(ability, arg2)`             | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetLinearProjectileLength(ability, arg2)`                   | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetLinearProjectileSpeed(ability, arg2)`                    | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetMaxCastRange(ability, arg2)`                             | `0`                                                  | Ability.GetOwner, NPC.GetCastRangeBonus                                                                                   |
| `XHelpers.XAbility:GetMinCastRange(ability, arg2)`                             | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetMuteDuration(ability, arg2)`                             | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetNormalizedOrderTargets(ability, arg2, arg3, arg4, arg5)` |                                                      | Ability.GetLevelSpecialValueFor, Ability.GetName, Ability.GetOwner, Entity.GetTeamNum, Entity.IsNPC, Heroes.GetLocal ...  |
| `XHelpers.XAbility:GetOnAttackSlow(ability, arg2)`                             | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetOnAttackSlowDuration(ability, arg2)`                     | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetProjectileHitPositionTime(ability, arg2, arg3)`          |                                                      | Ability.GetOwner, Entity.GetOrigin, NPC.GetHullRadius                                                                     |
| `XHelpers.XAbility:GetProjectileHitTargetTime(ability, arg2, arg3)`            |                                                      | Ability.GetOwner, Entity.GetOrigin, NPC.GetHullRadius                                                                     |
| `XHelpers.XAbility:GetRadius(ability, arg2)`                                   | `Ability.GetLevelSpecialValueFor(ability, "radius")` | Ability.GetLevelSpecialValueFor                                                                                           |
| `XHelpers.XAbility:GetRootDuration(ability, arg2)`                             | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetSilenceDuration(ability, arg2)`                          | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetStartWidth(ability, arg2)`                               | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetStunDuration(ability, arg2)`                             | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetTauntDuration(ability, arg2)`                            | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetTimeToMove(ability, arg2, arg3)`                         |                                                      | Ability.GetOwner, Entity.GetOrigin, NPC.GetHullRadius, NPC.GetMoveSpeed, NPC.GetTimeToFacePosition                        |
| `XHelpers.XAbility:GetTrackingProjectileAcceleration(ability, arg2)`           | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetTrackingProjectileSpeed(ability, arg2)`                  | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:GetTrueSightRadius(ability, arg2)`                          | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility.GetVectorTargetOrder(ability, arg2)`                        | `ability.__vector_target_order`                      |                                                                                                                           |
| `XHelpers.XAbility:GetVectorTargetPosition(ability)`                           | `api.p2_Vector()`                                    | Vector                                                                                                                    |
| `XHelpers.XAbility:GuessAOETargetFlags(ability)`                               | `self.Enum.TargetFlags.DOTA_UNIT_TARGET_FLAG_NONE`   | Ability.GetTargetFlags                                                                                                    |
| `XHelpers.XAbility:GuessAOETargetTeam(ability)`                                | `self.Enum.TargetTeam.DOTA_UNIT_TARGET_TEAM_BOTH`    | Ability.GetDamageType, Ability.GetTargetFlags, Ability.GetTargetTeam                                                      |
| `XHelpers.XAbility:GuessAOETargetTypes(ability)`                               | `self.Enum.TargetType.DOTA_UNIT_TARGET_BASIC`        | Ability.GetTargetType                                                                                                     |
| `XHelpers.XAbility:IgnoresSilence(ability)`                                    |                                                      | Ability.GetBehavior                                                                                                       |
| `XHelpers.XAbility:IgnoresStun(ability)`                                       |                                                      | Ability.GetBehavior                                                                                                       |
| `XHelpers.XAbility:IsChakraMagicCooldownReducable(ability)`                    | `not Ability.IsUltimate(ability)`                    | Ability.IsUltimate                                                                                                        |
| `XHelpers.XAbility:IsDoubleTapTargetToPosition(ability, arg2)`                 |                                                      |                                                                                                                           |
| `XHelpers.XAbility:IsMorphable(ability, arg2)`                                 | `false`                                              | Ability.IsUltimate                                                                                                        |
| `XHelpers.XAbility:IsRefreshable(ability, arg2)`                               |                                                      |                                                                                                                           |
| `XHelpers.XAbility:IsStealable(ability, arg2)`                                 | `false`                                              | Ability.GetBehavior, Ability.GetName, Ability.IsInnate                                                                    |
| `XHelpers.XAbility:IsTalent(ability)`                                          |                                                      | Ability.GetType                                                                                                           |
| `XHelpers.XAbility:LinearProjectileDestroyesOnHit(ability, arg2)`              |                                                      |                                                                                                                           |
| `XHelpers.XAbility:NormalizeCastOrder(ability, arg2)`                          | `{}`                                                 | Ability.GetName, Ability.GetOwner, Entity.GetOrigin, Entity.GetRotation, Entity.GetTeamNum, Entity.RecursiveGetOwner ...  |
| `XHelpers.XAbility:PiercesBKB(ability, arg2)`                                  |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RCanCastOnDebuffImmune(ability, arg2, arg3)`                |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RCanTargetTeamType(ability, arg2)`                          | `true`                                               |                                                                                                                           |
| `XHelpers.XAbility:RCastBreaksInvisibility(ability, arg2, arg3)`               | `false`                                              |                                                                                                                           |
| `XHelpers.XAbility:RDisableIgnoresStatusResistance(ability, arg2, arg3)`       |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RGetAOERadius(ability, arg2, arg3)`                         |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RGetAOERadiusRequirements(ability)`                         | `(internal)("aoe_radiuses", ability)`                |                                                                                                                           |
| `XHelpers.XAbility:RGetAbilityCastType(ability)`                               |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RGetBashDuration(ability, arg2, arg3)`                      | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetBashRequirements(ability)`                              | `(internal)("bash_durations", ability)`              |                                                                                                                           |
| `XHelpers.XAbility:RGetChargeRestoreTime(ability, arg2, arg3)`                 |                                                      | Hero.GetFacetID, NPC.HasScepter, NPC.HasShard                                                                             |
| `XHelpers.XAbility:RGetCooldownTime(ability, arg2, arg3)`                      |                                                      | Hero.GetFacetID, NPC.HasScepter, NPC.HasShard                                                                             |
| `XHelpers.XAbility:RGetDisableDuration(ability, arg2, arg3)`                   |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RGetDisableRequirements(ability)`                           |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RGetEndWidth(ability, arg2, arg3)`                          | `self:RGetStartWidth(ability, arg2, arg3)`           |                                                                                                                           |
| `XHelpers.XAbility:RGetEnemyDispelType(ability, arg2, arg3)`                   |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RGetFearDuration(ability, arg2, arg3)`                      | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetFearRequirements(ability)`                              | `(internal)("fear_durations", ability)`              |                                                                                                                           |
| `XHelpers.XAbility:RGetHexDuration(ability, arg2, arg3)`                       | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetHexRequirements(ability)`                               | `(internal)("hex_durations", ability)`               |                                                                                                                           |
| `XHelpers.XAbility:RGetImmunityType(ability, arg2, arg3)`                      |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RGetImpactDelay(ability, arg2, arg3)`                       | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetLinearProjectileAcceleration(ability, arg2, arg3)`      | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetLinearProjectileLength(ability, arg2, arg3)`            | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetLinearProjectileSpeed(ability, arg2, arg3)`             | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetMaxCastRange(ability, arg2, arg3)`                      | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetMinCastRange(ability, arg2, arg3)`                      | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetMuteDuration(ability, arg2, arg3)`                      | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetMuteRequirements(ability)`                              | `(internal)("mute_durations", ability)`              |                                                                                                                           |
| `XHelpers.XAbility:RGetOnAttackSlow(ability, arg2, arg3)`                      | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetOnAttackSlowDuration(ability, arg2, arg3)`              | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetOnAttackSlowDurationsRequirements(ability)`             | `(internal)("on_attack_slow_durations", ability)`    |                                                                                                                           |
| `XHelpers.XAbility:RGetOnAttackSlowRequirements(ability)`                      | `(internal)("on_attack_slow", ability)`              |                                                                                                                           |
| `XHelpers.XAbility:RGetRadius(ability, arg2, arg3)`                            |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RGetRequirementsForSpecial(ability, arg2)`                  | `(internal)(ability, arg2)`                          |                                                                                                                           |
| `XHelpers.XAbility:RGetRootDuration(ability, arg2, arg3)`                      | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetRootRequirements(ability)`                              | `(internal)("root_durations", ability)`              |                                                                                                                           |
| `XHelpers.XAbility:RGetSilenceDuration(ability, arg2, arg3)`                   | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetSilenceRequirements(ability)`                           | `(internal)("silence_durations", ability)`           |                                                                                                                           |
| `XHelpers.XAbility:RGetStackCooldownModifier(ability)`                         | `(internal)[ability]`                                |                                                                                                                           |
| `XHelpers.XAbility:RGetStartWidth(ability, arg2, arg3)`                        | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetStunDuration(ability, arg2, arg3)`                      | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetStunRequirements(ability)`                              | `(internal)("stun_durations", ability)`              |                                                                                                                           |
| `XHelpers.XAbility:RGetTauntDuration(ability, arg2, arg3)`                     | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetTauntRequirements(ability)`                             | `(internal)("taunt_durations", ability)`             |                                                                                                                           |
| `XHelpers.XAbility:RGetTrackingProjectileAcceleration(ability, arg2, arg3)`    | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetTrackingProjectileSpeed(ability, arg2, arg3)`           | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGetTrueSightRadius(ability, arg2, arg3)`                   | `0`                                                  |                                                                                                                           |
| `XHelpers.XAbility:RGuessAOETargetFlags(ability, arg2)`                        | `self.Enum.TargetFlags.DOTA_UNIT_TARGET_FLAG_NONE`   |                                                                                                                           |
| `XHelpers.XAbility:RGuessAOETargetTeam(ability, arg2)`                         | `self.Enum.TargetTeam.DOTA_UNIT_TARGET_TEAM_BOTH`    |                                                                                                                           |
| `XHelpers.XAbility:RGuessAOETargetTypes(ability, arg2)`                        | `self.Enum.TargetType.DOTA_UNIT_TARGET_BASIC`        |                                                                                                                           |
| `XHelpers.XAbility:RIgnoresSilence(ability)`                                   |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RIgnoresStun(ability)`                                      |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RIsAOEUnitTarget(ability, arg2, arg3)`                      |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RIsAOEUnitTargetTriggersUnits(ability, arg2, arg3)`         |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RIsChakraMagicCooldownReducable(ability)`                   |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RIsDoubleTapTargetToPosition(ability, arg2, arg3)`          |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RIsInnate(ability)`                                         |                                                      | tostring                                                                                                                  |
| `XHelpers.XAbility:RIsMorphable(ability, arg2, arg3)`                          | `false`                                              |                                                                                                                           |
| `XHelpers.XAbility:RIsRefreshable(ability, arg2, arg3)`                        |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RIsStealable(ability, arg2, arg3)`                          | `false`                                              |                                                                                                                           |
| `XHelpers.XAbility:RIsTalent(ability)`                                         | `self.string.startswith(ability, "special_bonus_")`  |                                                                                                                           |
| `XHelpers.XAbility:RIsUltimate(ability)`                                       |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RLinearProjectileDestroyesOnHit(ability, arg2, arg3)`       |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RNormalizeName(ability)`                                    | `"item_tango"`                                       |                                                                                                                           |
| `XHelpers.XAbility.RParseSpecials(...)`                                        |                                                      | 2 functions share this name; arguments vary                                                                               |
| `XHelpers.XAbility:RPiercesBKB(ability, arg2, arg3, arg4)`                     |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RSpellBlockTriggerRequiresImpact(ability)`                  | `false`                                              |                                                                                                                           |
| `XHelpers.XAbility:RSpellReflectTriggerRequiresImpact(ability)`                | `false`                                              |                                                                                                                           |
| `XHelpers.XAbility:RTriggersPlanarPocket(ability, arg2)`                       |                                                      |                                                                                                                           |
| `XHelpers.XAbility:RTriggersSpellBlock(ability, arg2)`                         | `true`                                               |                                                                                                                           |
| `XHelpers.XAbility:RTriggersSpellReflect(ability, arg2)`                       | `true`                                               |                                                                                                                           |
| `XHelpers.XAbility:RTrueSightAffectsWards(ability, arg2, arg3)`                |                                                      |                                                                                                                           |
| `XHelpers.XAbility.TargetTeamToTeamType(ability)`                              | `self.Enum.TeamType.TEAM_BOTH`                       |                                                                                                                           |
| `XHelpers.XAbility.TargetTypeFlagsToUnitTypeFlags(ability, arg2)`              |                                                      |                                                                                                                           |
| `XHelpers.XAbility:TriggersPlanarPocket(ability)`                              |                                                      | Ability.GetName                                                                                                           |
| `XHelpers.XAbility:TriggersSpellBlock(ability)`                                | `false`                                              | Ability.GetAltCastState, Ability.GetName                                                                                  |
| `XHelpers.XAbility:TriggersSpellReflect(ability)`                              | `false`                                              | Ability.GetAltCastState, Ability.GetName                                                                                  |
| `XHelpers.XAbility:TrueSightAffectsWards(ability, arg2)`                       |                                                      |                                                                                                                           |

#### `XHelpers.XEntity`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XEntity:IsAlive(entity)` |  | Entity.IsAlive, Entity.IsPlayer, Entity.RecursiveGetOwner |
| `XHelpers.XEntity:IsBountyRuneSpawner(entity)` | `Entity.GetClassName(entity) == "C_DOTA_Item_RuneSpawner_Bounty"` | Entity.GetClassName |
| `XHelpers.XEntity:IsMapTree(entity)` | `self.Entity.IsMapTree(entity)` | log |
| `XHelpers.XEntity:IsPowerupRuneSpawner(entity)` | `Entity.GetClassName(entity) == "C_DOTA_Item_RuneSpawner_Powerup"` | Entity.GetClassName |
| `XHelpers.XEntity:IsRuneSpawner(entity)` | `self:IsBountyRuneSpawner(entity) or self:IsPowerupRuneSpawner(entity)` |  |
| `XHelpers.XEntity:IsShop(entity)` | `Entity.GetClassName(entity) == "ent_dota_shop"` | Entity.GetClassName |
| `XHelpers.XEntity:IsTempTree(entity)` | `self.Entity.IsTempTree(entity)` | log |
| `XHelpers.XEntity:IsTree(entity)` | `self.Entity.IsTree(entity)` | log |

#### `XHelpers.XGridNav`

Data: `CellFlag`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XGridNav:BuildPathForNPC(arg1, arg2, arg3, arg4, arg5)` |  | Entity.GetOrigin, Entity.GetRotation, Entity.IsEntity, GridNav.CreateNpcMap, GridNav.ReleaseNpcMap, NPC.GetMoveSpeed ... |
| `XHelpers.XGridNav:BuildPathFromStart(arg1, arg2, arg3, arg4)` |  | GridNav.BuildPath |
| `XHelpers.XGridNav:BuildPathWithStripped(arg1, arg2, arg3, arg4, arg5, arg6)` |  | GridNav.BuildPath |
| `XHelpers.XGridNav:CutPath(arg1, arg2)` | `arg1, {}` | table.CopyShallow, table.IsEmpty |
| `XHelpers.XGridNav:CutPathAtTravelTime(arg1, arg2, arg3, arg4, arg5)` | `arg1, {}` | table.CopyShallow |
| `XHelpers.XGridNav:DebugNPCPath(arg1, arg2)` |  | Color, Entity.GetRotation, GridNav.CreateNpcMap, GridNav.ReleaseNpcMap, NPC.GetMoveSpeed, NPC.GetTurnRate ... |
| `XHelpers.XGridNav:DebugPath(arg1, arg2)` |  | Color, Render.Line, Render.Text, Render.WorldToScreen, Vec2, tostring |
| `XHelpers.XGridNav:GetTravelTime(arg1, arg2, arg3, arg4)` | `self.math.huge` |  |
| `XHelpers.XGridNav:GetTravelTimes(...)` | `{}, {}` | Vector |
| `XHelpers.XGridNav:GetTraversableSpace(arg1, arg2, arg3, arg4, arg5)` | `arg1` | GridNav.IsTraversable, Vector |
| `XHelpers.XGridNav:IsTraversable(arg1, arg2, arg3)` |  | GridNav.IsTraversable, Vector |

#### `XHelpers.XHTTP`

Data: `APIs`, `headers`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XHTTP:GetAPIUrl(arg1)` | `""` |  |
| `XHelpers.XHTTP.Init(...)` |  | 4 functions share this name; arguments vary |
| `XHelpers.XHTTP:Request(arg1, arg2, arg3, arg4, arg5)` | `HTTP.Request(arg1, arg2, arg3, arg4, arg5)` | HTTP.Request |
| `XHelpers.XHTTP:RequestAPI(arg1, arg2, arg3, arg4, arg5, arg6)` | `(internal)(arg1, arg2, arg3, arg4, arg5, arg6)` |  |
| `XHelpers.XHTTP:RequestSingleton(arg1, arg2, arg3, arg4, arg5, arg6)` |  |  |

#### `XHelpers.XHero`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XHero:GetAllPlayers()` |  | Player.GetAssignedHero, Players.GetAll |
| `XHelpers.XHero:GetAllPlayersHeroNames()` |  | Engine.GetHeroNameByID, Player.GetTeamData, Players.GetAll |
| `XHelpers.XHero:GetDormantPosition(hero)` | `Entity.GetOrigin(hero)` | Entity.GetOrigin, Entity.IsHero, Hero.GetLastMaphackPos, NPC.IsVisible |
| `XHelpers.XHero:GetDormantTime(hero)` | `nil` | GameRules.GetGameTime |
| `XHelpers.XHero:GetLocalHeroAbilitiesByName(...)` |  | Ability.GetName, Entity.IsAbility, Entity.IsHero, NPC.GetAbility, NPC.GetAbilityByIndex, table.IsEmpty |
| `XHelpers.XHero:GetPossibleAdditionalAbilities(hero, arg2, arg3)` |  | Engine.GetHeroNameByID, Entity.GetTeamNum, Player.GetTeamData, Players.GetAll |
| `XHelpers.XHero:GetPossibleMorphlingSpells(hero, arg2)` |  | Entity.GetTeamNum, Player.GetTeamData |
| `XHelpers.XHero:GetPossibleRubickSpells(hero, arg2)` |  | Entity.GetTeamNum, Player.GetTeamData |
| `XHelpers.XHero.InCone(...)` |  | 2 functions share this name; arguments vary |
| `XHelpers.XHero.InCones(...)` |  | 2 functions share this name; arguments vary |
| `XHelpers.XHero.InRadius(...)` |  | 3 functions share this name; arguments vary |
| `XHelpers.XHero.InRadiuses(...)` |  | 2 functions share this name; arguments vary |
| `XHelpers.XHero:InSquare(hero, arg2, arg3, arg4, arg5, arg6, arg7)` |  | Entity.GetOrigin, Heroes.GetAll, NPC.IsVisible |
| `XHelpers.XHero.IsInRadius(...)` |  | 2 functions share this name; arguments vary |
| `XHelpers.XHero.IsInRadiuses(...)` |  | 2 functions share this name; arguments vary |
| `XHelpers.XHero:_DormantHeroFilter(hero, arg2, arg3, arg4)` |  | Entity.GetTeamNum, NPC.IsIllusion, NPC.IsVisible |

#### `XHelpers.XInput`

Data: `HotkeyMode`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XInput.ButtonCodeFromKeybind(arg1)` | `(internal)[arg1]` |  |
| `XHelpers.XInput:GetInventoryKeybind(arg1)` | `(internal)[arg1]` | KV.KeysPersonal |
| `XHelpers.XInput:GetInventoryQuickcastKeybind(arg1)` |  | KV.KeysPersonal |
| `XHelpers.XInput:GetItemQuickcastMode(arg1, arg2)` | `arg2` | KV.KeysPersonal |
| `XHelpers.XInput:GetQuickcastMode()` | `self.HotkeyMode.Quickcast` |  |
| `XHelpers.XInput:IsAltDown()` |  | Input.IsKeyDown |
| `XHelpers.XInput:IsDirectQuickcastEnabled()` |  |  |
| `XHelpers.XInput:IsShiftDown()` |  | Input.IsKeyDown |
| `XHelpers.XInput.KeybindFromButtonCode(arg1)` | `(internal)[arg1]` |  |

#### `XHelpers.XItem`

Data: `InventorySearch`, `ItemSlot`, `categories`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XItem:GetKeybinds(item)` | `{}` | Ability.GetName |
| `XHelpers.XItem:GetSlotCached(item, arg2)` | `nil` | Ability.GetOwner |
| `XHelpers.XItem.Init(...)` |  | 4 functions share this name; arguments vary |
| `XHelpers.XItem:RGetCost(item)` |  |  |
| `XHelpers.XItem:RGetItemCategory(item)` |  |  |
| `XHelpers.XItem:RGetMainItemInRecipe(item, arg2)` | `nil` |  |
| `XHelpers.XItem:RGetNeutralItemTier(item)` |  |  |
| `XHelpers.XItem:RHasAnyItemInRecipe(item, ...)` |  |  |
| `XHelpers.XItem:RHasAnyItemInRecipeRecursive(item, ...)` |  |  |
| `XHelpers.XItem:RIsBasics(item)` | `false` |  |
| `XHelpers.XItem:RIsNeutralEnhancement(item)` |  |  |
| `XHelpers.XItem:RIsNeutralItem(item)` |  |  |
| `XHelpers.XItem:RIsRecipe(item)` |  |  |
| `XHelpers.XItem:RIsSecretShop(item)` |  |  |
| `XHelpers.XItem:RIsUpgrades(item)` | `false` |  |
| `XHelpers.XItem.SortedByCategory(item)` |  |  |

#### `XHelpers.XLazyTable`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XLazyTable.new(...)` |  | 2 functions share this name; arguments vary |
| `XHelpers.XLazyTable.set(...)` |  | 2 functions share this name; arguments vary |

#### `XHelpers.XLocalizer`

Data: `__abilities_owners`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XLocalizer:CallLocaledFunction(arg1, arg2, arg3, ...)` | `arg3(...)` |  |
| `XHelpers.XLocalizer:GameLanguageToLanguage(arg1)` | `(internal)[arg1]` | Steam.GetGameLanguage |
| `XHelpers.XLocalizer:GetLanguage()` |  | Menu.Find |
| `XHelpers.XLocalizer:GetPluralForm(arg1, arg2, arg3)` | `arg2[1]` |  |
| `XHelpers.XLocalizer.Init(...)` |  | 4 functions share this name; arguments vary |
| `XHelpers.XLocalizer:LanguageToISO639(arg1)` | `(internal)[arg1]` |  |
| `XHelpers.XLocalizer:LocalizeAbilityName(arg1)` |  | GameLocalizer.FindAbility, GameLocalizer.FindItem |
| `XHelpers.XLocalizer:LocalizeAbilityNameWithOwner(arg1, arg2)` |  |  |
| `XHelpers.XLocalizer:LocalizeAttribute(arg1)` |  | GameLocalizer.Find, table.Find |
| `XHelpers.XLocalizer:LocalizeTeamID(arg1, arg2)` | `(internal)[arg1]` |  |

#### `XHelpers.XMiniMap`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XMiniMap:GetExtraLargeMinimapValue()` | `self.ConvarManager:get_int("dota_hud_extra_large_minimap", 0)` |  |
| `XHelpers.XMiniMap:GetVanillaMinimapHeight(arg1)` | `244` |  |

#### `XHelpers.XModifier`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XModifier:GetDispellableType(modifier)` |  | Ability.GetDispellableType, Ability.GetLevelSpecialValueFor, Ability.GetName, Ability.GetOwner, Modifier.GetAbility, Modifier.GetCaster ... |
| `XHelpers.XModifier:GetElapsedTime(modifier, arg2)` |  | GameRules.GetGameTime, Modifier.GetCreationTime, Modifier.GetLastAppliedTime |
| `XHelpers.XModifier:GetRemainingTime(modifier)` | `-1` | Ability.GetLevelSpecialValueFor, Entity.IsPlayer, Entity.RecursiveGetOwner, GameRules.GetGameTime, Hero.GetReplicatingOtherHeroModel, Modifier.GetAbility ... |
| `XHelpers.XModifier:IsDispellable(modifier, arg2, arg3)` | `false` | GameRules.GetGameTime, Modifier.GetDieTime, Modifier.GetProvidedByAura, Modifier.IsCurrentlyInAuraRange, Modifier.IsDebuff |
| `XHelpers.XModifier:IsInterruptsOrderQueue(modifier)` | `true` | Modifier.GetName, Modifier.GetState |
| `XHelpers.XModifier:IsSentryWard(modifier)` | `true` | Ability.GetName, Entity.GetClassName, Modifier.GetAbility, Modifier.GetCaster, Modifier.GetName |
| `XHelpers.XModifier:RGetDispellableType(modifier, arg2)` |  | Ability.GetDispellableType, Ability.GetLevelSpecialValueFor, Ability.GetName, Ability.GetOwner, NPC.HasScepter, NPC.HasShard |

#### `XHelpers.XNPC`

Data: `ATTACK_RANGE_BUFFER`, `AttackCapability`, `HullSize`, `MaxHullSize`, `MovementCapability`, `NEUTRALS_ATTACK_ACQUISITION_RANGE_OVERRIDE`, `UF_RESULT`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XNPC:AutoAttacksByDefault(npc)` | `self:RAutoAttacksByDefault(NPC.GetUnitName(npc))` | NPC.GetUnitName |
| `XHelpers.XNPC:BuildPathsToPosition(npc, arg2, arg3, arg4, arg5)` |  | Angle, Entity.GetOrigin, GridNav.BuildPath, GridNav.CreateNpcMap, GridNav.ReleaseNpcMap, table.IsEmpty |
| `XHelpers.XNPC:CanHeal(npc, arg2, arg3)` |  | CustomEntities.GetTetheredUnit, Entity.GetHealth, Entity.GetMaxHealth, NPC.GetAbility, NPC.GetMana, NPC.GetMaxMana |
| `XHelpers.XNPC:CanPathThroughTrees(npc)` |  | NPC.HasState |
| `XHelpers.XNPC:DispelsBuffs(npc, arg2, arg3, arg4)` | `true` | Ability.GetName, Entity.GetTeamNum, Modifier.GetTeam, NPC.GetModifier, NPC.GetStatesDuration, TargetProjectiles.GetAll |
| `XHelpers.XNPC:DispelsDebuffs(npc, arg2, arg3, arg4)` | `true` | Ability.GetLevelSpecialValueFor, Ability.GetName, Entity.GetTeamNum, Modifier.GetAbility, Modifier.GetTeam, NPC.GetModifier ... |
| `XHelpers.XNPC:GetAbilitiesByName(npc, ...)` |  | Ability.GetName, NPC.GetAbility, NPC.GetAbilityByIndex, NPC.GetUnitName |
| `XHelpers.XNPC:GetAttackAcquisitionRange(npc)` | `Entity.GetField(npc, "m_iAcquisitionRange", false) or 0` | Entity.GetField |
| `XHelpers.XNPC:GetAttackBackswingTime(npc)` | `self:RGetAttackBackswingTime(NPC.GetUnitName(npc))` | NPC.GetUnitName |
| `XHelpers.XNPC:GetAttackCapability(npc)` | `Entity.GetField(npc, "m_iAttackCapabilities", false)` | Entity.GetField |
| `XHelpers.XNPC:GetAutoAttackTarget(npc, arg2)` |  | Entity.GetOrigin, Entity.GetTeamNum, NPC.GetHullRadius |
| `XHelpers.XNPC:GetChannellingAbilityOrItem(npc)` | `NPC.GetChannellingAbility(npc) or self:GetChannellingItem(npc)` | NPC.GetChannellingAbility |
| `XHelpers.XNPC:GetChannellingItem(npc)` |  | Ability.IsChannelling, NPC.GetItemByIndex |
| `XHelpers.XNPC:GetCurrentVisionRange(npc)` | `self:GetNightTimeVisionRange(npc)` |  |
| `XHelpers.XNPC:GetDayTimeVisionRange(npc)` |  | NPC.GetDayTimeVisionRange, NPC.GetModifierPropertyHighest |
| `XHelpers.XNPC:GetDebuffDurationAmplification(npc)` | `0` | NPC.GetModifierProperty |
| `XHelpers.XNPC:GetDebuffDurationMultiplier(npc, arg2, arg3, arg4)` |  |  |
| `XHelpers.XNPC:GetDebuffImmunityCooldown(npc, arg2)` | `0` | Ability.GetCooldown, Ability.GetLevelSpecialValueFor, NPC.GetAbility, NPC.GetItem, NPC.HasScepter, NPC.HasShard |
| `XHelpers.XNPC:GetFlyDuration(npc)` |  | NPC.GetStatesDuration, table.Values |
| `XHelpers.XNPC:GetHealthbarPositionCorrection(npc)` |  | Entity.GetClassName, Entity.GetTeamNum, NPC.GetUnitType, NPC.IsConsideredHero, NPC.IsCreep, NPC.IsHero ... |
| `XHelpers.XNPC:GetHealthbarScreenData(npc)` |  | NPC.GetBarriers, Vec2 |
| `XHelpers.XNPC:GetHealthbarSize(npc)` |  | Entity.GetClassName, Entity.GetTeamNum, NPC.GetUnitType, NPC.IsConsideredHero, NPC.IsCreep, NPC.IsHero |
| `XHelpers.XNPC.GetHullCollisionSize(npc)` | `4` |  |
| `XHelpers.XNPC:GetInvisibilityDuration(npc)` |  | NPC.GetStatesDuration |
| `XHelpers.XNPC:GetLearnedTalents(npc, arg2)` |  | Hero.TalentIsLearned, NPC.GetUnitName |
| `XHelpers.XNPC:GetLifeTime(npc)` |  |  |
| `XHelpers.XNPC:GetLifeTimeModifier(npc)` |  | NPC.GetModifier |
| `XHelpers.XNPC:GetMovementCapability(npc)` | `Entity.GetField(npc, "m_iMoveCapabilities", false)` | Entity.GetField |
| `XHelpers.XNPC:GetNightTimeVisionRange(npc)` |  | NPC.GetModifierPropertyHighest, NPC.GetNightTimeVisionRange |
| `XHelpers.XNPC:GetNothlProjection(npc)` |  | Hero.GetReplicatingOtherHeroModel, Heroes.GetAll |
| `XHelpers.XNPC:GetOrigin(npc)` |  | Entity.GetOrigin |
| `XHelpers.XNPC:GetSoulbindPartner(npc)` | `nil` | Ability.GetLevelSpecialValueFor, Entity.GetOrigin, Heroes.InRadius, Modifier.GetAbility, Modifier.GetDieTime, Modifier.GetField ... |
| `XHelpers.XNPC:GetSpellBlockCooldown(npc, arg2)` |  | Ability.GetCooldown, NPC.GetAbility, NPC.GetItem, NPC.IsLinkensProtected, NPC.IsMirrorProtected |
| `XHelpers.XNPC:GetSpellBlockCount(npc)` |  | Ability.GetCooldown, NPC.GetAbility, NPC.GetItem, NPC.HasModifier |
| `XHelpers.XNPC:GetSpellBlockDuration(npc)` | `-1` | NPC.GetModifier, NPC.IsLinkensProtected, NPC.IsMirrorProtected |
| `XHelpers.XNPC:GetSpellReflectCooldown(npc, arg2)` | `0` | Ability.GetCooldown, NPC.GetAbility, NPC.GetItem |
| `XHelpers.XNPC:GetSpellReflectDuration(npc)` |  | NPC.GetModifier |
| `XHelpers.XNPC:GetStatusResistance(npc, arg2, arg3)` | `0` | DrunkenBrawler.GetState, Hero.GetStrengthTotal, Modifier.GetAbility, Modifier.GetField, NPC.GetModifier, NPC.GetModifierProperty ... |
| `XHelpers.XNPC:GetTurnTime(npc, arg2, arg3)` | `self.RGetTurnTime(NPC.GetTurnRate(npc), arg2, arg3)` | NPC.GetTurnRate |
| `XHelpers.XNPC.GetUFResultErrorMessage(npc)` | `GameLocalizer.Find("#dota_hud_error_cant_cast_on_ally")` | GameLocalizer.Find, Localizer.Get |
| `XHelpers.XNPC:GetUnitType(npc)` | `self.Enum.UnitTypeFlags.TYPE_HERO` | Entity.IsNPC, NPC.IsBarracks, NPC.IsConsideredHero, NPC.IsCourier, NPC.IsCreep, NPC.IsHero ... |
| `XHelpers.XNPC:HasFlying(npc)` |  | NPC.HasState |
| `XHelpers.XNPC:HasTalent(npc, arg2)` |  | Ability.GetLevel, NPC.GetAbility |
| `XHelpers.XNPC.InCone(...)` |  | 2 functions share this name; arguments vary |
| `XHelpers.XNPC:InCones(npc, arg2, arg3, arg4, arg5, arg6, arg7)` | `{}` | Entity.GetOrigin, Heroes.GetAll, NPC.GetHullRadius, NPC.IsVisible, NPCs.GetAll, NPCs.InRadius ... |
| `XHelpers.XNPC.InRadius(...)` |  | 3 functions share this name; arguments vary |
| `XHelpers.XNPC:InRadiuses(npc, arg2, arg3, arg4, arg5, arg6, arg7, arg8)` | `{}` | Entity.GetOrigin, Heroes.GetAll, NPC.GetHullRadius, NPC.IsVisible, NPCs.GetAll, NPCs.InRadius |
| `XHelpers.XNPC:InSquare(npc, arg2, arg3, arg4, arg5, arg6, arg7)` |  | Entity.GetOrigin, Heroes.GetAll, NPC.IsVisible |
| `XHelpers.XNPC:IsAbsorbsSpells(npc)` | `NPC.HasModifier(npc, "modifier_antimage_counterspell")` | NPC.HasModifier |
| `XHelpers.XNPC:IsAncestralSpirit(npc)` | `Entity.GetClassName(npc) == "CDOTA_Unit_Elder_Titan_AncestralSpirit"` | Entity.GetClassName |
| `XHelpers.XNPC:IsAttackImmune(npc)` |  | NPC.HasState |
| `XHelpers.XNPC:IsAutoAttackable(npc)` | `false` | NPC.IsWaitingToSpawn |
| `XHelpers.XNPC:IsChannellingAbilityOrItem(npc)` | `NPC.IsChannellingAbility(npc) or self:GetChannellingItem(npc) ~= nil` | NPC.IsChannellingAbility |
| `XHelpers.XNPC:IsChannellingItem(npc)` |  |  |
| `XHelpers.XNPC:IsCommandAuraIllusion(npc)` | `NPC.HasModifier(npc, "modifier_vengefulspirit_command_aura_illusion")` | NPC.HasModifier |
| `XHelpers.XNPC:IsCrystalClone(npc)` | `NPC.HasModifier(npc, "modifier_crystal_maiden_crystal_clone_statue")` | NPC.HasModifier |
| `XHelpers.XNPC:IsDebuffImmune(npc)` |  | NPC.HasState |
| `XHelpers.XNPC:IsDisabled(npc)` | `NPC.IsStunned(npc)` | NPC.IsStunned |
| `XHelpers.XNPC:IsDisarmed(npc)` | `NPC.HasState(npc, self.Enum.ModifierState.MODIFIER_STATE_DISARMED)` | NPC.HasState |
| `XHelpers.XNPC:IsDominated(npc)` | `NPC.HasModifier(npc, "modifier_dominated")` | NPC.HasModifier |
| `XHelpers.XNPC:IsDominatedCreepHero(npc)` | `NPC.HasAnyModifier(npc, (internal))` | NPC.HasAnyModifier |
| `XHelpers.XNPC:IsFamiliar(npc)` | `Entity.GetClassName(npc) == "C_DOTA_Unit_VisageFamiliar"` | Entity.GetClassName |
| `XHelpers.XNPC:IsFeared(npc)` | `NPC.HasState(npc, self.Enum.ModifierState.MODIFIER_STATE_FEARED)` | NPC.HasState |
| `XHelpers.XNPC:IsFort(npc)` | `Entity.GetClassName(npc) == "C_DOTA_BaseNPC_Fort"` | Entity.GetClassName |
| `XHelpers.XNPC:IsHealingDisabled(npc)` |  | NPC.GetModifierPropertyHighest |
| `XHelpers.XNPC:IsHexed(npc)` | `NPC.HasState(npc, self.Enum.ModifierState.MODIFIER_STATE_HEXED)` | NPC.HasState |
| `XHelpers.XNPC:IsIdle(npc)` | `true` | NPC.GetAnimationInfo |
| `XHelpers.XNPC.IsInRadius(...)` |  | 2 functions share this name; arguments vary |
| `XHelpers.XNPC:IsInRadiuses(npc, arg2, arg3, arg4, arg5, arg6, arg7)` | `false` | Entity.GetOrigin, Heroes.GetAll, NPC.GetHullRadius, NPCs.GetAll, NPCs.InRadius |
| `XHelpers.XNPC:IsInfested(npc)` | `NPC.HasModifier(npc, "modifier_life_stealer_infest_effect")` | NPC.HasModifier |
| `XHelpers.XNPC:IsInvisible(npc)` | `NPC.HasState(npc, self.Enum.ModifierState.MODIFIER_STATE_INVISIBLE)` | NPC.HasState |
| `XHelpers.XNPC:IsLycanWolf(npc)` | `self.string.startswith(NPC.GetUnitName(npc), "npc_dota_lycan_wolf")` | NPC.GetUnitName |
| `XHelpers.XNPC:IsManaGainDisabled(npc)` | `NPC.HasModifier(npc, "modifier_antimage_empowered_mana_break_debuff")` | NPC.HasModifier |
| `XHelpers.XNPC:IsMonkeyClone(npc)` | `NPC.HasModifier(npc, "modifier_monkey_king_fur_army_soldier")` | NPC.HasModifier |
| `XHelpers.XNPC:IsMorphlingReplicateIllusion(npc)` |  | NPC.HasModifier |
| `XHelpers.XNPC:IsMuted(npc)` | `NPC.HasState(npc, self.Enum.ModifierState.MODIFIER_STATE_MUTED)` | NPC.HasState |
| `XHelpers.XNPC:IsNightmared(npc)` | `NPC.HasState(npc, self.Enum.ModifierState.MODIFIER_STATE_NIGHTMARED)` | NPC.HasState |
| `XHelpers.XNPC:IsNothlProjection(npc)` | `NPC.HasModifier(npc, "modifier_dazzle_nothl_projection_soul_debuff")` | NPC.HasModifier |
| `XHelpers.XNPC:IsOutpost(npc)` | `Entity.GetClassName(npc) == "C_DOTA_BaseNPC_Watch_Tower"` | Entity.GetClassName |
| `XHelpers.XNPC:IsPsionicTrap(npc)` | `Entity.GetClassName(npc) == "C_DOTA_Unit_TemplarAssassin_PsionicTrap"` | Entity.GetClassName |
| `XHelpers.XNPC:IsReflectsSpells(npc)` | `NPC.IsMirrorProtected(npc) or NPC.HasAnyModifier(npc, (internal))` | NPC.HasAnyModifier, NPC.IsMirrorProtected |
| `XHelpers.XNPC:IsRooted(npc)` | `NPC.HasState(npc, self.Enum.ModifierState.MODIFIER_STATE_ROOTED)` | NPC.HasState |
| `XHelpers.XNPC:IsScan(npc)` | `NPC.HasModifier(npc, "modifier_radar_thinker")` | NPC.HasModifier |
| `XHelpers.XNPC:IsSpellImmune(npc)` |  | NPC.HasState |
| `XHelpers.XNPC:IsSpiritBear(npc)` | `Entity.GetClassName(npc) == "C_DOTA_Unit_SpiritBear"` | Entity.GetClassName |
| `XHelpers.XNPC:IsSummoned(npc)` |  | NPC.GetUnitName, NPC.IsIllusion, NPC.IsNeutral |
| `XHelpers.XNPC:IsTaunted(npc)` | `NPC.HasState(npc, self.Enum.ModifierState.MODIFIER_STATE_TAUNTED)` | NPC.HasState |
| `XHelpers.XNPC:IsThinker(npc)` | `NPC.GetUnitName(npc) == "npc_dota_thinker"` | NPC.GetUnitName |
| `XHelpers.XNPC:IsTrueHero(npc)` |  | Entity.IsNPC, NPC.IsHero, NPC.IsIllusion |
| `XHelpers.XNPC:IsTrueSight(npc, arg2)` | `false` | NPC.HasAnyModifier |
| `XHelpers.XNPC:IsTrueSightImmune(npc)` |  | NPC.HasAnyModifier, NPC.HasState |
| `XHelpers.XNPC:IsWarlockGolem(npc)` | `Entity.GetClassName(npc) == "C_DOTA_BaseNPC_Warlock_Golem"` | Entity.GetClassName |
| `XHelpers.XNPC:IsWraith(npc)` |  | NPC.HasModifier |
| `XHelpers.XNPC:RAutoAttacksByDefault(npc)` |  |  |
| `XHelpers.XNPC:RGetAttackBackswingTime(npc)` | `(internal)[npc] or 0.3` |  |
| `XHelpers.XNPC:RGetAttackCapability(npc)` |  |  |
| `XHelpers.XNPC:RGetAutoAttackTarget(npc, arg2, arg3, arg4, arg5)` |  | Entity.GetOrigin, NPC.IsNeutral, NPCs.InRadius |
| `XHelpers.XNPC:RGetMovementCapability(npc)` |  |  |
| `XHelpers.XNPC.RGetTurnTime(npc, arg2, arg3)` |  |  |
| `XHelpers.XNPC:RIsHero(npc)` | `self.string.startswith(npc, "npc_dota_hero_")` |  |
| `XHelpers.XNPC:UnitFilter(npc, arg2, arg3, arg4, arg5)` | `self.UF_RESULT.ENEMY` | Entity.GetTeamNum, NPC.GetMaxMana, NPC.HasState, NPC.IsAncient, NPC.IsBarracks, NPC.IsConsideredHero ... |
| `XHelpers.XNPC:UnitTypeFlagsFilter(npc, arg2)` | `self.UF_RESULT.SUCCESS` | NPC.IsAncient, NPC.IsBarracks, NPC.IsConsideredHero, NPC.IsCourier, NPC.IsCreep, NPC.IsHero ... |
| `XHelpers.XNPC.UnitTypeFlagsToUFResult(npc)` | `self.UF_RESULT.CUSTOM` |  |

#### `XHelpers.XNeutralCamps`

Data: `AggroDistance`, `CampType`, `DamageAggroDistance`, `FirstNeutralSpawn`, `GuardDistance`, `GuardLossAggroDelay`, `PullType`, `RoshanAggroDistance`, `camp_pull_types`, `pull_type_to_max_distance`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XNeutralCamps:DoesAggro(camp)` |  | GameRules.GetTimeOfDay |
| `XHelpers.XNeutralCamps:GetCampPullMaxDistance(camp)` | `-1` |  |
| `XHelpers.XNeutralCamps:GetCampPullType(camp)` |  | tostring |
| `XHelpers.XNeutralCamps:GetDotaPlusTimerPositionInfo()` | `{` | Vec2 |
| `XHelpers.XNeutralCamps:GetNeutralsMovespeed(camp)` |  | Ability.GetLevelSpecialValueFor, NPC.GetAbility, NPC.GetMoveSpeed, NPC.IsVisible |
| `XHelpers.XNeutralCamps.GetPullTypeMaxDistance(camp)` | `self.pull_type_to_max_distance[camp]` |  |

#### `XHelpers.XOrderQueue`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XOrderQueue:GetAllQueues()` | `table.Copy((internal))` | table.Copy |
| `XHelpers.XOrderQueue:GetQueue(arg1)` |  | table.CopyShallow |
| `XHelpers.XOrderQueue:HandleOrder(arg1)` |  | Ability.GetAltCastState, Ability.GetAutoCastState, Ability.GetToggleState, Entity.GetOrigin, Entity.IsAbility, Entity.IsEntity ... |
| `XHelpers.XOrderQueue:IsNPCRegistered(arg1)` | `(internal)[arg1] ~= nil` |  |
| `XHelpers.XOrderQueue:RegisterNPC(arg1)` |  |  |
| `XHelpers.XOrderQueue:UnregisterNPC(arg1, arg2)` |  | table.IsEmpty |

#### `XHelpers.XPanorama`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XPanorama:EmitSound(arg1)` | `self.Panorama.RunScriptF((internal), nil, arg1)` |  |
| `XHelpers.XPanorama:GetPanelsByPath(arg1, arg2)` | `{ Panorama.GetPanelByPath(arg1, arg2) }` | Panorama.GetPanelByPath, table.Map |

#### `XHelpers.XPlayer`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XPlayer:CancelActiveAbility()` | `Engine.ExecuteCommand("-dota_ability_execute")` | Engine.ExecuteCommand |
| `XHelpers.XPlayer:GetInputCompensationTime()` | `(internal) - 0.033` |  |
| `XHelpers.XPlayer:GetInputDelay()` | `(internal)` |  |
| `XHelpers.XPlayer:GetInvisibleDelay()` | `(internal), (internal)` |  |
| `XHelpers.XPlayer:GetOrderNPCs(player, arg2)` |  | Ability.GetOwner, Entity.IsAbility, Heroes.GetLocal, Player.GetAssignedHero, Player.GetSelectedUnits, Players.GetLocal |
| `XHelpers.XPlayer:GetRespawnTime(player)` | `Player.GetTeamData(player).respawnTime` | Player.GetTeamData |
| `XHelpers.XPlayer:GetSteamID(player)` | `Player.GetPlayerData(player, (internal)).steamid` | Player.GetPlayerData |
| `XHelpers.XPlayer:IsImmediateOrder(player)` | `true` | Ability.GetBehavior, Entity.IsAbility |
| `XHelpers.XPlayer:IsOrderIgnoresQueue(player)` | `false` |  |
| `XHelpers.XPlayer:IsPlayerOrder(player)` |  |  |
| `XHelpers.XPlayer:MutePlayerFor(player, arg2)` | `false` | Player.IsMuted |
| `XHelpers.XPlayer:SendReport(player, arg2, arg3, arg4)` | `false` | GC.SendMessage, table.CopyShallow, table.IsEmpty, table.RemoveElement |
| `XHelpers.XPlayer:SetMuted(player, arg2)` |  | Panorama.GetPanelByPath |

#### `XHelpers.XRender`

Data: `fonts`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XRender:CircleInWorld(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10)` |  |  |
| `XHelpers.XRender:DrawAlert(arg1, arg2, arg3, arg4)` |  | Particle.Create, Particle.Destroy, Particle.SetControlPoint, Vector |
| `XHelpers.XRender:DrawFakeOrder(arg1, arg2, arg3, arg4)` | `self:DrawFakeOrder(arg1.order, arg1.target, arg1.position, arg1.queue)` | Entity.GetOrigin, Entity.GetTeamNum, Entity.IsHero, Entity.IsNPC, Particle.Create, Particle.SetControlPoint ... |
| `XHelpers.XRender:DrawSquareAlert(arg1, arg2, arg3, arg4, arg5)` |  | Angle, Particle.Create, Particle.Destroy, Particle.SetControlPoint, Particle.SetParticleControlTransform, Vector |
| `XHelpers.XRender:GetAttributeIconPath(arg1)` | `"panorama/images/primary_attribute_icons/primary_attribute_icon_"` | table.Find |
| `XHelpers.XRender:GetNPCIconPath(arg1)` | `self.LIB_RENDER.get_hero_icon_path(arg1)` |  |
| `XHelpers.XRender:GridSpritesheetUV(arg1, arg2, arg3, arg4)` |  |  |
| `XHelpers.XRender:PagedGridSpritesheetUV(arg1, arg2, arg3, arg4)` |  |  |
| `XHelpers.XRender:PingLocal(arg1, arg2, arg3, arg4)` |  | Engine.PlayVol, Particle.Create, Particle.SetControlPoint, Vector |

#### `XHelpers.XTree`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XTree:GetAll()` | `Trees.GetAll() + TempTrees.GetAll()` | TempTrees.GetAll, Trees.GetAll |
| `XHelpers.XTree.InRadius(...)` |  | 3 functions share this name; arguments vary |

#### `XHelpers.XVectorTargetManager`

Data: `DEFAULT_MAX_LENGTH`, `__vector_targets`, `__vector_targets_auto_cache`, `__vector_targets_auto_cancellable_cache`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.XVectorTargetManager:XVectorTarget(arg1, arg2)` | `(internal)(arg1, arg2)` |  |

#### `XHelpers.cachetools`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.cachetools:lru(arg1)` | `self.new(arg1)` |  |

#### `XHelpers.protobuf`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.protobuf.decodeToJSON(...)` |  |  |
| `XHelpers.protobuf.decodeToJSONfromObject(...)` |  |  |
| `XHelpers.protobuf.decodeToJSONfromString(...)` |  |  |
| `XHelpers.protobuf.encode(arg1, arg2)` | `self.table.concat((internal)(arg1, {}, {}, arg2))` |  |
| `XHelpers.protobuf.encodeFromJSON(...)` |  |  |
| `XHelpers.protobuf.free(...)` |  |  |

#### `XHelpers.schema_validator`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.schema_validator.validate(arg1, arg2)` |  | tostring |

#### `XHelpers.toml`

Data: `_DESCRIPTION`, `_LICENSE`, `_TOML_VERSION`, `_URL`, `_VERSION`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.toml.encode(arg1, arg2)` | `self.table.concat((internal)(arg1, {}, {}, arg2))` |  |
| `XHelpers.toml.parse(arg1, arg2)` | `{}` | tostring |

#### `XHelpers.xbit`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.xbit.contains(arg1, arg2)` | `false` |  |
| `XHelpers.xbit.contains_all(arg1, ...)` | `false` |  |
| `XHelpers.xbit.contains_any(arg1, ...)` | `true` |  |

#### `XHelpers.xkeyvalues`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.xkeyvalues.Load(...)` |  | 2 functions share this name; arguments vary |

#### `XHelpers.xkv`

Data: `VPK_BASE_URL`, `all_items`, `items`, `items_recipes`, `loaded_kvs`, `neutral_abilities`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.xkv:FacetIDToName(arg1, arg2)` | `nil` |  |
| `XHelpers.xkv:FacetNameToID(arg1, arg2)` | `nil` |  |
| `XHelpers.xkv:GetAbilityKeyValues(arg1)` |  |  |
| `XHelpers.xkv:GetAbilitySpecials(arg1, arg2)` | `{}` |  |
| `XHelpers.xkv:GetHeroAbilityCount(arg1)` | `9` |  |
| `XHelpers.xkv:GetHeroFacetAbilities(arg1, arg2)` |  | tostring |
| `XHelpers.xkv:GetHeroFacetsAbilities(arg1)` |  |  |
| `XHelpers.xkv:GetHeroPrimaryAttribute(arg1)` |  |  |
| `XHelpers.xkv:GetKV(arg1)` |  |  |
| `XHelpers.xkv:GetNeutralAbilities()` |  | GameLocalizer.FindNPC |
| `XHelpers.xkv:GetUnitAbilities(arg1, arg2)` |  | tostring |
| `XHelpers.xkv:GetUnitAbilityCount(arg1, arg2, arg3)` |  | tostring |
| `XHelpers.xkv:GetUnitKV(arg1)` | `{}` |  |
| `XHelpers.xkv:GetUnitTalents(arg1)` | `{}` | tostring |
| `XHelpers.xkv.Init(...)` |  | 4 functions share this name; arguments vary |
| `XHelpers.xkv:LoadKVfromAssetsJSON(arg1)` | `self.loaded_kvs[arg1]` |  |
| `XHelpers.xkv:LoadKVfromVPK(arg1)` |  |  |
| `XHelpers.xkv:RGetSpecialRequirements(arg1, arg2)` | `nil` |  |
| `XHelpers.xkv.RParseSpecials(...)` |  | 2 functions share this name; arguments vary |
| `XHelpers.xkv:RParseSum(arg1, arg2, arg3)` | `0` |  |

#### `XHelpers.xmath`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.xmath.circle_intersection_area(arg1, arg2, arg3, arg4)` | `0` |  |
| `XHelpers.xmath.circle_intersections_area_approximate(arg1, arg2, arg3, ...)` |  | Vec2 |
| `XHelpers.xmath.clamp_direction(arg1, arg2, arg3)` | `arg1:Normalized() * arg2` |  |
| `XHelpers.xmath.distance_with_acceleration(arg1, arg2, arg3, arg4)` | `arg2 * arg1 + 0.5 * arg3 * arg1 ^ 2` |  |
| `XHelpers.xmath.ease_out_progress(arg1, arg2, arg3, arg4)` | `arg2` | GlobalVars.GetAbsFrameTime |
| `XHelpers.xmath.exponential_progress(arg1, arg2, arg3, arg4)` | `arg2` | GlobalVars.GetAbsFrameTime |
| `XHelpers.xmath.fast_hash32(arg1)` | `arg1` |  |
| `XHelpers.xmath.is_vector_between(arg1, arg2, arg3, arg4)` |  |  |
| `XHelpers.xmath.polyline_box_intersection(arg1, arg2, arg3)` |  |  |
| `XHelpers.xmath.random_sign()` | `self.math.random() >= 0.5 and 1 or -1` |  |
| `XHelpers.xmath.random_uniform(arg1, arg2)` | `arg1 + self.math.random() * (arg2 - arg1)` |  |
| `XHelpers.xmath.ray_aabb_slab_intersection_exit(arg1, arg2, arg3, arg4)` |  | Vec2 |

#### `XHelpers.xstring`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.xstring.db_escape(arg1)` | `(arg1:gsub("%.", "_"))` |  |
| `XHelpers.xstring.djb2_hash(arg1)` |  |  |
| `XHelpers.xstring.fill(arg1, arg2, arg3)` | `arg1` |  |
| `XHelpers.xstring.fromhex(arg1)` | `self.string.fromhex(arg1)` | log |
| `XHelpers.xstring.tohex(arg1)` | `self.string.tohex(arg1)` | log |
| `XHelpers.xstring.uuid4()` |  |  |

#### `XHelpers.xtable`

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.xtable.slice(arg1, arg2, arg3)` |  |  |
| `XHelpers.xtable.stringify(arg1, arg2)` | `self.table.concat(arg1, arg2 or "\000")` |  |
| `XHelpers.xtable.to_keys(arg1, arg2)` |  |  |

#### `XHelpers.xutil`

Data: `AdditionalControllableUnitsFlags`, `State`, `additional_units`, `mmr_rank_table`, `month_days`.

| Function | Returns | Calls |
|---|---|---|
| `XHelpers.xutil:CreateAdditionalControllableUnits(arg1, arg2, arg3)` |  |  |
| `XHelpers.xutil:FixFacetID(arg1)` | `arg1 & 4294967295` |  |
| `XHelpers.xutil.GameTimeToDotaTime(...)` |  |  |
| `XHelpers.xutil:GetBase(arg1)` | `nil` | Entity.GetTeamNum |
| `XHelpers.xutil:GetDaysInMonth(arg1, arg2)` | `29` |  |
| `XHelpers.xutil:GetIngameTime(arg1)` | `GameRules.GetGameTime() - GameRules.GetGameStartTime()` | GameRules.GetGameStartTime, GameRules.GetGameState, GameRules.GetGameTime |
| `XHelpers.xutil:GetMMRRank(arg1)` | `0` |  |
| `XHelpers.xutil:GetNextRankMMR(arg1)` | `nil` |  |
| `XHelpers.xutil:GetNotificationsVolume()` | `1.0` | Menu.Find |
| `XHelpers.xutil:GetRankMMR(arg1)` |  |  |
| `XHelpers.xutil:GetState()` | `self.State.Loading` | Engine.IsInGame |
| `XHelpers.xutil:IsDayTime(arg1)` | `true` | GameRules.GetDaytimeStart, GameRules.GetNighttimeStart, GameRules.GetTimeOfDay, GameRules.IsTemporaryDay |
| `XHelpers.xutil:IsInDemoLobby(arg1)` | `(internal)` | Panorama.GetPanelByPath |
| `XHelpers.xutil:IsLeapYear(arg1)` | `arg1 % 4 == 0 and (arg1 % 100 ~= 0 or arg1 % 400 == 0)` |  |
| `XHelpers.xutil:IsNightTime(arg1)` | `false` | GameRules.GetDaytimeStart, GameRules.GetNighttimeStart, GameRules.GetTimeOfDay, GameRules.IsNightstalkerNight, GameRules.IsTemporaryDay, GameRules.IsTemporaryNight |
| `XHelpers.xutil:IsWatchingReplay()` | `false` |  |
| `XHelpers.xutil:OpenUrlInExternalBrowser(arg1)` |  |  |
| `XHelpers.xutil:ParseBarracksStatus(arg1)` | `{` |  |
| `XHelpers.xutil:ParseTowerStatus(arg1)` | `{` |  |
| `XHelpers.xutil:SteamID64ToAccountID(arg1)` | `-1` |  |


#### `XHelpers.XRune`

Data: `bounty_spawn_initial`, `bounty_spawn_interval`, `powerup_spawn_first`, `powerup_spawn_initial`, `powerup_spawn_interval`.

---

## Icons

The 19 FontAwesome glyphs Umbrella's menus use, as strings.

**Availability:** load time and callbacks.

| Key | Glyph | Key | Glyph |
|---|---|---|---|
| `arrows_distance` | U+E4BA | `panel` | U+F37E |
| `arrows_override` | U+F364 | `person_walk` | U+F554 |
| `backpack` | U+F5D4 | `person_walk_back` | U+E551 |
| `battery_half` | U+F242 | `radius` | U+E105 |
| `check` | U+F00C | `shield_check` | U+F2F7 |
| `cliff` | U+F6FD | `shuffle` | U+F074 |
| `cross` | U+F00D | `smile_enemies` | U+E368 |
| `gun_crossed` | U+E19C | `sword` | U+F71C |
| `heart` | U+F004 | `timer` | U+E29E |
| `indicator` | U+F2D0 | | |

They work as menu icons, and as text drawn with the FontAwesome font (`Enum.DefaultFont.FONTAWESOME`).

```lua
local group = Menu.Create("Scripts", "Main", "My Script"):Create("Main"):Create("Settings")
group:Switch("Show radius", true, Icons.radius)

local fa = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS)
function script.OnDraw()
  Render.Text(fa, 18, Icons.timer, Vec2(100, 100), Color(255, 255, 255))
end
```

---

## UnsafeFeaturesEnabled

```lua
UnsafeFeaturesEnabled() -> boolean
```

Whether the user has turned on Umbrella's unsafe features option. `Roshan.unsafe_features_enabled` holds the same value, and the official `Entity.GetRoshanHealth()` only works while it's `true`. Use it to gate any behaviour the user should have to opt into.

```lua
if UnsafeFeaturesEnabled() then
  local roshHp = Entity.GetRoshanHealth()
end
```

---

## AbilitiesSystem

A class holding the ability lists Umbrella's built-in features use to decide how to treat an ability: which ones never to cast automatically, which passives aren't really passive, and which casts belong to another ability. `AbilitiesSystem.__index` is the table itself, so it's used as a class through `new`.

**Availability:** load time and callbacks.

| Function | What it is |
|---|---|
| `AbilitiesSystem.new(...)` | constructor |
| `AbilitiesSystem.update_data(...)` | refreshes an instance's data |
| `AbilitiesSystem.get_function_for_ability(...)` | looks up the handler for an ability |
| `AbilitiesSystem.linked_abilities_handler(...)` | handler for the abilities in `linked_abilities` |

The data tables are plain sets (`name = true`):

| Field | Entries | Contents |
|---|---|---|
| `excluded_abilities` | 147 | abilities that generic casting logic should skip: toggles, stances and transformations (`invoker_quas`, `morphling_morph_agi`, `kez_switch_weapons`), recasts and returns (`kunkka_return`, `bane_nightmare_end`), summons and utility casts (`chen_holy_persuasion`, `furion_teleportation`, `lone_druid_spirit_bear`), ally versions (`antimage_counterspell_ally`) |
| `excluded_abilities_ultimates` | 6 | ultimates to skip: `centaur_work_horse`, `keeper_of_the_light_radiant_bind`, `keeper_of_the_light_recall`, `spectre_reality`, `techies_minefield_sign`, `witch_doctor_voodoo_switcheroo` |
| `fake_passives` | 11 | abilities flagged passive that behave differently: `beastmaster_inner_beast`, `bristleback_bristleback`, `bristleback_warpath`, `crystal_maiden_brilliance_aura`, `huskar_berserkers_blood`, `lone_druid_spirit_link`, `night_stalker_hunter_in_the_night`, `phantom_lancer_juxtapose`, `shredder_reactive_armor`, `spectre_dispersion`, `storm_spirit_overload` |
| `ignore_channel_check` | 20 | abilities that can be used while channelling or whose channel shouldn't block other actions: `ancient_apparition_ice_blast_release`, `drow_ranger_multishot`, `phoenix_icarus_dive`, `snapfire_mortimer_kisses`, `spirit_breaker_charge_of_darkness`, `templar_assassin_meld`, `tusk_launch_snowball`, ... |
| `linked_abilities` | 12 | second casts that belong to another ability: `ancient_apparition_ice_blast_release`, `dawnbreaker_converge`, `elder_titan_return_spirit`, `ember_spirit_activate_fire_remnant`, `grimstroke_return`, `hoodwink_sharpshooter_release`, `keeper_of_the_light_illuminate_end`, `phoenix_launch_fire_spirit`, `shredder_return_chakram`, `snapfire_spit_creep`, `templar_assassin_trap`, `tusk_launch_snowball` |

```lua
local function shouldAutoCast(ability)
  local name = Ability.GetName(ability)
  if AbilitiesSystem.excluded_abilities[name] then return false end
  if Ability.IsUltimate(ability) and AbilitiesSystem.excluded_abilities_ultimates[name] then return false end
  if AbilitiesSystem.linked_abilities[name] then return false end   -- a recast, handled with its parent
  return true
end
```

---

## g_logger

A logger object (native userdata) that writes to `debug.log` with a level prefix.

**Availability:** load time and callbacks.

| Member | What it does |
|---|---|
| `g_logger:debug(text)` | logs at level `DEBUG` |
| `g_logger:info(text)` | logs at level `INFO`; `g_logger:info("hello")` writes `[INFO] [g_logger] hello` |
| `g_logger:warning(text)` | logs at level `WARNING` |
| `g_logger:error(text)` | logs at level `ERROR` |
| `g_logger:get_level() -> integer` | the current minimum level; `0` (`DEBUG`) by default |
| `g_logger:set_level(level)` | changes the minimum level |
| `g_logger:get_name() -> string` | `"g_logger"`, the name shown in brackets |
| `g_logger.new(...)` | constructor for another logger; arguments unknown |
| `g_logger.DEBUG`, `INFO`, `WARNING`, `ERROR` | levels `0`, `1`, `2`, `3` |

The metatable also has `class_cast`, `class_check` and `__type`, which are part of the native binding.

```lua
g_logger:info("lane groups: " .. #LaneGroupsManager.all_groups)
g_logger:warning("no creeps found")
```


---

## Statistics

```lua
Statistics.AddLog(...)
Statistics.SendData(...)
```

Umbrella's usage statistics: `AddLog` records an entry and `SendData` sends the collected data to Umbrella. Scripts have no reason to call them.

---

## Notification

```lua
Notification(...)
```

A global notification function used by built-in scripts. For your own notifications use the official `Render.CenteredNotification(text, duration)` or the `LIB_RENDER` notification functions.

---

## COURIERS_MAPHACK_DATA

```lua
COURIERS_MAPHACK_DATA[courier: CNPC] -> CourierRecord
```

The data of the built-in Couriers Maphack: enemy couriers it is tracking, keyed by the courier unit. It's empty right after a script reload and fills in once the feature has spotted a courier.

**Availability:** callbacks, once the Couriers Maphack is on and has seen a courier.

### `CourierRecord`

| Field | Type | Meaning |
|---|---|---|
| `courier` | `CNPC` | the courier |
| `courier_owner` | `CNPC` | its owner |
| `is_flying` | `boolean` | flying courier |
| `static_movespeed` | `number` | base speed (`330` while flying) |
| `spawn_position` | `Vector` | where it spawns (the enemy fountain) |
| `start_position`, `start_time` | `Vector`, `number` | where and when the current trip started |
| `end_position` | `Vector` | where the current trip ends |
| `last_path` | `Vector[]` | the predicted route as waypoints |
| `predicted_position`, `predicted_angle` | `Vector`, `Angle` | where it is now by prediction, and its facing |
| `destination_position_prev` | `Vector` | previous destination; `(0, 0, 0)` if none |
| `movespeed_bouns_starttime`, `movespeed_bouns_endtime` (sic) | `number` | game times of the speed boost after leaving the fountain |
| `inventory` | `table` | items it's known to carry |
| `particle` | `table` | the fog marker drawn at its position (`particles/fog_models/idle_model_in_fog.vpcf`), a particle wrapper with `create`, `destroy`, `exists`, `recreate`, `should_draw` and `control_point*` methods |

Each record's metatable provides the methods `get_position`, `get_draw_position`, `is_on_fountain`, `update_courier_position`, `render_courier_icon`, `render_on_minimap`, `render_world_particle` and `remove_particle`, and these constants:

| Constant | Value |
|---|---|
| `const_fountain_buff_duration` | 3 |
| `const_fountain_buff_radius` | 1290 |
| `movespeed_bouns` (sic) | 550 |
| `retrace_path_distance` | 250 |
| `z_offset_flying` | 150 |

```lua
function script.OnUpdate()
  for courier, rec in pairs(COURIERS_MAPHACK_DATA) do
    local where = rec.predicted_position
    local heading = rec.end_position
    local etaSeconds = (heading - where):Length2D() / rec.static_movespeed
  end
end
```

---

## KeyValues

```lua
KeyValues.new(...) -> KeyValues
```

The class of native KeyValues objects (`lua_kv::node_view_t`), the type `KV.KeysPersonal()` returns. `KeyValues.new` creates one. The class table only exposes the constructor; the methods live on the objects.

```lua
local isKv = getmetatable(KeyValues).__type.is(value)
```

---

## RenderTarget and rt_handle_t

```lua
RenderTarget(...)
rt_handle_t.new(...) -> rt_handle_t
```

`rt_handle_t` is the class of render-target handles, the objects behind cached panels such as `LIB_RENDER.skill_ind_data[...].RT.handle`. `RenderTarget` is a global function for render targets. For your own render targets, the official `Render.FindOrCreateRT`, `Render.RenderRT`, `Render.ResizeRT` and `Render.MarkDirtyRT` are documented.

---

## Utils

```lua
Utils.MurmurHash(text: string, seed: integer) -> integer?
Utils.ResourceIdFromName(path: string) -> integer
```

- `MurmurHash` returns the 64-bit MurmurHash2 of `text`. The seed is required; without it the result is `nil`. `Utils.MurmurHash("npc_dota_hero_axe", 0)` is `2472970304528153805`.
- `ResourceIdFromName` converts a resource path to the ID the engine uses for it. `"particles/generic_gameplay/generic_stunned.vpcf"` is `-4626700462506042318`.

```lua
local stunId = Utils.ResourceIdFromName("particles/generic_gameplay/generic_stunned.vpcf")
local key = Utils.MurmurHash(NPC.GetUnitName(Heroes.GetLocal()), 0)
```

---

## KV

```lua
KV.KeysPersonal() -> userdata
KV.LoadFromFile(path: string) -> ?
```

`KeysPersonal` returns a native KeyValues object. `LoadFromFile` parses a KeyValues file from disk. For the game's own data, [KV_LIB](#kv_lib) is easier to use.

---

## DODGER_SLEEPS

State of Umbrella's built-in Dodger. The numbers are the game times until which the Dodger holds off each kind of action; `0` means not sleeping.

| Member | Meaning |
|---|---|
| `ALL` | all dodging paused |
| `ARMLET` | armlet toggling paused |
| `DRUNKEN` | Brewmaster's Drunken Brawler handling paused |
| `MORPH` | Morphling handling paused |
| `ONLY_ATTACK` | attack-only dodging paused |
| `is_destroying_mine(npc) -> boolean` | whether the Dodger is currently attacking a mine with `npc` |

```lua
function script.OnUpdate()
  local now = GameRules.GetGameTime()
  local dodgerBusy = DODGER_SLEEPS.ALL > now or DODGER_SLEEPS.is_destroying_mine(Heroes.GetLocal())
end
```

---

## UserInfo

The signed-in Umbrella account. Keep these values out of anything you share.

| Field | Type |
|---|---|
| `username` | `string` |
| `user_id` | `number` |
| `avatar_url` | `string` |
| `subscription_string` | `string` |
| `subscription_timestamp` | `number` (Unix time) |

```lua
local daysLeft = math.floor((UserInfo.subscription_timestamp - os.time()) / 86400)
```

---

## db

Umbrella's settings store, the data behind `[db] Save requested` in the log. It's a native object; its metatable has `__index`, `__newindex`, `__len`, `__pairs`, `__eq`, `__gc`, `__tostring` and `__name`.

```lua
db:to_table() -> table
```

- `db:to_table()` copies the store into a plain table (153 keys in a typical install). It must be called with `:`.
- `pairs(db)` fails with `cannot call '__pairs/pairs' ... it is not recognized as a container`, and `#db` is always `0`. Iterate over `db:to_table()` instead.
- Writing to `db` changes Umbrella's saved settings. For your own data, use the official `Config` functions.

```lua
local settings = db:to_table()
for key, value in pairs(settings) do
  -- read-only look at Umbrella's settings
end
```

---

## ProfileChanger

```lua
ProfileChanger.SetBadgesEnabled(...)
ProfileChanger.SetHeroLVLBadge(...)
```

Setters behind the built-in Profile Changer script; they change how profile badges are shown on your client. The Profile Changer script itself is listed by `XHelpers.GetScriptList()`, and `XHelpers.GetScript("ProfileChanger")` exposes its settings.

---

## Load

```lua
Load(response: table)
```

xlib's response loader. It reads the `body` field of an HTTP-style response table and fails with `attempt to get length of a nil value (field 'body')` without one. It isn't a general replacement for `load`.

---

## pr, log and profile

```lua
pr(...)
log(...)
profile
```

`pr` and `log` print their arguments to `debug.log` and return nothing. `profile` is Umbrella's profiling hook.

```lua
pr("lane groups:", #LaneGroupsManager.all_groups)
log("tick", GlobalVars.GetCurTime())
```

---

## _VERSION

```lua
_VERSION   -- "Lua 5.5"
```

The runtime is Lua 5.5: integer division, `math.type`, `utf8`, `<const>` and `<close>` locals all work.

---

## Undocumented engine functions

These engine functions exist on official tables but aren't in the official docs. Every other function those tables expose at runtime is documented.

### Entity

| Function | Returns |
|---|---|
| `Entity.GetOrigin(entity) -> Vector` | the same as `GetAbsOrigin` for heroes |
| `Entity.GetAbsRotation(entity) -> Angle` | `.pitch`, `.yaw`, `.roll`; yaw is the facing |
| `Entity.GetModel(entity) -> string` | `"models/heroes/arc_warden/arc_warden_c_1.vmdl"` |
| `Entity.IsModel(entity, model_path: string) -> boolean` | whether the entity uses that model |
| `Entity.GetRoshanEntityIndex() -> integer` | Roshan's entity index, even out of vision |
| `Entity.RecursiveOwnedByIndex(entity, owner_index: integer) -> boolean` | whether `entity` belongs, directly or through its owner chain, to the entity with that index. A hero is owned by its player's index; an ability is not owned by its hero's index (use the official `RecursiveOwnedBy` for that) |
| `Entity.SetModel(entity, model_path)` | changes the model on your client only |
| `Entity.SetScale(entity, scale)` | changes the size on your client only |
| `Entity.SetColor(entity, color)` | tints the entity on your client; the official version is `NPC.SetColor(npc, r, g, b)` |
| `Entity.SetBodygroup(entity, group, value)` | changes a model bodygroup on your client |

### Ability and NPC

| Function | Returns |
|---|---|
| `Ability.GetLevelSpecialValueForFloat(ability, key: string, level?: integer) -> number` | the float version of `GetLevelSpecialValueFor`; `0` for an unlearned ability |
| `NPC.GetDamageMultiplierVersus(attacker, target) -> number` | the attack-type against armor-type multiplier; `1` for a hero against a lane creep |

### Engine, HTTP, Panorama, chronos, Humanizer

| Function | Returns |
|---|---|
| `Engine.GetBarColorById(id) -> integer, integer, integer` | three packed colours of a health bar style; id `0` is `15103743` three times |
| `Engine.SetBarColorById(id, ...)` | changes a health bar colour |
| `Engine.GetDemoPanel() -> Panel?` | the demo-mode panel; `nil` outside demo mode |
| `Engine.GetRegionPlayersStat() -> table` | region ID to its matchmaking group token: `0` → `"#dota_matchgroup_uswest"`, `2` → `"#dota_matchgroup_eu"`, `3` → `"#dota_matchgroup_sea"`, `7` → `"#dota_matchgroup_ru"`, 20 regions |
| `Engine.OpenURL(url: string)` | opens a URL in the browser |
| `Engine.TipAlert(...)` | shows a HUD alert |
| `Engine.SetLabirinthEnabled(enabled: boolean)` | an internal feature flag |
| `Engine.GetSessionKey() -> string` | your Umbrella session key; treat it like a password |
| `HTTP.GetServerTime() -> integer` | Unix time from Umbrella's server, within a second of `os.time()` |
| `Panorama.SymbolToString(id: integer) -> string` | a Panorama event symbol name. IDs are assigned at runtime and change between game launches (`0` can be `"MoveUp"` one time and `"DropTarget"` the next), so look symbols up by ID only within the same session |
| `chronos.nanotime_ns() -> integer` | the `chronos.nanotime()` clock in nanoseconds |
| `Humanizer.ResetPanelSizeCache()` | clears the Humanizer's cached panel sizes |

```lua
local hero = Heroes.GetLocal()
local facing = Entity.GetAbsRotation(hero).yaw
local roshan = Entity.Get(Entity.GetRoshanEntityIndex())

local started = chronos.nanotime_ns()
-- work
local elapsedMs = (chronos.nanotime_ns() - started) / 1e6
```

---

## Undocumented enums

### `Enum.DefaultFont`

| Key | Value |
|---|---|
| `MUSEOSANS` | 3 |
| `FONTAWESOME` | 8 |
| `VERDANA` | 11 |
