# API_PARITY — Self Play bot contract vs. Lotus bridge

Static read-only audit (no Dota/inject run). Date: 2026-11-15.
Contract: `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\Self Play.lua` + `self_play\**\*.lua` (123 files).
Bridge: `D:\hake\lotus\src\api.lua`, `loader.lua`, `orders.lua`, `entity.lua`, `schema.lua`, `enums.lua`, `render.lua`, `menu.lua`, `xhelpers.lua`.
Offset sources: `D:\hake\lotus\schema_dump.json` (SD, 15 classes), `D:\hake\lotus\dumper\dota2_dump\offsets.json` (OJ, build `987800-1dd55f3e8eed2d5`, 12 client classes + 3 engine globals), KV `D:\hake\lotus\gamedata\*.json`.
Contract semantics: `D:\hake\lotus\umbrella_api\*.md`.

Method: regex `([A-Z][A-Za-z]+)\.([A-Za-z_]+)\(` over all 123 files → ~5.8k call sites, 362 distinct keys. ~5.45k calls target engine namespaces; the rest are bot-internal modules or camelCase artifacts (`heroModule.locked` → "Module.locked", `helpRotation.update` → "Rotation.update", `ioHero.locked` → "Hero.locked"). Excluded internal namespaces: Hit, Sim, Policy, Play, Defense, Rules, Safety, Data, March, Spots, Control, Rotation, Module(s), Camps, Brain, Groups, Cleanup, Model, Block, Spacing, Choice, Farm, Items. `Tower.GetAttackTarget` IS an engine call (global `Tower` stubbed in loader.lua:93; local `Tower` tables in creep_block/recovery are unrelated).

Status legend: **OK** real implementation · **PARTIAL** works but incomplete semantics · **STUB** constant return · **MISSING** no definition (metatable soft-stub: `Get*`→0, `Is*/Has*`→false, else nil; loader `stubNS`→nil) · **BROKEN** implemented but reads a schema field that does not exist on this build → constant wrong value · ⚠ = nil return crashes call sites (arithmetic / `ipairs` / `#`).

---

## 1. Call-frequency table (top 60)

| # | Calls | API | Status | Note |
|---|-------|-----|--------|------|
| 1 | 693 | Entity.GetAbsOrigin | OK | scene-node `m_vecAbsOrigin` |
| 2 | 284 | Entity.GetHealth | OK | `m_iHealth` 0x34C |
| 3 | 197 | Entity.IsSameTeam | OK | |
| 4 | 167 | Entity.GetIndex | OK | identity+0x10 handle |
| 5 | 157 | Entity.IsAlive | OK | `m_lifeState` 0x354 |
| 6 | 149 | Entity.IsEntity | OK | |
| 7 | 149 | NPC.HasState | OK | `m_nUnitState64` 0x12B8 bitmask |
| 8 | 143 | NPC.GetAttackRange | OK | `m_iAttackRange` 0xCC8 |
| 9 | 135 | NPC.GetAbility | OK | `m_vecAbilities` 0xD28 |
| 10 | 127 | Entity.GetMaxHealth | OK | `m_iMaxHealth` 0x348 |
| 11 | 115 | Ability.GetCastRange | PARTIAL+DATA | KV-only; hero abilities absent from dump → 0 (§6) |
| 12 | 110 | NPC.HasModifier | OK | ModifierManager 0xE30 |
| 13 | 110 | NPC.IsIllusion | OK | `m_bIsIllusion` 0xD24 |
| 14 | 98 | NPC.IsHero | OK | name match |
| 15 | 95 | NPC.GetUnitName | OK | designerName |
| 16 | 95 | NPC.GetMoveSpeed | OK | `m_iMoveSpeed` 0xCE0 |
| 17 | 93 | Ability.GetName | OK | |
| 18 | 89 | NPC.IsAttacking | STUB | `false` (api.lua:173) |
| 19 | 87 | NPC.GetAttackRangeBonus | BROKEN | reads absent `m_iAttackRangeBonus` → 0 |
| 20 | 84 | Entity.IsDormant | OK | identity flags 0x30 heuristic |
| 21 | 83 | NPC.IsVisible | PARTIAL | = not dormant, not team-visibility |
| 22 | 81 | GridNav.IsTraversable | STUB | `true` (loader.lua:105) |
| 23 | 78 | NPC.GetTrueDamage | PARTIAL | `m_iDamageMin` 0xE18; verify `m_iDamageBonus` 0xE20 folding |
| 24 | 75 | Ability.GetLevel | OK | 0x628 |
| 25 | 74 | NPC.GetMana | BROKEN | reads absent `m_iMana` → 0; real: `m_flMana` 0xCFC |
| 26 | 70 | Log.Write | OK | host.log |
| 27 | 69 | Ability.GetManaCost | PARTIAL+DATA | 0x640 + KV fallback (hero KV missing) |
| 28 | 56 | Ability.GetCastPoint | PARTIAL+DATA | override 0x658 + KV (hero KV missing) |
| 29 | 56 | NPC.IsChannellingAbility | OK | ability scan; relies on approx GameTime |
| 30 | 53 | NPC.GetSecondsPerAttack | STUB | `1.7` (api.lua:310) |
| 31 | 50 | NPC.IsStunned | OK | via HasState |
| 32 | 49 | NPC.IsLaneCreep | OK | |
| 33 | 49 | NPC.GetArmorDamageMultiplier | STUB | `1` (api.lua:313) |
| 34 | 49 | NPC.GetItem | OK | Inventory 0x11C0 + `m_hItems` 0x20 |
| 35 | 40 | Hero.GetRecentDamage | STUB | `0` (api.lua:341) |
| 36 | 35 | NPC.IsRunning | STUB | = IsAlive (wrong semantics) |
| 37 | 34 | NPC.GetMaxMana | BROKEN | reads absent `m_iMaxMana` → 0; real: `m_flMaxMana` 0xD00 |
| 38 | 33 | NPC.FindFacingNPC | STUB | `nil` (api.lua:326) |
| 39 | 31 | World.GetGroundZ | STUB | `128` (loader.lua:123) |
| 40 | 30 | NPC.GetItemByIndex | OK | |
| 41 | 29 | NPC.GetHullRadius | OK | `m_flHullRadius` 0xD60 |
| 42 | 29 | GameRules.GetGameTime | PARTIAL | order-timestamp anchor + wall clock (api.lua:497) |
| 43 | 29 | NPC.IsRanged | BROKEN | reads absent `m_bIsRanged` → false for everything |
| 44 | 27 | Item.GetCurrentCharges | STUB | `0` (loader.lua:83) |
| 45 | 27 | NPC.GetCurrentLevel | OK | `m_iCurrentLevel` 0xC9C |
| 46 | 26 | NPC.GetAbilityByIndex | OK | |
| 47 | 26 | Player.PrepareUnitOrders | OK | PUO RVA 0x1B5F860 (build-specific) |
| 48 | 25 | Ability.IsReady | PARTIAL | no mana/owner check (owner stub nil) |
| 49 | 24 | NPC.GetMagicalArmorDamageMultiplier | STUB | `1` (api.lua:314) |
| 50 | 24 | Ability.IsHidden | OK | 0x617 |
| 51 | 23 | NPC.GetHealthRegen | OK | `m_flHealthRegen` 0x1744 |
| 52 | 21 | Ability.GetCooldown | OK | 0x638 − GameTime (time-approx risk) |
| 53 | 21 | NetChannel.GetAvgLatency | STUB | `0` (loader.lua:127) |
| 54 | 21 | NPC.IsCreep | OK | |
| 55 | 20 | NPC.IsNeutral | OK | |
| 56 | 18 | Ability.GetToggleState | OK | 0x62D |
| 57 | 17 | NPC.IsStructure | OK | |
| 58 | 17 | NPC.IsRoshan | OK | |
| 59 | 17 | NPC.GetModifier | OK | |
| 60 | 17 | Item.IsItemEnabled | STUB | `true` (loader.lua:89) |

### Engine calls ranked 61–160+ (condensed)

| Calls | API | Status | | Calls | API | Status |
|---|---|---|---|---|---|---|
| 16 | NPC.IsSilenced | OK | | 7 | Ability.IsChannelling | OK |
| 16 | Entity.IsNPC | OK | | 7 | NPC.GetModifierProperty | STUB 0 |
| 15 | NPC.MoveTo | OK | | 7 | NPC.IsEntityInRange | OK |
| 15 | NPC.IsWaitingToSpawn | STUB false | | 6 | Couriers.GetLocal | MISSING nil |
| 15 | NPC.IsAncient | OK | | 6 | Ability.CanBeExecuted | PARTIAL (=IsReady) |
| 14 | Ability.GetDamage | PARTIAL KV | | 6 | FogOfWar.IsPointVisible | MISSING nil |
| 14 | GridNav.BuildPath | STUB midpoint | | 6 | Heroes.GetAll | OK |
| 14 | Entity.GetRotation | OK | | 6 | Ability.GetDamageType | STUB 0 |
| 13 | Ability.IsPassive | PARTIAL KV | | 5 | GameRules.GetGameStartTime | OK |
| 13 | NPC.IsFort / IsTower | OK | | 5 | Player.HoldPosition | OK |
| 13 | NPC.IsMeepoClone | STUB false | | 5 | Tree.IsActive | MISSING nil |
| 12 | Ability.GetLevelSpecialValueFor | MISSING →0 | | 5 | NPC.GetTrueMaximumDamage | OK |
| 12 | Ability.IsCastable | PARTIAL | | 5 | Players.GetLocal / GetAll | OK |
| 12 | NPC.IsTormentor | STUB false | | 5 | Panorama.GetPanelByName | MISSING nil |
| 11 | Entity.GetTeamNum | OK | | 5 | Trees.InRadius | MISSING ⚠ nil |
| 11 | Ability.GetBehavior | PARTIAL KV | | 5 | NPC.GetStatesDuration | STUB {} |
| 11 | NPC.GetBarriers | STUB zeros | | 5 | Entity.GetField | PARTIAL (1-arg→false) |
| 10 | NPC.IsInRangeOfShop | STUB false | | 5 | NPC.IsLinkensProtected | STUB false |
| 10 | Hero.GetReplicatingOtherHeroModel | STUB nil | | 5 | Bottle.GetRuneType | MISSING nil |
| 10 | NPC.GetAttackSpeed | STUB 0 | | 4 | NPC.HasScepter | STUB false |
| 10 | Ability.IsActivated | OK | | 4 | Modifier.GetStackCount | MISSING nil |
| 9 | NPC.GetTimeToFace | STUB 0 | | 4 | NPC.GetBountyXP | STUB 0 |
| 9 | NPC.GetAttackAnimPoint | STUB 0.45 | | 4 | Hero.GetRespawnTime | OK |
| 9 | Item.GetCost | STUB 0 | | 4 | Player.AttackTarget | OK |
| 9 | Ability.IsUltimate | PARTIAL KV | | 4 | Engine.IsInGame / RunScript | OK / STUB |
| 4 | GC.SendMessage / GetSteamID | STUB | | 3 | Item.GetSecondaryCharges | MISSING ⚠ nil |
| 4 | Ability.Toggle / ToggleMod | OK | | 3 | HTTP.Request | STUB noop |
| 4 | NPC.GetModifiers | OK | | 3 | Entity.Get / GetOwner | OK |
| 4 | Player.GetTeamPlayer | OK | | 3 | NPC.HasShard | STUB false |
| 4 | NPC.GetManaRegen | OK | | 3 | NPC.IsControllableByPlayer | PARTIAL |
| 3 | Rune.GetRuneType | MISSING nil | | 3 | Ability.GetChannelStartTime | MISSING →0 |
| 3 | Render.Line/Text/WorldToScreen/ScreenSize/FilledCircle | OK | | 3 | NPC.IsWard | OK |
| 2 | Ability.GetAutoCastState / SecondsSinceLastUse | MISSING →0 | | 2 | Modifier.GetCaster | MISSING nil |
| 2 | Hero.GetLastVisibleTime / GetLastMaphackPos / GetPrimaryAttribute | STUB | | 2 | GridNav.CreateNpcMap / ReleaseNpcMap | STUB |
| 2 | Item.GetStockCount / GetPlayerOwnerID | STUB | | 2 | NetChannel.SendNetMessage | MISSING nil |
| 2 | Runes.GetAll / TempTrees.GetAll | STUB {} | | 2 | NPC.GetAttackProjectileSpeed / GetGoldBountyMin | STUB 0 |
| 1 | NPCs.InRadius | MISSING ⚠ nil | | 1 | Hero.GetCurrentXP | MISSING →0 |
| 1 | Hero.GetStrength | BROKEN (`m_iStrength` absent) | | 1 | Hero.TalentIsLearned | STUB false |
| 1 | Player.GetAssignedHero | PARTIAL (always local) | | 1 | Player.GetQueryUnit / GetSelectedUnits | STUB |
| 1 | GameRules.IsPaused | STUB false | | 1 | Engine.IsShopOpen / AcceptMatch / CanAcceptMatch / GetHeroNameByID | STUB/MISSING |
| 1 | Menu.Create / Opened | OK | | 1 | Menu.Find | STUB nil |
| 1 | Modifier.GetCreationTime / GetState | MISSING nil | | 1 | Item.RequiresCharges / IsCombineLocked / IsStackable / IsSellable | STUB/MISSING |
| 1 | PhysicalItem.GetItem / PhysicalItems.GetAll / PowerTreads.GetStats | MISSING/STUB | | 1 | Humanizer.GetOrderQueue | STUB {} |
| 1 | Abilities.AttemptToUpgrade | MISSING nil | | 1 | Input.IsKeyDown / IsInputCaptured | STUB/MISSING |
| 1 | NPC.GetOwnerNPC / GetGoldBountyMax / IsMirrorProtected / IsVisibleToEnemies | STUB | | 1 | Entities.GetAll | OK |

---

## 2. Implemented (real) surface

- **Entity**: Get, GetIndex, GetClassName, GetAbsOrigin, GetHealth, GetMaxHealth, GetTeamNum, GetOwner (`m_hOwnerEntity` 0x514), IsAlive, IsDormant, IsEntity, IsNPC, IsSameTeam, GetRotation (`CGameSceneNode::m_angAbsRotation` 0xE4), GetField (2-arg schema form).
- **NPC**: GetUnitName, GetHealth/GetMaxHealth, GetCurrentLevel, GetMoveSpeed, GetAttackRange, GetHealthRegen/GetManaRegen, GetTrueDamage/GetTrueMaximumDamage, GetHullRadius, IsHero/IsCreep/IsLaneCreep/IsIllusion/IsNeutral/IsAncient/IsTower/IsBarracks/IsFort/IsStructure/IsCourier/IsRoshan/IsWard, IsStunned/IsSilenced/IsRooted/IsDisarmed (via HasState), HasState, HasModifier/GetModifier/GetModifiers, GetAbility/GetAbilityByIndex, GetItem/GetItemByIndex, MoveTo, IsEntityInRange, IsChannellingAbility, IsControllableByPlayer (local hero + illusions only).
- **Ability**: GetName, GetLevel/GetMaxLevel, CanBeUpgraded, GetCooldown/GetCooldownLength, GetManaCost (runtime+KV), GetCastRange (KV), GetCastPoint (override+KV), GetDamage (KV), IsReady (partial), IsPassive/IsUltimate (KV behavior), IsHidden, IsActivated, IsInAbilityPhase, GetToggleState, GetCurrentCharges (0x660), GetBehavior/GetTargetTeam/GetTargetType/GetTargetFlags (KV), IsChannelling, CanBeExecuted, IsCastable (partial), CastNoTarget/CastPosition/CastTarget/Toggle/ToggleMod (real orders).
- **Hero/Heroes**: GetPlayerID, GetAbilityPoints, GetRespawnTime; Heroes.GetAll/GetLocal.
- **Player/Players**: PrepareUnitOrders, AttackTarget, HoldPosition, GetPlayerID, GetTotalGold, GetTeamPlayer (team-data record reads — see risk R6), Players.GetAll/GetLocal.
- **GameRules**: GetGameTime (anchored approximation), GetGameState (0x7C), GetGameStartTime (0x594), GetGameMode (0xE4), GetMatchID (0x858).
- **Engine**: IsInGame, IsInLobby, GetCheatDirectory. **Log**: Write. **Config**: Read/Write Int/Float/String (in-memory only).
- **Render** (render.lua): WorldToScreen (view matrix), ScreenSize, Text, TextSize, Line, Circle, FilledCircle, FilledRect, LoadFont. **Menu** (menu.lua): Create, Opened, widget groups. **Enums** (enums.lua, 49 KB): ModifierState, UnitOrder, PlayerOrderIssuer, GameActivity, ModifierFunction, AbilityBehavior, TeamType, Flow, etc. — complete for bot usage.
- **Lists**: Entities.GetAll, NPCs.GetAll (loader overrides).
- **Orders pipeline** (orders.lua): verified PUO call, local controller discovery, issuer handling; Present-hook queue deliberately disabled (black-screen risk on this build).

---

## 3. BROKEN reads (implemented, wrong field names — silent constant returns)

Both dumps agree these fields do not exist on build `987800`; `schema.offsetOf` returns nil → default.

| API (calls) | Reads (absent) | Correct field | Fix |
|---|---|---|---|
| NPC.GetMana (74) | `m_iMana` | `C_DOTA_BaseNPC::m_flMana` **0xCFC** (SD+OJ) | rename, keep f32 |
| NPC.GetMaxMana (34) | `m_iMaxMana` | `C_DOTA_BaseNPC::m_flMaxMana` **0xD00** (SD+OJ) | rename, keep f32 |
| NPC.GetAttackRangeBonus (87) | `m_iAttackRangeBonus` | no such field | derive: `m_iAttackRange` 0xCC8 − KV `AttackRange` (npc_units.json), clamp ≥0 |
| NPC.IsRanged (29) | `m_bIsRanged` | no such field | `m_iAttackCapabilities` **0x13B4** & 2 (`DOTA_UNIT_CAP_RANGED_ATTACK`) or KV `AttackCapabilities` |
| Hero.GetStrength (1) | `m_iStrength` | `C_DOTA_BaseNPC_Hero::m_flStrength` **0x1AE0** (SD+OJ) | rename, f32 |
| Player.GetTotalGold/GetTeamPlayer (12) | `m_vecDataTeam` fallback 0x5F0 | `C_DOTA_PlayerResource::m_vecPlayerTeamData` **0x608** (SD) | fix name+fallback; re-verify 0x12F0 record stride live |

Impact: mana gates always 0 → bot refuses spells it can cast (or scripts mis-spend); every unit treated as melee; range bonus 0 corrupts focus/last-hit/support_policy range math (`last_hit.lua:289`, `focus.lua:46`, `support_policy.lua:32`).

---

## 4. Stub/missing gaps sorted by impact area

### A. Combat / last-hit (highest)
| Gap | Calls | Effect on bot |
|---|---|---|
| NPC.IsAttacking → false | 89 | engagement/fights/awareness/tower_safety never see attacks; `IsAttacking and FindFacingNPC` chains all dead |
| NPC.GetAttackRangeBonus → 0 (BROKEN) | 87 | attack-range math short by bonus (dragon lance/talents) |
| NPC.GetSecondsPerAttack → 1.7 | 53 | last-hit windup timing wrong for every unit (creeps 1.0, heroes vary) |
| NPC.GetArmorDamageMultiplier → 1 | 49 | physical last-hit/deny thresholds ignore armor → missed LH, failed denies |
| Hero.GetRecentDamage → 0 | 40 | "am I/ally being attacked" always false → retreat/heal/TP decisions blind (combat.lua:171, recovery.lua:231, travel.lua:78) |
| NPC.FindFacingNPC → nil | 33 | target-of-attack inference dead everywhere (last_hit.lua:89/289, positioning, roshan aggro) |
| NPC.GetMagicalArmorDamageMultiplier → 1 | 24 | spell burst sim overestimates damage |
| NPC.GetBarriers → zeros | 11 | barrier-aware kill thresholds wrong |
| NPC.GetAttackSpeed → 0 / GetAttackAnimPoint → 0.45 | 10+9 | attack timing constants |
| NPC.GetTimeToFace / GetTimeToFacePosition → 0 | 9+6 | turn-rate lead omitted (last_hit.lua:49/625) |
| Modifier.GetDieTime → nil ⚠ | 8 | **crashes** fight_sim.lua:218, engagement.lua:54, common.lua:52, recovery.lua:24, units.lua:181, help_rotation.lua:98, shadow_demon.lua:28 → whole tick aborted (loader pcalls OnUpdate) |
| NPC.GetModifierProperty → 0 | 7 | deny-percent threshold (last_hit.lua:412/530/611), disable-healing check (engagement.lua:147) dead |
| Tower.GetAttackTarget → nil | 8 | tower-aggro/dive safety blind (Self Play.lua:439/490/529, tower_safety.lua:21, dive.lua:31) |
| Modifier.GetStackCount/GetCaster/GetCreationTime/GetState → nil | 4+2+1+1 | stack tracking (shadow_demon), modifier attribution dead |
| NPC.IsLinkensProtected/IsMirrorProtected → false | 5+1 | spell-target selection ignores spell blocks |
| NPC.GetStatesDuration → {} | 5 | stun-duration-aware combos dead |
| NPC.GetBountyXP/GetGoldBountyMin/Max → 0 | 4+2+1 | farm value model blind |

### B. Movement / GridNav
| Gap | Calls | Effect |
|---|---|---|
| GridNav.IsTraversable → true | 81 | every cliff/wall/tree point "valid"; navigation/positioning/blink-landing checks are no-ops |
| World.GetGroundZ → 128 | 31 | high-ground logic flat (support_camps.lua:72 always true), ward-spot elevation scores wrong |
| GridNav.BuildPath → straight midpoint | 14 | paths cut through terrain; no wayaround |
| NPC.IsRunning → IsAlive | 35 | "moving" inference wrong (support_camps.lua:265) |
| GridNav.CreateNpcMap/ReleaseNpcMap/IsTraversableFromTo | 2+2+0 | stubs |

### C. Items / shopping
| Gap | Calls | Effect |
|---|---|---|
| Item.GetCurrentCharges → 0 | 27 | ward/bottle/charge items always "empty" (vision.lua:10, runes.lua:71, objectives.lua:81) |
| Item.IsItemEnabled → true | 17 | cooldown-locked items treated usable |
| NPC.IsInRangeOfShop → false | 10 | side-shop/fountain shopping gating dead |
| Item.GetCost → 0 | 9 | buy/sell value math zero |
| Couriers.GetLocal → nil | 6 | courier delivery/return logic inert (shop.lua, recovery.lua:67) |
| Bottle.GetRuneType → nil | 5 | bottle rune tracking dead (runes.lua:62/161) |
| NPC.HasScepter/HasShard → false | 4+3 | upgrade-aware ability logic dead |
| Item.GetSecondaryCharges → nil ⚠ | 3 | vision.lua:10/18, objectives.lua:81 nil propagation |
| Item.GetStockCount → 99, RequiresCharges/IsCombineLocked/IsStackable/IsSellable/GetPlayerOwnerID | 2+1+1+1+3+2 | constants |
| PowerTreads.GetStats → nil | 1 | tread-switching dead |

### D. Casting
| Gap | Calls | Effect |
|---|---|---|
| Ability.GetCastRange KV-only + **hero abilities missing from KV dump** | 115 | returns 0 for most hero spells → cast-range gates fail (§6) |
| Ability.GetCastPoint / GetManaCost KV fallback | 56+69 | same data gap for hero spells |
| Ability.IsReady/IsCastable — no mana/owner gate | 25+12 | casts attempted OOM; `NPC.GetOwnerNPC` nil (api.lua:277) |
| Ability.GetLevelSpecialValueFor → 0 | 12 | mobility/aim/arc_warden/earth_spirit distance/delay math zeroed |
| Ability.GetBehavior/IsPassive/IsUltimate KV-only | 11+13+9 | wrong for stolen/morphed abilities; data gap |
| Ability.GetDamageType → 0 | 6 | damage-type-aware targeting dead |
| Ability.GetAutoCastState → 0 | 2 | orb-walk toggling dead (field exists: 0x644) |
| Ability.SecondsSinceLastUse → 0 | 2 | (fields exist: 0x650/0x6A0) |
| Ability.GetChannelStartTime → 0 | 3 | (field exists: 0x64C) |
| Hero.TalentIsLearned → false; Abilities.AttemptToUpgrade → nil | 1+1 | talent/leveling automation dead |

### E. States / unit classification
| Gap | Calls | Effect |
|---|---|---|
| NPC.IsWaitingToSpawn → false | 15 | spawn-camp/stack timing blind (field 0x1730) |
| NPC.IsMeepoClone → false | 13 | clone micro dead (field `m_bIsClone` 0xCCC) |
| NPC.IsTormentor → false | 12 | tormentor objectives dead (name `npc_dota_miniboss`) |
| Hero.GetReplicatingOtherHeroModel → nil | 10 | morph/illusion model inference dead (handle 0x1B7C) |
| Hero.GetPrimaryAttribute/GetCurrentXP/GetLastVisibleTime/GetLastMaphackPos → 0 | 2+1+2+2 | attribute/XP/missing-hero tracking dead (fields exist) |
| NPC.IsControllableByPlayer — partial | 3 | summons/ dominated creeps excluded (mask 0xCB8) |
| NPC.IsVisibleToEnemies → false | 1 | smoke/invis logic |
| Entity.GetField 1-arg (`m_bActive`, `m_bIsBeingGranted`) → false | 5 | wisdom-rune collection logic dead (objectives.lua:130–210) |

### F. Projectiles
| Gap | Calls | Effect |
|---|---|---|
| NPC.GetAttackProjectileSpeed → 0 | 2 | ranged LH travel time omitted (KV `ProjectileSpeed` available for units) |
| LinearProjectiles namespace | 0 | stubbed in loader, unused by current bot — no action needed |

### G. Fog / vision / trees
| Gap | Calls | Effect |
|---|---|---|
| FogOfWar.IsPointVisible → nil (falsy) | 6 | deward/ward-spot/rune-scan logic inverted: points always "not visible" (detection.lua:90, runes.lua:150, awareness.lua:147) |
| Trees.InRadius → nil ⚠ | 5 | **crashes** hoodwink.lua:6, mars.lua:36, timbersaw.lua:29; `#nil` tinker.lua:38; ward_spots.lua:48 |
| Tree.IsActive → nil | 5 | tree-interaction heroes dead |
| TempTrees.GetAll/InRadius, Entity.GetTreesInRadius/GetTempTreesInRadius | 2+2 | empty/nil |
| Rune.GetRuneType → nil; Runes.GetAll → {} | 3+2 | rune control dead |
| NPC.IsVisible = not-dormant | 83 | semantics differ from Umbrella (enemy-team visibility) |

### H. Infrastructure / misc
NetChannel.GetAvgLatency → 0 (21; latency compensation in last_hit/invoker/aim dead) · GameRules.IsPaused → false, glyph CDs → 0 · Engine.ExecuteCommand log-only, RunScript noop, IsShopOpen nil · Player.GetQueryUnit/GetSelectedUnits stubs, GetAssignedHero always local · GC/HTTP/Panorama/Input stubs · Config not persisted across restarts · GameRules.GetGameTime drifts when bot sends no orders (anchor stale) → cooldown/channel math drifts.

---

## 5. Top-20 implementation proposals (ranked by impact)

Offsets: SD = schema_dump.json, OJ = dumper/dota2_dump/offsets.json (both agree unless noted). All `C_DOTA_*` are client.dll classes; resolve via existing `schema.offsetOf` (patch-resilient) rather than new hardcodes.

**P1. NPC.GetMana / GetMaxMana — 108 calls, casting gate (BROKEN).**
`field(e,"C_DOTA_BaseNPC","m_flMana","f32")` → **0xCFC**; `m_flMaxMana` → **0xD00** (SD+OJ). Two-line rename in api.lua:142–143. Unblocks every script-side mana check.

**P2. NPC.IsAttacking — 89 calls.**
Read `C_DOTA_BaseNPC::m_NetworkActivity` **0x18E8** (SD+OJ, i32); true when ∈ {`ACT_DOTA_ATTACK`=1503, `ACT_DOTA_ATTACK2`=1504} (enums.lua GameActivity already has them). Fallback/fuse: `GameTime − m_flLastAttackTime` **0x13C8** < GetSecondsPerAttack (P5). Activity lags one tick; the time-window fusion covers it.

**P3. NPC.GetAttackRangeBonus — 87 calls (BROKEN).**
No such field. Compute `max(0, m_iAttackRange(0xCC8) − KV AttackRange)` using npc_units.json (present for creeps/neutrals/buildings); heroes need npc_heroes.json re-dump (§6). Interim: explicit 0 + one-time log instead of silent schema miss.

**P4. GridNav.IsTraversable / BuildPath / IsTraversableFromTo — 95 calls.**
No CGridNav data in either dump. Two-stage: (a) interim conservative filter — static blocked-region rectangles for cliffs/walls + tree-circle rejection (P20) + out-of-map bounds; BuildPath = A* over a 128-unit grid using that filter (replaces loader.lua:109 midpoint). (b) real fix — extend the dumper to signature-scan the client gridnav singleton and cell-query fn (same workflow as PUO RVA). Always-true currently validates blink landings into cliffs; any conservative filter is a net win.

**P5. NPC.GetSecondsPerAttack / GetAttackSpeed — 63 calls.**
`m_flBaseAttackTime` **0xCE8** (BAT, f32) and `m_iBaseAttackSpeed` **0xCE4** (current AS incl. IAS, i32) (SD+OJ). `GetAttackSpeed = m_iBaseAttackSpeed`; `GetSecondsPerAttack = BAT / (clamp(AS,20,700)/100)`; `bIgnoreTempAttackSpeed` → KV `AttackRate` base (npc_units.json). Creep example: BAT 1.0, AS 100 → 1.0 s vs current constant 1.7.

**P6. NPC.GetArmorDamageMultiplier — 49 calls.**
`m_flPhysicalArmorValue` **0x162C** (f32, SD+OJ). Dota formula: armor ≥ 0 → `1 − (0.06·a)/(1 + 0.06·a)`; armor < 0 → `2 − 0.94^(−a)` (approximation of the negative-armor amplification curve; calibrate once in-game).

**P7. Hero.GetRecentDamage — 40 calls.**
`C_DOTA_BaseNPC_Hero::m_iRecentDamage` **0x1B28** (i32, SD+OJ). Direct read; drives retreat/heal/TP decisions across ~25 files.

**P8. NPC.FindFacingNPC — 33 calls.**
Composite, no single field: if `m_NetworkActivity` (P2) is attack, cone-scan NPCs: candidates within `distance` arg of source, team filter per `Enum.TeamType`, `|wrap(yaw − atan2(dy,dx))| ≤ angle` (deg), yaw from `CGameSceneNode::m_angAbsRotation` **0xE4** (already read by GetRotation). Prefer `m_hGoalEntity` **0x1768** (SD+OJ) when it resolves to an in-range enemy. Cache per tick (called in hot loops).

**P9. World.GetGroundZ — 31 calls.**
Constant 128 flattens high-ground checks (support_camps.lua:72). No offset available. Options: (a) engine TraceRay vs world via signature scan (dumper work), (b) offline heightmap grid baked from map data, (c) interim: z of nearest live entity within 300 u, else 128. (c) is cheap and fixes lane/jungle elevation relative checks.

**P10. NPC.IsRanged — 29 calls (BROKEN).**
`m_iAttackCapabilities` **0x13B4** (SD+OJ) & `DOTA_UNIT_CAP_RANGED_ATTACK` (2); fallback KV `AttackCapabilities == "DOTA_UNIT_CAP_RANGED_ATTACK"` (npc_units.json). Fixes ranged-LH projectile logic and focus targeting.

**P11. Item state cluster — 60+ calls.**
`C_DOTA_Item` (SD+OJ): GetCurrentCharges → `m_iCurrentCharges` **0x6E0**; GetSecondaryCharges → `m_iSecondaryCharges` **0x6E4** (fixes ⚠ nil); IsItemEnabled → `m_bItemEnabled` **0x701** AND `m_flEnableTime` **0x704** ≤ GameTime; IsCombineLocked → `m_bCombineLocked` **0x6EC**; IsStackable → `m_bStackable` **0x6AE**; IsSellable → `m_bSellable` **0x6BE**; RequiresCharges → `m_bRequiresCharges` **0x6C1**; GetPlayerOwnerID → `m_iPlayerOwnerID` **0x72C**; GetCost → items.json `ItemCost` (544 items present, e.g. item_blink=2250). GetStockCount: shop stock not dumped → keep 99.

**P12. NetChannel.GetAvgLatency — 21 calls.**
Interim: `C_DOTAPlayerController::m_flLastUnitOrdersTotalLatency` **0x948** (SD+OJ) on the local controller — order RTT; use value/2 for FLOW_OUTGOING, value/2 for FLOW_INCOMING (approximation). Real fix: engine.dll `INetChannel` via CreateInterface (same pattern as schema.lua). Last-hit windup (last_hit.lua:49) and Invoker combo timing consume this directly.

**P13. NPC.GetMagicalArmorDamageMultiplier — 24 calls.**
`m_flMagicalResistanceValue` **0x1630** (f32 percent, SD+OJ) → `1 − v/100` (field already aggregates base+items; verify against KV `MagicalResistance` once).

**P14. Modifier.GetDieTime / GetStackCount / GetCaster / GetCreationTime / GetName — 16 calls, ⚠ crash.**
Class `C_DOTA_Modifier_Lua` is in neither dump — resolve at runtime: `schema.offsetOf("C_DOTA_Modifier_Lua","m_flDieTime")`, `m_iStackCount`, `m_hCaster` (→ entity.byHandle), `m_flCreationTime`; the live SchemaSystem can resolve any client class (schema.lua already does). **Immediate guard:** GetDieTime fallback `0` (call sites wrap in `math.max(0, die−now)`), GetName → designer(m). Stops tick-aborting crashes in fight_sim/engagement/recovery.

**P15. Unit-flag cluster — 53 calls.**
IsMeepoClone → `m_bIsClone` **0xCCC**; IsWaitingToSpawn → `m_bIsWaitingToSpawn` **0x1730**; IsTormentor → designerName == `npc_dota_miniboss` (in npc_units.json); HasScepter → `m_bLastScepterState` **0x12ED** OR `m_bForceScepterState` **0x12EE**; HasShard → `m_bLastShardState` **0x12EC** OR `m_bForceShardState` **0x12EF**; GetBountyXP → `m_iXPBounty` **0x1754** (+`m_iXPBountyExtra` **0x1758**); GetGoldBountyMin/Max → **0x175C/0x1760** (all SD+OJ, u8/i32 as named).

**P16. Ability.GetLevelSpecialValueFor — 12 calls.**
Extend existing `abilityKV()` (api.lua:591) to read the `AbilitySpecial` block: key → `{value}` or level-scaled string; reuse `kvNum` parser. Requires full npc_abilities re-dump (§6) — hero spells are absent today. Unblocks mobility.lua:50–54, aim.lua:58, arc_warden, earth_spirit geometry.

**P17. Ability.IsReady / IsCastable mana+owner gate — 37 calls.**
Implement `NPC.GetOwnerNPC` via `C_DOTA_BaseNPC::m_hOwnerNPC` **0x1764** (SD+OJ) → `entity.byHandle`. Then IsReady &= owner alive && mana (P1) ≥ GetManaCost && !stunned/silenced (HasState already works); IsCastable(ability, mana) honors the optional mana arg per umbrella ability.md. Prevents OOM cast spam.

**P18. Tower.GetAttackTarget — 8 calls.**
Reuse P8 cone-scan on the tower with its `m_iAttackRange` (0xCC8; tower KV ranges in npc_units.json) + activity check (P2). Restores tower-aggro detection for dive.lua:31, tower_safety.lua:21, Self Play.lua:439/490/529, last_hit.lua:88 (tower tank inference).

**P19. FogOfWar.IsPointVisible — 6 calls (semantics inverted).**
No FoW query surface in dumps (`m_FoWViewID` **0x12D8** is a per-unit viewer id, not a point query). Real fix: signature-scan client FoW manager (dumper task). Interim: return **true** — unblocks detection.lua:90, runes.lua:150, awareness.lua:147 which currently treat every point as unseen. Risk: bot may attempt wards/dewars on actually-unseen points; pair with NPC.IsDormant sanity where possible.

**P20. Trees cluster — 12 calls, ⚠ crash.**
Trees.InRadius: iterate `entity.iter()`, designerName match `ent_dota_tree` (verify exact name at runtime), 2-D radius filter, return **{}** not nil (fixes ipairs/# crashes in hoodwink/mars/timbersaw/tinker/ward_spots). Tree.IsActive → true fallback (C_DOTA_Tree not dumped; probe `m_bActive` via runtime schema). TempTrees: same scan over `ent_dota_temp_tree` candidates; Entity.GetTreesInRadius/GetTempTreesInRadius delegate. Hoodwink/Mars/Timbersaw/Tinker kits become functional.

### Runners-up (cheap, same pattern)
- NPC.GetAttackAnimPoint (9): KV `AttackAnimationPoint` (npc_units.json ✓ e.g. melee creep 0.467; heroes need re-dump).
- NPC.GetTimeToFace/Position (15): `|Δyaw| / (KV MovementTurnRate · π)` s — approximation, calibrate in-game (creep turn rate 0.5 in KV).
- NPC.GetAttackProjectileSpeed (2): KV `ProjectileSpeed`.
- Hero.GetPrimaryAttribute → `m_iPrimaryAttribute` **0x1B8C**; GetCurrentXP → `m_iCurrentXP` **0x1AC4**; GetReplicatingOtherHeroModel → `m_hReplicatingOtherHeroModel` **0x1B7C** → byHandle (SD+OJ).
- Ability.GetAutoCastState → `m_bAutoCastState` **0x644**; SecondsSinceLastUse → GameTime − `m_flCastStartTime` **0x650** (or `m_flLastCastClickTime` **0x6A0**); GetChannelStartTime → `m_flChannelStartTime` **0x64C** (OJ).
- GameRules.GetGoodGlyphCD/GetBadGlyphCD → `C_DOTAGamerules::m_fGoodGlyphCooldown` **0x5B8** / `m_fBadGlyphCooldown` **0x5BC** (SD) minus GameTime. IsPaused: no pause field in the 231-field dump → runtime-probe full class.
- NPC.IsInRangeOfShop → `m_iNearShopMask` **0x13EC** ≠ 0 (or `m_iCurShop` **0xE04**) (SD+OJ).
- NPC.IsControllableByPlayer → `m_iIsControllableByPlayer64` **0xCB8** bitmask `2^playerID` (SD+OJ).
- Player.GetQueryUnit → `m_hQueryUnit` **0x9FC**; GetAssignedHero → per-controller `m_hAssignedHero` **0x914** (SD+OJ).
- Couriers.GetLocal → `C_DOTA_PlayerResource::m_hPlayerCouriers` **0x2A20** / `m_hTeamCouriers` **0x28B8** (SD) handle arrays, match local playerID.
- NPC.GetBarriers (11): scan modifierList (already works) for barrier modifiers, sum via P14; interim zeros acceptable.
- NPC.GetModifierProperty (7) / GetStatesDuration (5): need modifier vtable property getters / per-state die-time min — larger effort; special-case `MODIFIER_PROPERTY_CREEP_DENY_PERCENT` by known modifier names first.
- Config persistence: flush cfgStore to JSON beside host.log (27 calls, low risk).

---

## 6. KV data gaps (block several "implemented" APIs)

| File | State | Consequence |
|---|---|---|
| gamedata/npc_abilities.json | **Partial**: 666 keys, only 105 with AbilityCastRange, **zero hero abilities** (lion_impale, nevermore_shadowraze1 absent) | Ability.GetCastRange/GetCastPoint/GetManaCost-fallback/GetDamage/GetBehavior/IsPassive/IsUltimate/GetLevelSpecialValueFor return 0 for hero spells → casting core effectively dead for heroes |
| gamedata/npc_heroes.json | **Empty `{}`** | hero AttackAnimationPoint/MovementTurnRate/primary attribute/base stats unavailable |
| gamedata/items.json | OK: 544 items with ItemCost etc. | P11 GetCost works |
| gamedata/npc_units.json | OK: creeps/neutrals/buildings with AttackRate, AttackAnimationPoint, MovementTurnRate, ArmorPhysical, BountyXP/Gold, AttackCapabilities | P3/P5/P6/P10/P15 unit-side works |
| gamedata/neutral_items.json | 4 KB — likely partial | verify before neutral-item logic |

Action: re-dump full `npc_abilities` + `npc_heroes` KV (dumper at D:\hake\lotus\dumper; xhelpers.lua already wraps root as DOTAAbilities, so api.lua needs no change). This is the single highest-leverage non-code fix.

---

## 7. Risk notes

- **R1 Build-specific RVAs**: PUO `0x1B5F860` (orders.lua:40), gamerules global `0x6219008` (entity.lua:45; OJ `dwLocalPlayerController`=0x6219008, `dwEntityList`=0x662FFE8). Field offsets are runtime-resolved (patch-resilient) but these RVAs are not — re-dump after every patch. Audit build: `987800-1dd55f3e8eed2d5` (Dota 7.41 per schema.lua header).
- **R2 Hardcoded offsets in api.lua** — 0xE30 (ModifierManager), 0x11C0+0x20 (Inventory.m_hItems), 0x12B8 (m_nUnitState64) — match current dumps but should move to `schema.offsetOf("C_DOTA_BaseNPC","m_ModifierManager"/"m_Inventory"/"m_nUnitState64")` for patch resilience.
- **R3 GameTime approximation** (api.lua:497): anchored on last order timestamp + wall clock; drifts while the bot sends no orders (idle/dead) → cooldowns, channels, modifier die-times mis-timed. Re-anchor from any fresh networked timestamp when possible.
- **R4 Silent soft-stubs**: api.lua `softIndex` returns 0/false/nil and logs once; loader `stubNS` returns nil for everything. Nil returns are actively dangerous: ⚠ arithmetic crashes (Modifier.GetDieTime ×7 files) and ipairs/# crashes (Trees.InRadius ×5, NPCs.InRadius objectives.lua:23). Because loader pcalls OnUpdate, one crash aborts the **entire tick**. Recommend type-safe defaults ({} for list getters, 0 for numeric) + per-key warning counter.
- **R5 Interim semantics tradeoffs**: FogOfWar→true and GridNav→true both "optimistic"; optimistic fog wastes ward attempts, optimistic gridnav walks into cliffs. Prefer conservative gridnav (P4a) and optimistic fog (P19) with logged assumptions.
- **R6 Team-data stride**: Player.GetTeamPlayer reads record stride 0x12F0 and field offsets (0x30 gold etc.) that no dump covers; the vector field name itself is wrong (§3). Verify live before trusting gold/lasthit stats.
- **R7 Order path**: Present-hook queue disabled (orders.lua:28, black-screen on this build); orders issued from bot thread — keep PUO calls off the render thread. `Enum.UnitOrder` values verified against enums.lua (1/4/5/6/8/9/10/21).
- **R8 Entity.IsDormant heuristic** (identity flags 0x30, `%0x100 ≥ 0x80`) and NPC.IsVisible=not-dormant are approximations of Umbrella semantics; dormant ≠ invisible-to-enemies.
- **R9 Ability.GetCastRange** ignores +cast-range modifiers/talents even after KV re-dump (KV is base only); add modifier scan later.
- **R10 No runtime verification performed** (per audit constraints): all offsets cited from the two dumps/KV; P14 modifier fields and P8/P18 composites need one live calibration pass before trusting.

---

## 8. Suggested execution order

1. **Same-day one-liners**: P1 (mana), P7 (recent damage), P15 flags, P13/P6 armor multipliers, P5 attack timing, P10 IsRanged, P3 range bonus, §3 team-data field name, P11 item cluster, runners-up ability fields. (~250 call sites fixed, all offset-backed.)
2. **Crash guards**: P14 fallbacks + P20 {} returns + NPCs.InRadius implementation (radius scan over NPCs.GetAll) — stops tick aborts.
3. **Data re-dump**: full npc_abilities + npc_heroes (§6) — unlocks hero casting core.
4. **Composites**: P2+P8+P18 (activity/cone), P17 mana gate, P12 latency approximation.
5. **Dumper extensions**: P4 gridnav, P9 ground trace, P19 FoW, P14 modifier class dump.
