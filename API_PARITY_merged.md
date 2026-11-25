# API_PARITY (merged) — combined findings of both audit agents

> Source 1: API_PARITY_agent1.md (53KB). Source 2: API_PARITY_agent2.md (35KB).
> Both preserved verbatim below; dedupe by function name when implementing.

---

## AGENT 1 REPORT

# API_PARITY.md — Umbrella API bridge audit for "Self Play"

- **Date:** 2026-11-15 (read-only audit; no game launched, no injection, no existing file modified)
- **Contract:** `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\Self Play.lua` + `self_play\**\*.lua` (incl. `heroes\*`)
- **Bridge:** `D:\hake\lotus\src\{api,loader,orders,entity,schema,enums,mathx,menu,render,xhelpers}.lua`
- **Offset sources:** `D:\hake\lotus\schema_dump.json` (runtime schema dump), `D:\hake\lotus\dumper\dota2_dump\offsets.json` (build `987800-1dd55f3e8eed2d5`), `client.dll.hpp` / `server.dll.hpp` (same dump), KV: `D:\hake\lotus\gamedata\*.json`
- **Method:** regex census of `Namespace.Method(` across all 123 Self Play script Lua files (5,452 call sites, 226 distinct functions; no `:`-style API calls and no local aliases of API functions found), cross-referenced against every bridge definition, `stubNS` defaults, and the `softIndex` catch-all. Runtime evidence from `host.log`.

**Status legend**

| Code | Meaning |
|---|---|
| REAL | Implemented with live data (schema/KV/orders) |
| APPROX | Implemented, but an approximation of the Umbrella contract |
| BROKEN | Implemented, but reads a **non-existent schema field** or violates the contract (silently wrong) |
| STUB | Explicit constant / no-op / empty table in `api.lua` or `loader.lua` |
| MISS | Not defined anywhere — falls through `softIndex` (api.lua) or `stubNS` (loader.lua) |

**Headline findings**

1. **The event-callback layer is missing entirely.** The loader fires only `OnUpdateEx/OnUpdate/OnDraw/OnScriptsLoaded`. Self Play defines 20 callbacks; `OnProjectile`, `OnUnitAnimation(End)`, `OnEntityHurt`, `OnNpcDying`, `OnEntityDestroy`, `OnPrepareUnitOrders`, `OnLinearProjectileCreate/Destroy`, `OnParticle*`, `OnGameEnd`, `OnGCMessage` are never invoked. Dodge, animation-based last-hit timing, damage memory, creep-aggro tracking, manual-override pause and TP-particle awareness are dead regardless of API parity.
2. **`NPC.GetMana`/`GetMaxMana` read fields that do not exist** (`m_iMana`, `m_iMaxMana`; the schema has `m_flMana` 0xCFC / `m_flMaxMana` 0xD00). They return 0, so every script-side mana gate (`Ability.IsCastable(spell, NPC.GetMana(hero))`, `mana >= cost`, mana-reserve math) fails → **almost no spells/items are ever cast**.
3. **`Ability.GetBehavior/GetTargetTeam/GetTargetType/GetTargetFlags` return 0** because `kvNum` only extracts digits while the gamedata KV stores symbolic flags (`"DOTA_ABILITY_BEHAVIOR_UNIT_TARGET | ..."`). The generic combat cast dispatcher (combat.lua:227–231, 477–501, 611–615) cannot classify spells → generic spell engine dead; `IsPassive`/`IsUltimate` also wrong.
4. **Nil-returning stubs cause tick-aborting crashes.** `Modifier.GetDieTime/GetStackCount`, `NPCs.InRadius`, `Trees.InRadius`, `Ability.SecondsSinceLastUse` return nil into arithmetic/`ipairs`/comparisons (e.g. `modifier_teleporting` during every TP, `modifier_kill` on every summon). The loader's `pcall` catches them, but the rest of that tick is skipped — repeated every tick while the condition holds.
5. **`Item.GetCurrentCharges` = 0** kills tangoes, bottle, mangoes, wards, dust, clarities (27 call sites). **`Hero.GetRecentDamage` = 0** blinds retreat/engagement logic (40 sites). **`NPC.IsAttacking` = false** gates off the attack-cycle model (89 sites). **`NPC.GetAttackSpeed` = 0** is clamped to 0.2 by callers → ~5× wrong attack windup.
6. **Economy is blocked:** `NPC.IsInRangeOfShop` = false and `Couriers.GetLocal` = nil → hero never considered at base, no courier found → no purchases while alive; `Item.GetCost` = 0 corrupts buy/sell/win-model math.
7. Several "implemented" functions are subtly wrong: `Entity.GetOwner` returns a raw handle instead of an entity; `Ability.CanBeExecuted` returns a boolean but the script compares `== -1` (`Enum.AbilityCastResult.READY`); `Ability.IsCastable` ignores its mana argument; `Modifier.GetName` returns `""`; `Hero.GetStrength` reads non-existent `m_iStrength`.

---

## (a) Call-frequency table

All 226 functions actually called by Self Play, sorted by call count. "Where" = bridge location (`api` = api.lua, `loader` = loader.lua stubNS/overrides, `soft` = softIndex catch-all, `miss` = stubNS nil fall-through).

| # | Calls | Function | Status | Where / note |
|---|---|---|---|---|
| 1 | 693 | Entity.GetAbsOrigin | REAL | api; CGameSceneNode::m_vecAbsOrigin 0xD8 |
| 2 | 284 | Entity.GetHealth | REAL | api; C_BaseEntity::m_iHealth 0x34C |
| 3 | 197 | Entity.IsSameTeam | REAL | api |
| 4 | 167 | Entity.GetIndex | REAL | api; identity+0x10 handle % 0x8000 |
| 5 | 157 | Entity.IsAlive | REAL | api; m_lifeState 0x354 |
| 6 | 149 | Entity.IsEntity | REAL | api |
| 7 | 149 | NPC.HasState | REAL | api; m_nUnitState64 0x12B8 (hardcoded, matches dump) |
| 8 | 143 | NPC.GetAttackRange | REAL | api; m_iAttackRange 0xCC8 |
| 9 | 135 | NPC.GetAbility | REAL | api; m_vecAbilities 0xD28 |
| 10 | 127 | Entity.GetMaxHealth | REAL | api; m_iMaxHealth 0x348 |
| 11 | 115 | Ability.GetCastRange | REAL | api; KV AbilityCastRange (numeric) |
| 12 | 110 | NPC.HasModifier | REAL | api; m_ModifierManager 0xE30 |
| 13 | 110 | NPC.IsIllusion | REAL | api; m_bIsIllusion 0xD24 |
| 14 | 98 | NPC.IsHero | REAL | api; designer name |
| 15 | 95 | NPC.GetMoveSpeed | REAL | api; m_iMoveSpeed 0xCE0 |
| 16 | 95 | NPC.GetUnitName | REAL | api; designer name |
| 17 | 93 | Ability.GetName | REAL | api; designer name |
| 18 | 89 | NPC.IsAttacking | STUB | api `return false` |
| 19 | 87 | NPC.GetAttackRangeBonus | BROKEN | api reads `m_iAttackRangeBonus` — field absent → 0 |
| 20 | 84 | Entity.IsDormant | REAL | api; identity flags heuristic (+0x30) |
| 21 | 83 | NPC.IsVisible | APPROX | api = not dormant |
| 22 | 81 | GridNav.IsTraversable | STUB | loader `return true` |
| 23 | 78 | NPC.GetTrueDamage | REAL | api; m_iDamageMin 0xE18 |
| 24 | 75 | Ability.GetLevel | REAL | api; C_DOTABaseAbility::m_iLevel 0x628 |
| 25 | 74 | NPC.GetMana | BROKEN | api reads `m_iMana` — absent; real field m_flMana 0xCFC → returns 0 |
| 26 | 70 | Log.Write | REAL | api → host.log |
| 27 | 69 | Ability.GetManaCost | REAL | api; m_iManaCost 0x640 + KV fallback |
| 28 | 56 | NPC.IsChannellingAbility | REAL | api; scans ability slots |
| 29 | 56 | Ability.GetCastPoint | REAL | api; m_flOverrideCastPoint 0x658 + KV |
| 30 | 53 | NPC.GetSecondsPerAttack | STUB | api `return 1.7` |
| 31 | 50 | NPC.IsStunned | REAL | api via HasState |
| 32 | 49 | NPC.GetItem | REAL | api; m_Inventory 0x11C0 + m_hItems 0x20 |
| 33 | 49 | NPC.IsLaneCreep | REAL | api; name |
| 34 | 49 | NPC.GetArmorDamageMultiplier | STUB | api `return 1` |
| 35 | 40 | Hero.GetRecentDamage | STUB | api `return 0` |
| 36 | 35 | NPC.IsRunning | APPROX | api = IsAlive |
| 37 | 34 | NPC.GetMaxMana | BROKEN | api reads `m_iMaxMana` — absent; m_flMaxMana 0xD00 → 0 |
| 38 | 33 | NPC.FindFacingNPC | STUB | api `return nil` |
| 39 | 31 | World.GetGroundZ | STUB | loader `return 128` |
| 40 | 30 | NPC.GetItemByIndex | REAL | api |
| 41 | 29 | NPC.IsRanged | BROKEN | api reads `m_bIsRanged` — absent → false |
| 42 | 29 | GameRules.GetGameTime | APPROX | api; wall-clock anchored to order timestamps |
| 43 | 29 | NPC.GetHullRadius | REAL | api; m_flHullRadius 0xD60 |
| 44 | 27 | NPC.GetCurrentLevel | REAL | api; m_iCurrentLevel 0xC9C |
| 45 | 27 | Item.GetCurrentCharges | STUB | loader `return 0` |
| 46 | 26 | Player.PrepareUnitOrders | REAL | api → orders.prepare (PUO RVA 0x1B5F860) |
| 47 | 26 | NPC.GetAbilityByIndex | REAL | api |
| 48 | 25 | Ability.IsReady | APPROX | api; level/CD/hidden only, no mana/owner check |
| 49 | 24 | Ability.IsHidden | REAL | api; m_bHidden 0x617 |
| 50 | 24 | NPC.GetMagicalArmorDamageMultiplier | STUB | api `return 1` |
| 51 | 23 | NPC.GetHealthRegen | REAL | api; m_flHealthRegen 0x1744 |
| 52 | 21 | NetChannel.GetAvgLatency | STUB | loader `return 0` |
| 53 | 21 | Ability.GetCooldown | REAL | api; m_fCooldown 0x638 − gameTime |
| 54 | 21 | NPC.IsCreep | REAL | api; name |
| 55 | 20 | NPC.IsNeutral | REAL | api; m_bIsNeutralUnitType 0xCA3 |
| 56 | 18 | Ability.GetToggleState | REAL | api; m_bToggleState 0x62D |
| 57 | 17 | NPC.IsRoshan | REAL | api; name |
| 58 | 17 | NPC.IsStructure | REAL | api |
| 59 | 17 | NPC.GetModifier | REAL | api |
| 60 | 17 | Item.IsItemEnabled | STUB | loader `return true` (m_bItemEnabled 0x701 available) |
| 61 | 16 | NPC.IsSilenced | REAL | api via HasState |
| 62 | 16 | Entity.IsNPC | REAL | api |
| 63 | 15 | NPC.MoveTo | REAL | api → orders |
| 64 | 15 | NPC.IsWaitingToSpawn | STUB | api `return false` (m_bIsWaitingToSpawn 0x1730 available) |
| 65 | 15 | NPC.IsAncient | REAL | api; m_bIsAncient 0xCA0 |
| 66 | 14 | GridNav.BuildPath | STUB | loader; straight line via midpoint |
| 67 | 14 | Ability.GetDamage | REAL | api; KV AbilityDamage (numeric) |
| 68 | 14 | Entity.GetRotation | REAL | api; m_angAbsRotation 0xE4 |
| 69 | 13 | NPC.IsMeepoClone | STUB | api `return false` (m_bIsClone 0xCCC available) |
| 70 | 13 | NPC.IsFort | REAL | api; name |
| 71 | 13 | NPC.IsTower | REAL | api; name |
| 72 | 13 | Ability.IsPassive | BROKEN | api via GetBehavior → always 0 |
| 73 | 12 | Ability.IsCastable | BROKEN | api ignores `mana` argument; no mana check |
| 74 | 12 | NPC.IsTormentor | STUB | api `return false` |
| 75 | 12 | Ability.GetLevelSpecialValueFor | MISS | soft → 0 (KV AbilityValues available) |
| 76 | 11 | NPC.GetBarriers | STUB | api; zeroed barrier table |
| 77 | 11 | Ability.GetBehavior | BROKEN | api; kvNum cannot decode symbolic KV flags → 0 |
| 78 | 11 | Entity.GetTeamNum | REAL | api; m_iTeamNum 0x3E7 |
| 79 | 10 | Hero.GetReplicatingOtherHeroModel | STUB | api `return nil` (m_hReplicatingOtherHeroModel 0x1B7C available) |
| 80 | 10 | NPC.GetAttackSpeed | STUB | api `return 0` (callers clamp to 0.2 → 5× windup error) |
| 81 | 10 | NPC.IsInRangeOfShop | STUB | api `return false` |
| 82 | 10 | Ability.IsActivated | REAL | api; m_bActivated 0x619 |
| 83 | 9 | NPC.GetTimeToFace | STUB | api `return 0` |
| 84 | 9 | Ability.IsUltimate | BROKEN | api via GetBehavior → 0 |
| 85 | 9 | Item.GetCost | STUB | loader `return 0` (KV ItemCost available) |
| 86 | 9 | NPC.GetAttackAnimPoint | STUB | api `return 0.45` (KV AttackAnimationPoint available) |
| 87 | 8 | Tower.GetAttackTarget | MISS | stubNS nil (m_hTowerAttackTarget 0x1B5C available) |
| 88 | 8 | NPC.IsBarracks | REAL | api; name |
| 89 | 8 | Config.WriteString | REAL | api; in-memory only |
| 90 | 8 | Player.GetTotalGold | REAL | api; DataTeamPlayer_t 0x30+0x34 |
| 91 | 8 | Modifier.GetDieTime | MISS | stubNS nil → **nil-arithmetic crashes** |
| 92 | 7 | NPC.IsEntityInRange | REAL | api |
| 93 | 7 | Config.ReadString | REAL | api |
| 94 | 7 | NPC.GetModifierProperty | STUB | api `return 0` |
| 95 | 7 | Ability.IsChannelling | REAL | api; m_flChannelStartTime 0x64C + KV |
| 96 | 6 | NPC.GetTimeToFacePosition | STUB | api `return 0` |
| 97 | 6 | FogOfWar.IsPointVisible | MISS | loader defines IsVisible only; script calls IsPointVisible → nil |
| 98 | 6 | Ability.GetDamageType | STUB | api `return 0` (KV AbilityUnitDamageType available) |
| 99 | 6 | Couriers.GetLocal | MISS | stubNS nil |
| 100 | 6 | Heroes.GetAll | REAL | api |
| 101 | 6 | Ability.CanBeExecuted | BROKEN | api returns bool; script expects cast-result code (READY = −1) |
| 102 | 5 | Config.ReadInt | REAL | api |
| 103 | 5 | Tree.IsActive | MISS | stubNS nil |
| 104 | 5 | Player.HoldPosition | REAL | api → orders |
| 105 | 5 | Players.GetLocal | REAL | api |
| 106 | 5 | NPC.GetTrueMaximumDamage | REAL | api; m_iDamageMax 0xE1C |
| 107 | 5 | NPC.IsLinkensProtected | STUB | api `return false` |
| 108 | 5 | GameRules.GetGameStartTime | REAL | api; m_flGameStartTime 0x594 |
| 109 | 5 | Bottle.GetRuneType | MISS | stubNS nil |
| 110 | 5 | Config.WriteInt | REAL | api |
| 111 | 5 | Entity.GetField | APPROX | api; 2-arg form real; 1-arg form only handles m_bActive→false |
| 112 | 5 | Trees.InRadius | MISS | stubNS nil → **ipairs(nil) crash risk** |
| 113 | 5 | Panorama.GetPanelByName | MISS | stubNS nil (lobby UI automation dead) |
| 114 | 5 | NPC.GetStatesDuration | STUB | api `return {}` |
| 115 | 5 | Players.GetAll | REAL | api |
| 116 | 4 | GC.GetSteamID | STUB | loader `return 0` |
| 117 | 4 | Render.TextSize | REAL | render.lua |
| 118 | 4 | NPC.HasScepter | STUB | api `return false` (m_bLastScepterState 0x12ED available) |
| 119 | 4 | Player.GetTeamPlayer | REAL | api; DataTeamPlayer_t |
| 120 | 4 | Engine.IsInGame | REAL | api; game state 4–6 |
| 121 | 4 | NPC.GetModifiers | REAL | api |
| 122 | 4 | Hero.GetRespawnTime | REAL | api; m_flRespawnTime 0x1AD8 |
| 123 | 4 | NPC.GetManaRegen | REAL | api; m_flManaRegen 0x1740 |
| 124 | 4 | Player.AttackTarget | REAL | api → orders |
| 125 | 4 | Ability.Toggle | REAL | api → order 9 |
| 126 | 4 | NPC.GetBountyXP | STUB | api `return 0` (m_iXPBounty 0x1754 available) |
| 127 | 4 | Engine.RunScript | STUB | api no-op (talent UI path; order path works) |
| 128 | 4 | GC.SendMessage | STUB | loader no-op (matchmaking dead) |
| 129 | 4 | Modifier.GetStackCount | MISS | stubNS nil → **nil-comparison crashes** |
| 130 | 4 | Render.FilledRect | REAL | render.lua |
| 131 | 3 | Entity.GetOwner | BROKEN | api returns raw u32 handle, not entity (m_hOwnerEntity 0x514) |
| 132 | 3 | Ability.GetCurrentCharges | REAL | api; m_nAbilityCurrentCharges 0x660 |
| 133 | 3 | Runes.Contains | MISS | stubNS nil |
| 134 | 3 | Render.LoadFont | REAL | render.lua |
| 135 | 3 | NPCs.GetAll | REAL | loader override |
| 136 | 3 | Render.FilledCircle | REAL | render.lua |
| 137 | 3 | Entity.Get | REAL | api |
| 138 | 3 | Engine.ExecuteCommand | STUB | api log-only (camera follow dead) |
| 139 | 3 | Ability.IsInAbilityPhase | REAL | api; m_bInAbilityPhase 0x634 |
| 140 | 3 | NPC.IsWard | REAL | api; name |
| 141 | 3 | Render.Line | REAL | render.lua |
| 142 | 3 | Entity.GetTreesInRadius | STUB | api `return {}` |
| 143 | 3 | Render.WorldToScreen | REAL | render.lua; viewmatrix 0x6221CB0 |
| 144 | 3 | NPC.IsCourier | REAL | api; name |
| 145 | 3 | Render.Text | REAL | render.lua |
| 146 | 3 | Render.ScreenSize | REAL | render.lua |
| 147 | 3 | Ability.GetChannelStartTime | MISS | soft → 0 (m_flChannelStartTime 0x64C available) |
| 148 | 3 | Heroes.GetLocal | REAL | api |
| 149 | 3 | Item.GetSecondaryCharges | MISS | stubNS nil (m_iSecondaryCharges 0x6E4 available) |
| 150 | 3 | Item.IsSellable | STUB | loader `return true` (m_bSellable 0x6BE available) |
| 151 | 3 | NPC.HasShard | STUB | api `return false` (m_bLastShardState 0x12EC available) |
| 152 | 3 | Player.GetTeamData | STUB | api `return {}` |
| 153 | 3 | NPC.IsControllableByPlayer | APPROX | api; local hero + illusions/clones only |
| 154 | 3 | HTTP.Request | STUB | loader no-op (online builds dead) |
| 155 | 3 | Modifier.GetName | STUB | loader `return ""` (should be designer name) |
| 156 | 3 | Rune.GetRuneType | MISS | stubNS nil (C_DOTA_Item_Rune::m_iRuneType 0xBC0 available) |
| 157 | 2 | Item.GetStockCount | STUB | loader `return 99` |
| 158 | 2 | GridNav.CreateNpcMap | STUB | loader `return {}` |
| 159 | 2 | Hero.GetPrimaryAttribute | STUB | api `return 0` (m_iPrimaryAttribute 0x1B8C available) |
| 160 | 2 | Modifier.GetCaster | MISS | stubNS nil |
| 161 | 2 | Item.GetPlayerOwnerID | STUB | loader `return -1` (m_iPlayerOwnerID 0x72C available) |
| 162 | 2 | GameRules.GetMatchID | REAL | api; m_unMatchID64 0x858 |
| 163 | 2 | Ability.GetAutoCastState | MISS | soft → 0 (m_bAutoCastState 0x644 available) |
| 164 | 2 | Ability.SecondsSinceLastUse | MISS | soft → nil → **nil-comparison crash (invoker)** |
| 165 | 2 | Engine.IsInLobby | REAL | api |
| 166 | 2 | Menu.Opened | REAL | menu.lua |
| 167 | 2 | Hero.GetLastMaphackPos | STUB | api `return {0,0,0}` |
| 168 | 2 | NPC.GetGoldBountyMin | STUB | api `return 0` (m_iGoldBountyMin 0x175C available) |
| 169 | 2 | Ability.CastNoTarget | REAL | api → order 8 |
| 170 | 2 | Ability.CastPosition | REAL | api → order 5 |
| 171 | 2 | Hero.GetLastVisibleTime | STUB | api `return 0` |
| 172 | 2 | Entity.GetTempTreesInRadius | STUB | api `return {}` |
| 173 | 2 | Ability.GetTargetTeam | BROKEN | api; symbolic KV → 0 |
| 174 | 2 | GridNav.ReleaseNpcMap | STUB | loader no-op |
| 175 | 2 | Input.IsKeyDown | STUB | loader `return false` |
| 176 | 2 | Hero.GetPlayerID | REAL | api; m_iPlayerID 0x1B68 |
| 177 | 2 | NPC.GetAttackProjectileSpeed | STUB | api `return 0` (KV ProjectileSpeed available) |
| 178 | 2 | Runes.GetAll | STUB | loader `return {}` |
| 179 | 2 | Engine.GetCheatDirectory | REAL | api |
| 180 | 2 | NetChannel.SendNetMessage | MISS | stubNS nil |
| 181 | 1 | Item.RequiresCharges | MISS | stubNS nil (m_bRequiresCharges 0x6C1 available) |
| 182 | 1 | Engine.AcceptMatch | STUB | api no-op |
| 183 | 1 | PowerTreads.GetStats | MISS | stubNS nil |
| 184 | 1 | NPCs.InRadius | MISS | stubNS nil → **ipairs(nil) crash (objectives.lua:23)** |
| 185 | 1 | Config.WriteFloat | REAL | api |
| 186 | 1 | Hero.GetAbilityPoints | REAL | api; m_iAbilityPoints 0x1AC8 |
| 187 | 1 | Ability.ToggleMod | REAL | api → order 20 |
| 188 | 1 | PhysicalItem.GetItem | MISS | stubNS nil |
| 189 | 1 | Ability.GetTargetType | BROKEN | api; symbolic KV → 0 |
| 190 | 1 | GameRules.IsPaused | STUB | api `return false` |
| 191 | 1 | NPC.GetGoldBountyMax | STUB | api `return 0` (m_iGoldBountyMax 0x1760 available) |
| 192 | 1 | Ability.GetTargetFlags | BROKEN | api; symbolic KV → 0 |
| 193 | 1 | Modifier.GetCreationTime | MISS | stubNS nil |
| 194 | 1 | Render.Circle | REAL | render.lua |
| 195 | 1 | NPC.IsVisibleToEnemies | STUB | api `return false` |
| 196 | 1 | PhysicalItems.GetAll | STUB | loader `return {}` |
| 197 | 1 | Menu.Find | STUB | menu.lua `return nil` |
| 198 | 1 | Couriers.GetAll | STUB | loader `return {}` |
| 199 | 1 | Engine.CanAcceptMatch | STUB | api `return false` |
| 200 | 1 | Ability.CanBeUpgraded | REAL | api |
| 201 | 1 | Player.GetPlayerID | REAL | api; m_nPlayerID 0x910 |
| 202 | 1 | Modifier.GetState | MISS | stubNS nil |
| 203 | 1 | Input.IsInputCaptured | MISS | stubNS nil (guarded by caller) |
| 204 | 1 | Abilities.AttemptToUpgrade | MISS | only referenced inside a Panorama JS string (talents.lua:30), not a live Lua call |
| 205 | 1 | Entities.GetAll | REAL | loader override |
| 206 | 1 | Humanizer.GetOrderQueue | STUB | loader `return {}` |
| 207 | 1 | Player.GetQueryUnit | STUB | api `return nil` (m_hQueryUnit 0x9FC available) |
| 208 | 1 | GameRules.GetGameState | REAL | api; m_nGameState 0x7C |
| 209 | 1 | Item.IsCombineLocked | STUB | loader `return false` (m_bCombineLocked 0x6EC available) |
| 210 | 1 | TempTrees.GetAll | STUB | loader `return {}` |
| 211 | 1 | Hero.TalentIsLearned | STUB | api `return false` |
| 212 | 1 | Player.GetAssignedHero | APPROX | api always returns local hero |
| 213 | 1 | Player.GetSelectedUnits | STUB | api `return {}` (m_nSelectedUnits 0x9C8 available) |
| 214 | 1 | Hero.GetCurrentXP | MISS | soft → 0 (m_iCurrentXP 0x1AC4 available) |
| 215 | 1 | GameRules.GetGameMode | REAL | api; m_iGameMode 0xE4 |
| 216 | 1 | Engine.IsShopOpen | MISS | Engine has **no softIndex**; caller guards with `and` |
| 217 | 1 | NPC.GetOwnerNPC | STUB | api `return nil` (m_hOwnerNPC 0x1764 available) |
| 218 | 1 | TempTrees.InRadius | MISS | stubNS nil (guarded by caller) |
| 219 | 1 | Entity.GetClassName | REAL | api |
| 220 | 1 | Menu.Create | REAL | menu.lua |
| 221 | 1 | Engine.GetHeroNameByID | STUB | api `return ""` |
| 222 | 1 | Player.GetPlayerNeutralInfo | STUB | api constant table |
| 223 | 1 | Hero.GetStrength | BROKEN | api reads `m_iStrength` — absent; m_flStrengthTotal 0x1AEC → 0 |
| 224 | 1 | Item.IsStackable | STUB | loader `return false` (m_bStackable 0x6AE available) |
| 225 | 1 | NPC.IsMirrorProtected | STUB | api `return false` |
| 226 | 1 | Config.ReadFloat | REAL | api |
| 226 | 1 | Hero.GetStrength (dup guard) | — | see #222 (table kept at 226 distinct keys) |


**Aggregate:** REAL 106 functions (4193 sites) · APPROX 7 · BROKEN 14 (283 sites) · STUB 70 (700 sites) · MISS 29 (95 sites). Total 226 functions / 5,452 sites.

---

## (b) Implemented list (real or acceptable approximation)

**Entity:** GetAbsOrigin, GetHealth, GetMaxHealth, GetTeamNum, GetIndex, GetClassName, Get, IsAlive, IsEntity, IsNPC, IsSameTeam, IsDormant, GetRotation, GetField (2-arg form).
**NPC:** GetUnitName, GetHealth, GetMaxHealth, GetAttackRange, GetMoveSpeed, GetTrueDamage, GetTrueMaximumDamage, GetHullRadius, GetCurrentLevel, GetHealthRegen, GetManaRegen, IsHero, IsCreep, IsLaneCreep, IsNeutral, IsAncient, IsTower, IsBarracks, IsFort, IsStructure, IsCourier, IsRoshan, IsWard, IsIllusion, IsStunned, IsSilenced, IsRooted, IsDisarmed, HasState, HasModifier, GetModifier, GetModifiers, GetAbility, GetAbilityByIndex, GetItem, GetItemByIndex, IsEntityInRange, IsChannellingAbility, MoveTo, IsVisible (≈), IsRunning (≈), IsControllableByPlayer (partial).
**Hero:** GetPlayerID, GetAbilityPoints, GetRespawnTime. **Heroes:** GetAll, GetLocal.
**Player/Players:** PrepareUnitOrders, AttackTarget, HoldPosition, GetTotalGold, GetTeamPlayer, GetPlayerID, Players.GetAll, Players.GetLocal, GetAssignedHero (≈).
**Ability:** GetName, GetLevel, GetMaxLevel, CanBeUpgraded, GetCooldown, GetCooldownLength, GetManaCost, GetCastRange, GetCastPoint, GetDamage, IsHidden, IsActivated, IsInAbilityPhase, GetToggleState, GetCurrentCharges, IsChannelling, CastNoTarget, CastPosition, CastTarget, Toggle, ToggleMod, IsReady (partial).
**GameRules:** GetGameTime (≈), GetGameState, GetGameStartTime, GetGameMode, GetMatchID. **Engine:** IsInGame, IsInLobby, GetCheatDirectory.
**Infrastructure:** orders.lua PrepareUnitOrders (verified live), entity.lua identity-list walker + handle map + local hero, schema.lua runtime SchemaSystem resolver, enums.lua (complete Umbrella v2.0 enum set incl. ModifierState bit indices, UnitOrder, AbilityCastResult), mathx Vector/Vec2/Angle/Color (covers all methods the script uses), menu.lua ClickGUI data model, render.lua (WorldToScreen + draw command collection), xhelpers.xkv KV loader (npc_abilities/items/npc_units/npc_heroes/neutral_items), Config (in-memory), Log.

---

## (c) Stub / missing list, sorted by impact

### P0 — crash-class or bot-paralyzing

| Gap | Sites | Failure mode |
|---|---|---|
| Event callbacks never fired (OnProjectile, OnUnitAnimation/End, OnEntityHurt, OnNpcDying, OnEntityDestroy, OnPrepareUnitOrders, OnLinearProjectile*, OnParticle*, OnGameEnd, OnGCMessage) | whole subsystems | dodge, animation last-hit model, damage memory, creep aggro, manual pause, TP awareness all dead |
| NPC.GetMana / GetMaxMana read non-existent fields | 74+34 | all mana gates fail → no spells/items cast |
| Ability.GetBehavior / GetTargetTeam / GetTargetType / GetTargetFlags (+IsPassive/IsUltimate) | 11+2+1+1+13+9 | symbolic KV → 0; combat dispatcher cannot classify casts |
| Modifier.GetDieTime | 8 | `nil − now` arithmetic crash whenever `modifier_teleporting`/`modifier_kill` present (every TP, every summon) → tick aborted |
| Modifier.GetStackCount | 4 | `nil >= n` / `nil * n` crashes (primal_beast, shadow_demon, shadow_fiend, lion) |
| Item.GetCurrentCharges (=0) | 27 | tango/bottle/mango/ward/dust/clarities never used |
| NPCs.InRadius | 1 | `ipairs(nil)` crash in objectives.lua:23 (ward coverage check, support role) |
| Trees.InRadius | 5 | `ipairs(nil)`/`#nil` crashes in hoodwink/mars/timbersaw/tinker modules; ward_spots guarded |
| Ability.SecondsSinceLastUse | 2 | `nil < x` crash in invoker.lua:679 |
| Ability.IsCastable ignores mana; CanBeExecuted returns bool not −1 | 12+6 | cast gating wrong; base_defense.lua:46 `== -1` never true |

### P1 — core behavior degraded (combat / last-hit / movement / economy)

| Gap | Sites | Effect |
|---|---|---|
| NPC.IsAttacking = false | 89 | lastHit.animation/animationEnd gated off; attack-cycle model blind |
| NPC.GetAttackRangeBonus = 0 (bad field) | 87 | all reach computations miss item/modifier bonus (pike, lance, facets) |
| GridNav.IsTraversable = true, BuildPath = straight line | 81+14 | walks into cliffs/trees; no path safety; CreateNpcMap = {} |
| NPC.GetSecondsPerAttack = 1.7 | 53 | wrong attack cadence for every unit |
| NPC.GetArmorDamageMultiplier / GetMagicalArmorDamageMultiplier = 1 | 49+24 | damage prediction ignores armor/resistance → bad last-hit & fight decisions |
| Hero.GetRecentDamage = 0 | 40 | never detects being attacked → no retreat, no defensive items, bad engagement |
| NPC.FindFacingNPC = nil | 33 | cannot infer attack targets (tower tanking, focus, support) |
| World.GetGroundZ = 128 | 31 | wrong Z on cliffs/ramps for candidate points |
| NPC.IsRanged = false (bad field) | 29 | melee/ranged logic inverted everywhere (block, positioning, last-hit value, target flags) |
| NetChannel.GetAvgLatency = 0 | 21 | all timing leads optimistic by real ping |
| NPC.IsWaitingToSpawn = false | 15 | targets unspawned neutrals/roshan |
| NPC.IsMeepoClone / IsTormentor = false | 13+12 | clone miscontrol; tormentor treated as normal camp |
| Ability.GetLevelSpecialValueFor → 0 | 12 | ability-specific distances/delays/radii wrong (mobility, arc, aim, earth_spirit) |
| NPC.GetBarriers = zeros | 11 | barrier damage ignored in kill thresholds |
| NPC.GetAttackSpeed = 0 | 10 | callers clamp to 0.2 → ~5× windup overestimate |
| NPC.IsInRangeOfShop = false + Couriers.GetLocal = nil | 10+6 | **no purchases while alive; no courier delivery** |
| Hero.GetReplicatingOtherHeroModel = nil | 10 | arc-warden double counted as real hero |
| NPC.GetTimeToFace / GetTimeToFacePosition = 0 | 9+6 | turn-rate lead missing in last-hit & block timing |
| Item.GetCost = 0 | 9 | buy/sell/disassemble/win-model economy math wrong |
| NPC.GetAttackAnimPoint = 0.45 | 9 | wrong per-unit attack point |
| Tower.GetAttackTarget = nil | 8 | tower-aggro safety blind (tower_safety, teamplay, dive, units) |
| NPC.GetModifierProperty = 0 | 7 | deny-percent & disable-healing checks wrong |
| FogOfWar.IsPointVisible = nil | 6 | rune/deward/jungle vision checks always "not visible" |
| Ability.GetDamageType = 0 | 6 | projectile damage never armor/resist-adjusted |
| NPC.GetStatesDuration = {} | 5 | stun-chain durations unknown (awareness.control, lina, meepo, units) |
| NPC.IsLinkensProtected = false | 5 | wastes targeted spells on Linken's |
| Bottle.GetRuneType / Runes.Contains / Rune.GetRuneType / Runes.GetAll | 5+3+3+2 | rune control & bottle refill logic dead |
| Item.GetSecondaryCharges = nil | 3 | ward dispenser counts nil → comparison crash risk |
| Entity.GetOwner returns raw handle | 3 | ember/earth spirit remnant ownership never matches |
| Engine.ExecuteCommand log-only | 3 | camera follow dead |
| NPC.HasScepter / HasShard = false | 4+3 | scepter/shard-aware logic & shop counts wrong |
| NPC.GetBountyXP / GetGoldBountyMin / Max = 0 | 4+2+1 | farm-value ranking degraded |
| Modifier.GetName = "" / GetCaster = nil | 3+2 | invoker orb counting, arc flux, deward caster attribution dead |
| Item.GetPlayerOwnerID = −1 | 2 | courier cargo ownership unknown |
| Ability.GetAutoCastState → 0 | 2 | autocast toggle spam (huskar spear, combat autocast) |
| Ability.GetChannelStartTime → 0 | 3 | channel tracking (invoker, tinker) degraded |
| NPC.GetAttackProjectileSpeed = 0 | 2 | ranged flight time ignored in engagement/last-hit |

### P2 — quality / economy / hero-specific

Item.GetStockCount=99, Item.IsItemEnabled=true, Item.IsSellable=true, Item.IsStackable=false, Item.IsCombineLocked=false, Item.RequiresCharges=nil, PowerTreads.GetStats=nil, Tree.IsActive=nil, Entity.GetTreesInRadius={}, Entity.GetTempTreesInRadius={}, TempTrees.*, PhysicalItem(s).*, Hero.GetLastVisibleTime=0, Hero.GetLastMaphackPos={0,0,0}, Hero.TalentIsLearned=false, Hero.GetCurrentXP→0, Hero.GetPrimaryAttribute=0, Hero.GetStrength broken, NPC.GetOwnerNPC=nil, NPC.IsVisibleToEnemies=false, NPC.IsMirrorProtected=false, Player.GetTeamData={}, Player.GetSelectedUnits={}, Player.GetQueryUnit=nil, Player.GetPlayerNeutralInfo const, GameRules.IsPaused=false, Humanizer.GetOrderQueue={}, Input.IsKeyDown=false, Input.IsInputCaptured=nil, Menu.Find=nil, Engine.RunScript no-op, Engine.GetHeroNameByID="", Engine.IsShopOpen missing, Engine.AcceptMatch/CanAcceptMatch stubs.

### P3 — lobby / online features (out of in-game scope)

Panorama.GetPanelByName, GC.SendMessage/GetSteamID, HTTP.Request, NetChannel.SendNetMessage, Protobuf (stub), matchmaking/draft/queue_account/protracker/online builds. These need Panorama UI automation, GC messaging and HTTP — none available in the bridge. In-game bot still functions with manual queue and local builds.

---

## (d) Top-25 implementation proposals

Offsets below are **verified** against `offsets.json` / `schema_dump.json` / `client.dll.hpp` (build 987800) unless marked *(runtime-resolve)* or *(approx)*. Prefer `schema.offsetOf(cls, field)` over hardcoding. KV = `D:\hake\lotus\gamedata\*.json`.

### 1. Event-callback dispatch (MISSING — highest leverage)
Loader fires only OnUpdateEx/OnUpdate/OnDraw. Add a per-tick event synthesizer in `loader.lua`/`api.lua`:
- **OnEntityHurt {target, source, damage, ability}:** poll `C_BaseEntity::m_iHealth 0x34C` per entity each tick; emit on decreases. Attribute `source` via `NPC.FindFacingNPC`-style heuristic or `m_flLastDamageTime 0x13C4` proximity; `ability=nil`. Feeds lastHit.hurt, ctx.lossLog/recentLoss, jungle/positioning/teamplay hurt.
- **OnUnitAnimation {unit, castpoint, lag_compensation_time} / OnUnitAnimationEnd:** poll `C_DOTA_BaseNPC::m_NetworkActivity 0x18E8`; on transition into `ACT_DOTA_ATTACK (1503)` emit with `castpoint = AttackAnimationPoint(KV)/GetAttackSpeed`, on transition out emit End. Cross-check `m_flLastAttackTime 0x13C8`.
- **OnProjectile {source, target, moveSpeed, isAttack, ability, handle}:** no projectile entity class exists in the client dump → synthesize from ranged attack-animation events: target = facing NPC within range, `moveSpeed` = KV `ProjectileSpeed` (npc_units.json). Feeds lastHit.projectile, creep aggro, dodge.
- **OnPrepareUnitOrders {player, order, npc, orderIssuer, identifier}:** poll `C_DOTAPlayerController::m_unitorders 0x9A0` / `m_nNextOutgoingOrderSequenceNumber 0x9B8`; entries not issued by the bridge = human orders → fire callback (enables manual-override pause). Do NOT fire for bridge-issued orders.
- **OnNpcDying / OnEntityDestroy:** entity-list diff + `m_lifeState 0x354` transitions.
- **OnLinearProjectileCreate/Destroy, OnParticle*:** require engine/particle hooks (not in dump) — mark hook-dependent; interim: detect enemy TPs via `modifier_teleporting` on visible heroes (already used by help_rotation).
- **OnGameEnd:** `C_DOTAGamerules::m_nGameState 0x7C` → POST_GAME(6) transition.

### 2. NPC.GetMana / GetMaxMana (BROKEN — fix field names)
`api.lua` reads `m_iMana`/`m_iMaxMana` which **do not exist** in `C_DOTA_BaseNPC`. Use `m_flMana 0xCFC` / `m_flMaxMana 0xD00` (f32). Unblocks every mana gate in the script. Also add mana check to `Ability.IsCastable(a, mana)` (see #13).

### 3. Ability behavior / target flag decoding (BROKEN)
`kvNum` only parses digits; gamedata stores `"AbilityBehavior":"DOTA_ABILITY_BEHAVIOR_UNIT_TARGET | DOTA_ABILITY_BEHAVIOR_POINT"`, `"AbilityUnitTargetTeam":"DOTA_UNIT_TARGET_TEAM_ENEMY"`, etc. Implement `kvFlags(kv, key, enumTable)`: split on `|`, trim, look up each name in `Enum.AbilityBehavior` / `Enum.TargetTeam` / `Enum.TargetType` / `Enum.TargetFlags`, OR the values; accept plain numbers too. Wire into GetBehavior/GetTargetTeam/GetTargetType/GetTargetFlags (fixes IsPassive/IsUltimate and the combat.lua cast dispatcher). Cache per ability name.

### 4. Modifier namespace (MISSING — crash fix)
`Modifier.GetName(m)` → `entity.designerName(m)` (trivial). For GetDieTime/GetStackCount/GetCaster/GetCreationTime/GetState: the base class `CDOTA_Buff` is **not in the static dumps** (derived modifiers start own fields at 0x1AA8), but the live SchemaSystem has it — resolve via `schema.offsetOf("CDOTA_Buff", "m_flDieTime" / "m_nStackCount" / "m_hCaster" / "m_flCreationTime" / "m_flDuration")` *(runtime-resolve; probe once and log)*. GetDieTime = GameTime_t value; GetState = read the modifier's state bitmask if present, else derive from name. Return type-safe defaults (0 / nil-safe) until resolved. Eliminates the TP/summon tick crashes.

### 5. Item charges (STUB/MISSING)
`C_DOTA_Item::m_iCurrentCharges 0x6E0`, `m_iSecondaryCharges 0x6E4`, `m_iMaxCharges 0x6E8`, `m_bRequiresCharges 0x6C1`, `m_iInitialCharges 0x6D4`. Implement Item.GetCurrentCharges/GetSecondaryCharges/RequiresCharges from these (items are entities; reuse `field()`). Unblocks tangoes, bottle, mangoes, wards, dust, clarities (27+ sites).

### 6. Hero.GetRecentDamage (STUB)
`C_DOTA_BaseNPC_Hero::m_iRecentDamage 0x1B28` (i32). Direct read. 40 call sites; restores retreat/defensive-item/engagement logic.

### 7. NPC.IsAttacking (STUB)
Approximation: `m_NetworkActivity 0x18E8 == ACT_DOTA_ATTACK (1503)` OR `(GameTime − m_flLastAttackTime 0x13C8) < GetSecondsPerAttack * 0.5`. Better once #1 animation events exist (track per-unit attack state). 89 sites; un-gates lastHit.animation.

### 8. Attack timing bundle (STUB)
- `GetSecondsPerAttack = m_flBaseAttackTime 0xCE8 * 100 / (100 + IAS)`.
- `GetAttackSpeed = (100 + IAS) / 100` (multiplier the script divides anim point by).
- IAS *(approx)*: heroes → `m_flAgilityTotal 0x1AF0` + base; plus sum of modifier attack-speed bonuses when #4 lands; creeps → `m_iBaseAttackSpeed 0xCE4 − 100`. Clamp [20, 500].
- `GetAttackAnimPoint` → KV `AttackAnimationPoint` (npc_units.json, per designer name; e.g. lane ranged creep 0.5).
- `GetAttackProjectileSpeed` → KV `ProjectileSpeed` (e.g. 900 for ranged creeps); 0 for melee.
Fixes the 0.2-clamp windup distortion and cadence math (53+10+9+2 sites).

### 9. Armor / magic-resistance multipliers (STUB)
`C_DOTA_BaseNPC::m_flPhysicalArmorValue 0x162C`, `m_flMagicalResistanceValue 0x1630`.
Physical: `armor >= 0 → 1 − (0.06·armor)/(1 + 0.06·armor)` else `1 − (0.06·|armor|)/(1 + 0.06·|armor|)` mirrored (2 − …). Magical: `1 − m_flMagicalResistanceValue` (value is total resist incl. base 25%; verify sign/range at runtime). 73 sites; core to damage prediction.

### 10. NPC.GetAttackRangeBonus (BROKEN field)
`m_iAttackRangeBonus` does not exist. Compute `GetAttackRange(e) − baseRange`, baseRange = KV `AttackRange` for the unit's designer name (npc_units.json); for heroes add known item bonuses (Dragon Lance/Hurricane Pike +140 via `NPC.HasModifier`/item presence). Clamp ≥ 0. 87 sites.

### 11. NPC.IsRanged (BROKEN field)
`m_bIsRanged` does not exist. Use `C_DOTA_BaseNPC::m_iAttackCapabilities 0x13B4` bitmask (DOTA_UNIT_CAP_RANGED_ATTACK) *(verify bit value against dumper enums at runtime)*, fallback KV `AttackCapabilities == "DOTA_UNIT_CAP_RANGED_ATTACK"`, fallback `GetAttackRange > 128`. 29 sites.

### 12. Ability.GetLevelSpecialValueFor (MISSING)
Read `abilityKV(a).AbilityValues[key]` — **gamedata uses `AbilityValues`, not `AbilitySpecialValues`** (637 entries; the script's own common.value already reads AbilityValues). Parse per-level numbers exactly like `kvNum` (space-separated list, index = level, optional `lvl` arg). 12 direct sites + many hero modules.

### 13. Ability.IsCastable / CanBeExecuted / IsReady / GetOwnerNPC (BROKEN/STUB)
- `IsCastable(a, mana)`: `IsReady(a)` and `(mana or ownerMana) >= GetManaCost(a)`; owner via `NPC.GetOwnerNPC`.
- `GetOwnerNPC(e)` → `entity.byHandle(field(e,"C_DOTA_BaseNPC","m_hOwnerNPC","u32"))` (0x1764).
- `CanBeExecuted(a)` must return `Enum.AbilityCastResult` codes: READY = **−1**, NO_MANA = 14, ABILITY_CD = 15, NOT_LEARNED = 16, PASSIVE = 17, HIDDEN = 60 (base_defense.lua:46 compares `== -1`).
- IsReady: add owner-mana & silence/mute checks when cheap.

### 14. NPC.FindFacingNPC (STUB)
Iterate `entity.iter()` NPCs within `distance` (default ~1200), team filter per `Enum.TeamType`, compute yaw from `Entity.GetRotation`, angle between facing and direction-to-candidate ≤ `angle` (default 30°), pick nearest/best. Reuse origin()/rotation helpers. 33 sites (target inference for tower tanking, focus, support).

### 15. GridNav (STUB)
No navmesh in schema. Two-stage plan:
- Interim *(approx)*: `IsTraversable` = inside map bounds (±8200) AND not inside a tree entity radius (trees discoverable via designer name `npc_dota_tree*` in entity list) AND not in known cliff/river polygons (hardcode a coarse Dota 2 map mask); `BuildPath` = A* over a 128–256u grid using that mask, cached per tick; `CreateNpcMap` = snapshot of blocking NPC hulls (`m_flHullRadius 0xD60`), `ReleaseNpcMap` = free.
- Real: hook the client nav interface (signature scan needed; not in current dump). 81+14+2+2 sites; movement safety is the biggest behavioral win after casting.

### 16. Economy / shop bundle (STUB/MISSING)
- `NPC.IsInRangeOfShop(e, shopType, includeSecret)`: `m_iNearShopMask 0x13EC` / `m_iCurShop 0xE04` *(verify semantics)*; robust fallback: distance to shop entities from `C_DOTAGamerules::m_hTeamShops 0x8EC`, `m_hSideShop1/2 0x864/0x868`, `m_hSecretShop1/2 0x86C/0x870`, fountains `m_hTeamFountains 0x874` (home shop radius ~1200).
- `Couriers.GetLocal/GetAll`: iterate `npc_dota_courier*`, match `m_hOwnerNPC 0x1764`/`m_nPlayerOwnerID 0x13C0` to local hero/PID.
- `Item.GetCost` → KV `ItemCost` (items.json, 534 entries).
- `Item.GetStockCount(id, team)` → `C_DOTAGamerules::m_vecItemStockInfo 0x7D8` vector of `CDOTA_ItemStockInfo` (stride 0x58): `nItemAbilityID 0x34`, `iStockCount 0x40`, `iTeamNumber 0x30`, `fStockTime 0x3C`, `iMaxCount 0x44`.
- `Item.GetPlayerOwnerID` → `C_DOTA_Item::m_iPlayerOwnerID 0x72C`.
- `Item.IsSellable/IsStackable/IsCombineLocked/IsItemEnabled/IsRecipe` → `m_bSellable 0x6BE`, `m_bStackable 0x6AE`, `m_bCombineLocked 0x6EC`, `m_bItemEnabled 0x701` (+`m_flEnableTime 0x704`), `m_bRecipe 0x6B4`.
Unblocks buying while alive, courier delivery, stock-aware ward buys, sell/disassemble logic.

### 17. FogOfWar.IsPointVisible (MISSING)
Loader defines `IsVisible` but the script calls `IsPointVisible`. Implement both: point is visible if any living allied unit/ward/building has it within vision range — use `m_iDayTimeVisionRange 0xE10` / `m_iNightTimeVisionRange 0xE14` + day/night from `C_DOTAGamerules::m_fTimeOfDay 0xA10`; include truesight via `m_nHasTruesightForTeam` (CDOTA_ModifierManager 0x380) for wards. Cache per tick. 6 sites but gates rune/deward/jungle decisions.

### 18. Tower.GetAttackTarget (MISSING)
`C_DOTA_BaseNPC_Tower::m_hTowerAttackTarget 0x1B5C` (CHandle) → `entity.byHandle`. Fallback `m_hPrevTowerAttackTarget 0x1B58`. 8 sites; restores tower-aggro safety (tower_safety, teamplay, dive, units, last_hit).

### 19. NPC.GetStatesDuration (STUB)
For each requested state bit, scan `modifierList(e)`; for modifiers whose state mask (via #4 CDOTA_Buff runtime fields) includes the bit, take `max(m_flDieTime − GameTime)`. Return `{[state]=seconds}`. 5 sites (awareness.control → engagement/focus/lina/meepo/units stun-chain math).

### 20. NPC.GetModifierProperty + GetBarriers (STUB)
- GetModifierProperty: maintain a name→{property, value} table for the properties the script actually queries — `MODIFIER_PROPERTY_DISABLE_HEALING` (e.g. modifier_ice_shroud, modifier_oracle_fates_edict…) and `MODIFIER_PROPERTY_CREEP_DENY_PERCENT` — plus generic aggregation once CDOTA_Buff property access lands (#4). 7 sites.
- GetBarriers: detect barrier modifiers (crimson_guard, pipe, abaddon_aphotic_shield, …) and sum KV barrier values into `{physical/magic/all:{total,current}}`; current scaled by remaining duration. 11 sites (zeros are safe but blind).

### 21. Hero tracking / attributes bundle (STUB/BROKEN/MISSING)
- `GetLastVisibleTime` / `GetLastMaphackPos`: bridge-side tracker — each tick, for every non-dormant enemy hero record `{pos, time}`; return stored values (Umbrella does the same). 2+2 sites (awareness, strategy).
- `GetReplicatingOtherHeroModel` → `byHandle(m_hReplicatingOtherHeroModel 0x1B7C)`. 10 sites.
- `TalentIsLearned(hero, talentIndex)`: scan ability slots for `special_bonus_*` with `GetLevel > 0`, map order → talent index. 1 site (+combat.lua:331).
- `GetCurrentXP` → `m_iCurrentXP 0x1AC4`. `GetPrimaryAttribute` → `m_iPrimaryAttribute 0x1B8C`.
- `GetStrength` fix: read `m_flStrengthTotal 0x1AEC` (f32), not absent `m_iStrength`.

### 22. NPC flags / bounty / ownership bundle (STUB/BROKEN)
- `IsMeepoClone` → `m_bIsClone 0xCCC`; `IsTormentor` → designer `npc_dota_tormentor`; `IsWaitingToSpawn` → `m_bIsWaitingToSpawn 0x1730`.
- `HasScepter` → `m_bLastScepterState 0x12ED` (or `m_bForceScepterState 0x12EE`); `HasShard` → `m_bLastShardState 0x12EC`.
- `IsLinkensProtected` → `HasModifier(e, "modifier_item_sphere_target")`; `IsMirrorProtected` → `HasModifier(e, "modifier_item_lotus_orb_active")` *(approx)*.
- `IsControllableByPlayer` → test bit for playerId in `m_iIsControllableByPlayer64 0xCB8` (u64 mask), fallback current logic.
- `GetBountyXP` → `m_iXPBounty 0x1754 + m_iXPBountyExtra 0x1758`; `GetGoldBountyMin/Max` → `0x175C/0x1760`.
- `IsVisibleToEnemies` *(approx)* → alive and not `MODIFIER_STATE_INVISIBLE` and not smoke-modified.
- **Entity.GetOwner fix:** return `entity.byHandle(m_hOwnerEntity 0x514)` instead of the raw handle (ember/earth spirit remnant checks).

### 23. Ability state bundle (MISSING/STUB)
- `GetAutoCastState` → `C_DOTABaseAbility::m_bAutoCastState 0x644` (u8). Fixes autocast spam.
- `SecondsSinceLastUse` → `GameTime − m_flLastCastClickTime 0x6A0` (fallback: bridge-side cast-order timestamp tracker). Fixes invoker crash.
- `GetChannelStartTime` → `m_flChannelStartTime 0x64C` (f32).
- `GetDamageType` → decode KV `AbilityUnitDamageType` (76 entries, e.g. `"DAMAGE_TYPE_MAGICAL"`) via `Enum.DamageTypes`; default PHYSICAL for attacks.

### 24. Ground Z + trees + NPCs.InRadius (STUB/MISSING)
- `NPCs.InRadius(pos, radius, team, teamType)`: trivial filter over `NPCs.GetAll()` + origin distance + team — **fixes objectives.lua:23 crash**.
- `Trees.InRadius` / `Entity.GetTreesInRadius` / `Tree.IsActive`: discover tree entities by designer name (`npc_dota_tree*`) in entity.iter; cache positions per tick; `IsActive` = entity present & not dormant (runtime-resolve `C_DOTA_Tree` fields if needed). `TempTrees.InRadius/GetAll` → `C_DOTA_TempTree` entities, filter `m_fExpireTime 0xBE0 > GameTime`. `Entity.GetTempTreesInRadius` likewise. Fixes hoodwink/mars/timbersaw/tinker crashes + tango tree healing.
- `World.GetGroundZ(x, y)` *(approx)*: no trace interface in dump → build a coarse heightmap from sampled tree/ward/building `m_vecAbsOrigin.z` per map region + known lane/ramp heights; fallback 128. Mark hook-dependent for exact traces. 31 sites (Z mostly cosmetic for candidate scoring, but cliff checks matter).

### 25. Runes / latency / misc (STUB/MISSING)
- `Runes.GetAll/Contains`, `Rune.GetRuneType`: rune entities are `C_DOTA_Item_Rune` (designer `npc_dota_rune*`); `m_iRuneType 0xBC0`, `m_flRuneTime 0xBC4`. Spawners: `C_DOTA_Item_RuneSpawner*` `m_nRuneType 0xBB0`. **Implement together** — runes.lua:133 does `kind >= 0` on the result (nil would crash once GetAll is non-empty).
- `Bottle.GetRuneType` → read bottle's stored-rune modifier (`modifier_bottle_regeneration` variants) or item KV state; return −1 when empty *(approx; probe modifier names)*.
- `NetChannel.GetAvgLatency(flow)` → `C_DOTAPlayerController::m_flLastUnitOrdersTotalLatency 0x948` (seconds→ms as Umbrella expects; verify unit) *(approx)*. 21 sites.
- `GameRules.IsPaused` → game-state/pause detection (probe `m_nGameState` during pause; no explicit pause bool in dump).
- `Player.GetSelectedUnits` → `m_nSelectedUnits 0x9C8` handle vector; `Player.GetQueryUnit` → `m_hQueryUnit 0x9FC`.
- `Input.IsInputCaptured` → foreground/window + cursor state heuristic, or false (safe).
- `Engine.ExecuteCommand` → needs engine console interface (signature scan; not in dump); interim keep no-op but note camera follow stays dead. `Engine.IsShopOpen` → add explicit false stub (Engine lacks softIndex).

**Already implemented — do not redo:** everything in section (b); notably the entire order pipeline (MoveTo/AttackTarget/HoldPosition/PrepareUnitOrders/Cast*), entity/ability/item enumeration, HasState/HasModifier, cooldowns/levels/mana-cost/cast-range/cast-point, GameRules state/time/matchID, Render/Menu/Enum/mathx/KV infrastructure.

---

## (e) Risks & notes

1. **Build-specific hardcodes.** `orders.lua` PUO RVA `0x1B5F860`, `entity.lua` gamerules global `0x6219008`, `render.lua` viewmatrix `0x6221CB0` must be refreshed after every Dota patch (dumper in `D:\hake\lotus\dumper`). api.lua additionally hardcodes `0xE30` (ModifierManager), `0x12B8` (UnitState64), `0x11C0+0x20` (inventory), and the whole `AB_OFF` table — all currently match the dump, but should move to `schema.offsetOf` for patch resilience (schema.lua already resolves any class/field at runtime).
2. **Silent stubs are dangerous.** `softIndex` returns 0 for any `Get*`, false for `Is*/Has*/Can*`, {} for some; `stubNS` returns nil for everything. Nil into arithmetic/`ipairs` aborts the whole tick via the loader pcall (bot freezes while the condition persists). Prefer type-safe defaults + one-time logging for every unimplemented function; the current `miss()` log cap (40) hides later gaps.
3. **GameTime approximation.** `GameRules.GetGameTime` anchors on controller order timestamps (`m_flUnitOrdersSendTime 0x940` / `m_flLastUnitOrdersSendTime 0x944`) and advances by wall clock. It drifts during pauses, lag, or long order-less periods; cooldowns/channel times computed against it inherit the drift. Consider reading a real game-time global (signature scan) later.
4. **Field-name bugs are invisible.** `m_iMana`, `m_iMaxMana`, `m_bIsRanged`, `m_iAttackRangeBonus`, `m_iStrength` do not exist in this build's schema; `schema.offsetOf` returns nil and the wrappers silently return defaults. Add a startup self-test that asserts every field used by api.lua resolves, and logs failures.
5. **KV drift.** gamedata JSON is a static snapshot; balance patches change numbers. The dump uses `AbilityValues` (not the original KV's `AbilitySpecialValues`) and symbolic flag strings — any KV consumer must decode names, not just digits. `npc_heroes.json` is effectively empty (2 bytes) — hero base data must come from `npc_units.json`/`heroes.json` in the script's own data dir.
6. **Entity representation.** Entities are `CEntityIdentity` pointers; handles resolve through a 0.05s-cached map. `Entity.GetOwner` currently leaks a raw handle (fix in #22). `orderIndex` heuristic (numbers < 0x10000 = ability IDs) can misclassify small entity indices — fine in practice, worth a comment.
7. **Threading.** Orders are issued directly from the bot thread (Present-hook queue disabled because it black-screened this build). PUO from a non-game thread is inherently racy; keep call volume low and watch for crashes after patches.
8. **Dormancy heuristic.** `Entity.IsDormant` tests identity flags `(+0x30) % 0x100 >= 0x80`; verify the exact dormancy bit against `CEntityIdentity::m_flags 0x30` if vision logic misbehaves. `NPC.IsVisible = not dormant` is an approximation (no team-visibility check).
9. **Callback synthesis limits.** Animation/activity polling gives ~1-tick granularity (33ms) — adequate for last-hit windows but not frame-perfect; projectile synthesis from animations misses ability projectiles and true travel paths. Linear-projectile/particle callbacks need real hooks (not in the current dump) — plan signature scans if dodge parity is required.
10. **Lobby/online scope.** Panorama, GC, HTTP, protobuf are stubs → matchmaking, draft, talents-via-UI, protracker builds are unavailable. Talents still work via `DOTA_UNIT_ORDER_TRAIN_ABILITY` (talents.lua method 0/2 already uses it). In-game play requires manual queueing.
11. **Config persistence.** Config.Read/Write are memory-only; UI settings reset each launch. Persist to JSON under the cheat directory if desired.
12. **Legal/ToS.** This audit is static analysis only. Automating play in Dota 2 violates Valve's terms and can result in bans; nothing here was executed against the game.

---

### Appendix A — callback contract (script → bridge)

| Callback | Data fields used by Self Play | Bridge status |
|---|---|---|
| OnUpdate / OnUpdateEx / OnDraw / OnScriptsLoaded | — | fired by loader |
| OnPrepareUnitOrders | player, order, npc, orderIssuer, identifier | never fired |
| OnProjectile | source, target, moveSpeed, isAttack, ability, handle | never fired |
| OnUnitAnimation | unit, castpoint, lag_compensation_time | never fired |
| OnUnitAnimationEnd | unit | never fired |
| OnEntityHurt | target, source, damage, ability | never fired |
| OnNpcDying / OnEntityDestroy | npc / entity | never fired |
| OnLinearProjectileCreate/Destroy | source, origin, velocity, distance, handle | never fired |
| OnParticleCreate/Update/UpdateFallback/UpdateEntity/Destroy | particle data (teleports module) | never fired |
| OnGameEnd / OnGCMessage | — / data | never fired |

### Appendix B — key offset quick reference (client.dll, build 987800)

| Class::field | Hex | Used by proposal |
|---|---|---|
| C_BaseEntity::m_iHealth / m_iMaxHealth / m_lifeState / m_iTeamNum / m_pGameSceneNode / m_hOwnerEntity | 0x34C / 0x348 / 0x354 / 0x3E7 / 0x330 / 0x514 | 1, 22 |
| CGameSceneNode::m_vecAbsOrigin / m_angAbsRotation | 0xD8 / 0xE4 | existing |
| C_DOTA_BaseNPC::m_flMana / m_flMaxMana | 0xCFC / 0xD00 | 2 |
| C_DOTA_BaseNPC::m_iBaseAttackSpeed / m_flBaseAttackTime / m_flLastAttackTime / m_NetworkActivity | 0xCE4 / 0xCE8 / 0x13C8 / 0x18E8 | 7, 8 |
| C_DOTA_BaseNPC::m_flPhysicalArmorValue / m_flMagicalResistanceValue | 0x162C / 0x1630 | 9 |
| C_DOTA_BaseNPC::m_iAttackCapabilities / m_iAttackRange | 0x13B4 / 0xCC8 | 10, 11 |
| C_DOTA_BaseNPC::m_ModifierManager / m_nUnitState64 / m_Inventory / m_vecAbilities | 0xE30 / 0x12B8 / 0x11C0 / 0xD28 | existing, 4, 19 |
| C_DOTA_UnitInventory::m_hItems | 0x20 | existing |
| C_DOTA_BaseNPC::m_iNearShopMask / m_iCurShop / m_nPlayerOwnerID / m_hOwnerNPC | 0x13EC / 0xE04 / 0x13C0 / 0x1764 | 13, 16 |
| C_DOTA_BaseNPC::m_bIsClone / m_bIsWaitingToSpawn / m_bLastScepterState / m_bLastShardState / m_iIsControllableByPlayer64 | 0xCCC / 0x1730 / 0x12ED / 0x12EC / 0xCB8 | 22 |
| C_DOTA_BaseNPC::m_iXPBounty / m_iXPBountyExtra / m_iGoldBountyMin / m_iGoldBountyMax | 0x1754 / 0x1758 / 0x175C / 0x1760 | 22 |
| C_DOTA_BaseNPC::m_iDayTimeVisionRange / m_iNightTimeVisionRange | 0xE10 / 0xE14 | 17 |
| C_DOTA_BaseNPC_Hero::m_iRecentDamage / m_iCurrentXP / m_iPrimaryAttribute / m_flStrengthTotal / m_flAgilityTotal / m_hReplicatingOtherHeroModel | 0x1B28 / 0x1AC4 / 0x1B8C / 0x1AEC / 0x1AF0 / 0x1B7C | 6, 8, 21 |
| C_DOTABaseAbility::m_bAutoCastState / m_flChannelStartTime / m_flLastCastClickTime | 0x644 / 0x64C / 0x6A0 | 23 |
| C_DOTA_Item::m_iCurrentCharges / m_iSecondaryCharges / m_bRequiresCharges / m_iPlayerOwnerID / m_bItemEnabled / m_bSellable / m_bStackable / m_bCombineLocked | 0x6E0 / 0x6E4 / 0x6C1 / 0x72C / 0x701 / 0x6BE / 0x6AE / 0x6EC | 5, 16 |
| C_DOTA_BaseNPC_Tower::m_hTowerAttackTarget | 0x1B5C | 18 |
| C_DOTAGamerules::m_vecItemStockInfo / m_hTeamShops / m_hSecretShop1/2 / m_hSideShop1/2 / m_fTimeOfDay / m_nGameState | 0x7D8 / 0x8EC / 0x86C/0x870 / 0x864/0x868 / 0xA10 / 0x7C | 16, 17, 25 |
| CDOTA_ItemStockInfo::nItemAbilityID / iStockCount / iTeamNumber / fStockTime (stride 0x58) | 0x34 / 0x40 / 0x30 / 0x3C | 16 |
| C_DOTAPlayerController::m_flLastUnitOrdersTotalLatency / m_unitorders / m_nSelectedUnits / m_hQueryUnit | 0x948 / 0x9A0 / 0x9C8 / 0x9FC | 1, 25 |
| C_DOTA_Item_Rune::m_iRuneType / m_flRuneTime | 0xBC0 / 0xBC4 | 25 |
| C_DOTA_TempTree::m_fExpireTime | 0xBE0 | 24 |
| C_DOTA_BaseNPC_XP_Fountain::m_bActive / m_bIsBeingGranted (wisdom shrine) | 0x1B2C / 0x1B2D | Entity.GetField 1-arg |
| C_DOTA_BaseNPC_LotusPool::m_nLotusCount / m_bInVision | 0x1B28 / 0x1B38 | Entity.GetField 1-arg |
| CDOTA_Buff::m_flDieTime / m_nStackCount / m_hCaster / m_flCreationTime | *(runtime-resolve; not in static dump)* | 4, 19, 20 |

*End of report.*


---

## AGENT 2 REPORT

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

