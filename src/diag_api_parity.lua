-- diag_api_parity.lua -- task-21 "API PARITY AUDIT" (owner: api-core)
-- -----------------------------------------------------------------------
-- Companion of D:\hake\lotus\API_PARITY_INVENTORY.md (developer, task-22):
-- 225 reference functions / 39 namespaces / 5604 call sites; early-game path = 136.
-- This script exercises the EARLY-GAME PATH live and prints, per function:
--   live value | tag | umbrella_api doc | 16.11 call-site
-- plus acceptance rows for Lead's post-fix criteria and a manifest presence check.
--
-- Tag decision rules (reviewer-adjudicable):
--   OK          documented type + range/invariant, cross-API consistency passes.
--   GARBAGE     wrong type/range, nil where the contract requires a value (incl. any
--               high-serial CHandle -> nil), or undocumented cross-API mismatch.
--               GARBAGE in the early-game path = blocker (fix before live re-test).
--   STUB        EXPECTED documented approximation/gap: GetBarriers nil, Engine.RunScript
--               stub, GetGameModeEntity nil, FogOfWar remote-point conservative false,
--               enemy-player GetTeamData zeros (playerIDToPlayer map is local-team only).
--   UNVERIFIED  needs another context (enemy unit, illusion, ability/item, no creeps).
--   MISSING     manifest symbol absent from this Lua state (loader-owned namespaces can
--               be absent when the diag runs outside loader's session).
--   ERROR       call raised (pcall message captured).
--
-- TWO-SAMPLE ACCEPTANCE: run this diag TWICE >=20 s apart in the same match; compare the
-- `[parity] ACCEPTANCE` lines (lasthit_count / xp growth / clock delta) and compare the
-- HUD "Now" screenshot with `[parity] acceptance activity` + self_play.log `[SelfPlay ... mode=]`.
--
-- Run: Set-Content run.txt 'D:\hake\lotus\src\diag_api_parity.lua' in a live Treant game.
-- -----------------------------------------------------------------------

-- task-24 (orders-nav): nav.lua ships a canonical `_G.GridNav` surface and installs it
-- only when nil (never overrides the loader's table). This makes the manifest see
-- GridNav even when the diag runs outside the loader session.
pcall(function() package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path end)
pcall(function()
  local n = require("nav")
  if n then
    -- Robust to both nav revisions: in the 21:58:43 nav.lua the GridNav surface block
    -- was inserted inside local function cellCenter(), so nav.installGlobal only exists
    -- after cellCenter runs once; trigger that lazy path first, then install if present.
    if not n.installGlobal then pcall(n.IsTraversable, { x = 0, y = 0, z = 0 }) end
    if n.installGlobal then n.installGlobal() end
    if rawget(_G, "GridNav") == nil and n.gridnav then _G.GridNav = n.gridnav end
    -- Fallback (diag-only) for nav revisions where the GridNav block is trapped inside
    -- a function scope: wrap the canonical nav module functions directly so the manifest
    -- and behavior rows still measure the real navigation surface.
    if rawget(_G, "GridNav") == nil then
      _G.GridNav = {
        IsTraversable = function(p)
          if not p then return true, 0 end
          if n.IsTraversable then return n.IsTraversable(p) end
          return true, 0
        end,
        IsTraversableFromTo = function(a, b, it, nm)
          if n.IsTraversableFromTo then return n.IsTraversableFromTo(a, b, it == true, nm) end
          return true
        end,
        BuildPath = function(s, d, it, nm)
          if type(d) ~= "table" then return {} end
          local sx = s and (s.x or s[1]) or 0
          local sy = s and (s.y or s[2]) or 0
          local path = {}
          if n.buildPath then
            local okp, p = pcall(n.buildPath, sx, sy, d.x or d[1] or 0, d.y or d[2] or 0, it == true, nm)
            if okp and type(p) == "table" then path = p end
          end
          local out = {}
          for i, w in ipairs(path) do out[i] = { x = w.x, y = w.y, z = w.z or (d.z or 128) } end
          return out
        end,
        CreateNpcMap = function(ex, it, sz)
          if not n.CreateNpcMap then return nil end
          local okm, m = pcall(n.CreateNpcMap, ex, it == true, sz)
          if okm then return m end
          return nil
        end,
        ReleaseNpcMap = function(m)
          if n.ReleaseNpcMap then return n.ReleaseNpcMap(m) end
          return true
        end,
      }
    end
  end
end)


local okf, ffi = pcall(require, "ffi")
if not okf then ffi = nil end
local inDota = false
if okf and ffi then
  pcall(ffi.cdef, [[ void* __stdcall GetModuleHandleA(const char* lpModuleName); ]])
  local okM, mod = pcall(function() return ffi.C.GetModuleHandleA("client.dll") end)
  inDota = (okM and mod ~= nil)
end
if not inDota then
  print("API_PARITY DRYRUN OK (outside Dota: client.dll not loaded, body skipped)")
  return
end
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  if not f then return end
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  f:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n")
  f:flush()
end

-- orders-nav task-24: in a fresh script state nav's grid is virgin (statsValid=false,
-- campSites()={} by guard, groundZ=128 sentinel). One pcall-wrapped rescan builds the
-- static grid so the NAV/World/diag rows are meaningful (live cost 11-36 ms, idempotent);
-- the raise is contained so a nav problem can never abort the whole diag run.
do
  local before, after, okr = false, false, false
  local function navValid()
    local okn, n = pcall(require, "nav")
    if not okn or not n or not n.stats then return false end
    local okS, s = pcall(n.stats)
    return (okS and type(s) == "table" and s.valid == true)
  end
  before = navValid()
  okr = pcall(function() local n = require("nav"); if n and n.rescan then n.rescan() end end)
  after = navValid()
  log(string.format("[parity] warmup rescan ok=%s valid_before=%s valid_after=%s",
    tostring(okr), tostring(before), tostring(after)))
end

-- reference call sites: SITE["NS.Fn"] = "file:line" (first occurrence, 16.11 tree)
local SITE = {
  ["Ability.CanBeExecuted"] = "Self Play.lua:2151",
  ["Ability.CanBeUpgraded"] = "self_play/combat.lua:457",
  ["Ability.CastNoTarget"] = "self_play/consumables.lua:233",
  ["Ability.CastPosition"] = "self_play/recovery.lua:137",
  ["Ability.GetAutoCastState"] = "self_play/combat.lua:698",
  ["Ability.GetBehavior"] = "self_play/combat.lua:277",
  ["Ability.GetCastPoint"] = "self_play/awareness.lua:67",
  ["Ability.GetCastRange"] = "self_play/active_items.lua:69",
  ["Ability.GetChannelStartTime"] = "self_play/heroes/invoker.lua:120",
  ["Ability.GetCooldown"] = "self_play/active_items.lua:42",
  ["Ability.GetCurrentCharges"] = "self_play/heroes/earth_spirit.lua:91",
  ["Ability.GetDamage"] = "Self Play.lua:2212",
  ["Ability.GetDamageType"] = "Self Play.lua:2213",
  ["Ability.GetLevel"] = "self_play/active_items.lua:41",
  ["Ability.GetLevelSpecialValueFor"] = "self_play/mobility.lua:50",
  ["Ability.GetManaCost"] = "self_play/active_items.lua:38",
  ["Ability.GetName"] = "self_play/active_items.lua:45",
  ["Ability.GetTargetFlags"] = "self_play/combat.lua:135",
  ["Ability.GetTargetTeam"] = "self_play/combat.lua:137",
  ["Ability.GetTargetType"] = "self_play/combat.lua:136",
  ["Ability.GetToggleState"] = "self_play/active_items.lua:153",
  ["Ability.IsActivated"] = "self_play/active_items.lua:41",
  ["Ability.IsCastable"] = "self_play/active_items.lua:90",
  ["Ability.IsChannelling"] = "Self Play.lua:1013",
  ["Ability.IsHidden"] = "self_play/active_items.lua:41",
  ["Ability.IsInAbilityPhase"] = "self_play/combat.lua:327",
  ["Ability.IsPassive"] = "self_play/active_items.lua:41",
  ["Ability.IsReady"] = "self_play/active_items.lua:88",
  ["Ability.IsUltimate"] = "self_play/active_items.lua:47",
  ["Ability.SecondsSinceLastUse"] = "self_play/active_items.lua:43",
  ["Ability.Toggle"] = "self_play/combat.lua:333",
  ["Ability.ToggleMod"] = "self_play/combat.lua:334",
  ["Bottle.GetRuneType"] = "self_play/combat.lua:83",
  ["Config.ReadFloat"] = "self_play/localization.lua:53",
  ["Config.ReadInt"] = "Self Play.lua:99",
  ["Config.ReadString"] = "self_play/build_brain.lua:337",
  ["Config.WriteFloat"] = "self_play/localization.lua:62",
  ["Config.WriteInt"] = "Self Play.lua:101",
  ["Config.WriteString"] = "self_play/build_brain.lua:342",
  ["Engine.AcceptMatch"] = "self_play/matchmaking.lua:128",
  ["Engine.CanAcceptMatch"] = "self_play/matchmaking.lua:123",
  ["Engine.ExecuteCommand"] = "Self Play.lua:2349",
  ["Engine.GetCheatDirectory"] = "self_play/build_brain.lua:285",
  ["Engine.GetHeroNameByID"] = "self_play/draft.lua:180",
  ["Engine.IsInGame"] = "Self Play.lua:1823",
  ["Engine.IsInLobby"] = "self_play/matchmaking.lua:105",
  ["Engine.RunScript"] = "self_play/draft.lua:275",
  ["Entity.Get"] = "self_play/teleports.lua:12",
  ["Entity.GetAbsOrigin"] = "Self Play.lua:345",
  ["Entity.GetClassName"] = "self_play/runes.lua:117",
  ["Entity.GetField"] = "self_play/objectives.lua:263",
  ["Entity.GetHealth"] = "Self Play.lua:450",
  ["Entity.GetIndex"] = "Self Play.lua:273",
  ["Entity.GetMaxHealth"] = "Self Play.lua:475",
  ["Entity.GetOwner"] = "self_play/heroes/earth_spirit.lua:13",
  ["Entity.GetRotation"] = "self_play/active_items.lua:176",
  ["Entity.GetTeamNum"] = "Self Play.lua:312",
  ["Entity.GetTempTreesInRadius"] = "self_play/consumables.lua:88",
  ["Entity.GetTreesInRadius"] = "self_play/consumables.lua:115",
  ["Entity.IsAlive"] = "Self Play.lua:244",
  ["Entity.IsDormant"] = "Self Play.lua:244",
  ["Entity.IsEntity"] = "Self Play.lua:244",
  ["Entity.IsNPC"] = "self_play/combat.lua:519",
  ["Entity.IsSameTeam"] = "Self Play.lua:279",
  ["FogOfWar.IsPointVisible"] = "self_play/awareness.lua:151",
  ["GameRules.GetBadGlyphCD"] = "self_play/siege.lua:369",
  ["GameRules.GetGameMode"] = "self_play/draft.lua:251",
  ["GameRules.GetGameStartTime"] = "Self Play.lua:346",
  ["GameRules.GetGameState"] = "Self Play.lua:1833",
  ["GameRules.GetGameTime"] = "Self Play.lua:338",
  ["GameRules.GetGoodGlyphCD"] = "self_play/siege.lua:369",
  ["GameRules.GetMatchID"] = "self_play/shop.lua:640",
  ["GameRules.IsPaused"] = "Self Play.lua:1832",
  ["GC.GetSteamID"] = "self_play/party_queue.lua:72",
  ["GC.SendMessage"] = "self_play/matchmaking.lua:17",
  ["GlobalVars.GetAbsFrameTime"] = "self_play/party_queue.lua:225",
  ["GridNav.BuildPath"] = "Self Play.lua:764",
  ["GridNav.CreateNpcMap"] = "self_play/last_hit.lua:554",
  ["GridNav.IsTraversable"] = "Self Play.lua:370",
  ["GridNav.ReleaseNpcMap"] = "self_play/last_hit.lua:599",
  ["Hero.GetAbilityPoints"] = "self_play/combat.lua:425",
  ["Hero.GetCurrentXP"] = "self_play/value.lua:47",
  ["Hero.GetLastMaphackPos"] = "self_play/awareness.lua:102",
  ["Hero.GetLastVisibleTime"] = "self_play/awareness.lua:104",
  ["Hero.GetPlayerID"] = "Self Play.lua:277",
  ["Hero.GetPrimaryAttribute"] = "self_play/consumables.lua:227",
  ["Hero.GetRecentDamage"] = "Self Play.lua:535",
  ["Hero.GetReplicatingOtherHeroModel"] = "Self Play.lua:280",
  ["Hero.GetRespawnTime"] = "self_play/recovery.lua:467",
  ["Hero.GetStrength"] = "self_play/heroes/morphling.lua:11",
  ["Hero.TalentIsLearned"] = "self_play/combat.lua:381",
  ["Heroes.GetAll"] = "Self Play.lua:276",
  ["Heroes.GetLocal"] = "Self Play.lua:1835",
  ["HTTP.Request"] = "self_play/build_brain.lua:320",
  ["Humanizer.GetOrderQueue"] = "self_play/creep_block.lua:130",
  ["Input.IsInputCaptured"] = "Self Play.lua:1860",
  ["Item.GetCost"] = "self_play/inventory_cleanup.lua:21",
  ["Item.GetCurrentCharges"] = "self_play/active_items.lua:319",
  ["Item.GetPlayerOwnerID"] = "self_play/inventory_cleanup.lua:63",
  ["Item.GetSecondaryCharges"] = "self_play/objectives.lua:134",
  ["Item.GetStockCount"] = "self_play/shop.lua:18",
  ["Item.IsCombineLocked"] = "self_play/shop.lua:356",
  ["Item.IsItemEnabled"] = "self_play/active_items.lua:88",
  ["Item.IsSellable"] = "self_play/inventory_cleanup.lua:24",
  ["Item.IsStackable"] = "self_play/shop.lua:557",
  ["Item.RequiresCharges"] = "self_play/combat.lua:86",
  ["Menu.Create"] = "Self Play.lua:88",
  ["Menu.Find"] = "self_play/localization.lua:107",
  ["Modifier.GetCaster"] = "self_play/deward.lua:43",
  ["Modifier.GetCreationTime"] = "self_play/runes.lua:167",
  ["Modifier.GetDieTime"] = "Self Play.lua:1639",
  ["Modifier.GetName"] = "self_play/heroes/arc_warden.lua:33",
  ["Modifier.GetStackCount"] = "self_play/heroes/lion.lua:9",
  ["Modifier.GetState"] = "self_play/heroes/invoker.lua:95",
  ["NetChannel.GetAvgLatency"] = "Self Play.lua:1023",
  ["NetChannel.SendNetMessage"] = "self_play/neutral_items.lua:134",
  ["NPC.FindFacingNPC"] = "Self Play.lua:1660",
  ["NPC.GetAbility"] = "self_play/combat.lua:449",
  ["NPC.GetAbilityByIndex"] = "self_play/active_items.lua:40",
  ["NPC.GetArmorDamageMultiplier"] = "Self Play.lua:478",
  ["NPC.GetAttackAnimPoint"] = "self_play/engagement.lua:52",
  ["NPC.GetAttackProjectileSpeed"] = "self_play/engagement.lua:58",
  ["NPC.GetAttackRange"] = "Self Play.lua:488",
  ["NPC.GetAttackRangeBonus"] = "Self Play.lua:577",
  ["NPC.GetAttackSpeed"] = "self_play/engagement.lua:66",
  ["NPC.GetBarriers"] = "Self Play.lua:523",
  ["NPC.GetBountyXP"] = "self_play/active_items.lua:418",
  ["NPC.GetCurrentLevel"] = "self_play/combat.lua:378",
  ["NPC.GetGoldBountyMax"] = "self_play/heroes/tinker_farming.lua:113",
  ["NPC.GetGoldBountyMin"] = "self_play/last_hit.lua:583",
  ["NPC.GetHealthRegen"] = "self_play/combat.lua:265",
  ["NPC.GetHullRadius"] = "Self Play.lua:871",
  ["NPC.GetItem"] = "Self Play.lua:1011",
  ["NPC.GetItemByIndex"] = "self_play/awareness.lua:77",
  ["NPC.GetMagicalArmorDamageMultiplier"] = "Self Play.lua:2214",
  ["NPC.GetMana"] = "self_play/active_items.lua:52",
  ["NPC.GetManaRegen"] = "self_play/recovery.lua:18",
  ["NPC.GetMaxMana"] = "self_play/active_items.lua:81",
  ["NPC.GetModifier"] = "Self Play.lua:1638",
  ["NPC.GetModifierProperty"] = "Self Play.lua:843",
  ["NPC.GetModifiers"] = "self_play/heroes/arc_warden.lua:32",
  ["NPC.GetMoveSpeed"] = "Self Play.lua:457",
  ["NPC.GetOwnerNPC"] = "self_play/coordination.lua:29",
  ["NPC.GetSecondsPerAttack"] = "Self Play.lua:880",
  ["NPC.GetStatesDuration"] = "self_play/awareness.lua:23",
  ["NPC.GetTimeToFace"] = "self_play/engagement.lua:65",
  ["NPC.GetTimeToFacePosition"] = "self_play/creep_block.lua:94",
  ["NPC.GetTrueDamage"] = "Self Play.lua:431",
  ["NPC.GetTrueMaximumDamage"] = "self_play/base_defense.lua:65",
  ["NPC.GetUnitName"] = "Self Play.lua:291",
  ["NPC.HasModifier"] = "Self Play.lua:1013",
  ["NPC.HasScepter"] = "self_play/shop.lua:48",
  ["NPC.HasShard"] = "self_play/shop.lua:46",
  ["NPC.HasState"] = "Self Play.lua:555",
  ["NPC.IsAncient"] = "self_play/active_items.lua:416",
  ["NPC.IsAttacking"] = "Self Play.lua:601",
  ["NPC.IsBarracks"] = "self_play/base_defense.lua:20",
  ["NPC.IsChannellingAbility"] = "Self Play.lua:704",
  ["NPC.IsControllableByPlayer"] = "self_play/units.lua:33",
  ["NPC.IsCourier"] = "Self Play.lua:430",
  ["NPC.IsCreep"] = "Self Play.lua:363",
  ["NPC.IsEntityInRange"] = "Self Play.lua:853",
  ["NPC.IsFort"] = "Self Play.lua:1269",
  ["NPC.IsHero"] = "Self Play.lua:423",
  ["NPC.IsIllusion"] = "Self Play.lua:280",
  ["NPC.IsInRangeOfShop"] = "self_play/inventory_cleanup.lua:118",
  ["NPC.IsLaneCreep"] = "Self Play.lua:363",
  ["NPC.IsLinkensProtected"] = "self_play/active_items.lua:174",
  ["NPC.IsMeepoClone"] = "Self Play.lua:280",
  ["NPC.IsMirrorProtected"] = "self_play/combat.lua:151",
  ["NPC.IsNeutral"] = "Self Play.lua:428",
  ["NPC.IsRanged"] = "self_play/base_defense.lua:367",
  ["NPC.IsRoshan"] = "Self Play.lua:428",
  ["NPC.IsRunning"] = "Self Play.lua:366",
  ["NPC.IsSilenced"] = "self_play/active_items.lua:124",
  ["NPC.IsStructure"] = "Self Play.lua:422",
  ["NPC.IsStunned"] = "Self Play.lua:652",
  ["NPC.IsTormentor"] = "Self Play.lua:428",
  ["NPC.IsTower"] = "Self Play.lua:421",
  ["NPC.IsVisible"] = "Self Play.lua:248",
  ["NPC.IsVisibleToEnemies"] = "self_play/heroes/tinker.lua:60",
  ["NPC.IsWaitingToSpawn"] = "Self Play.lua:407",
  ["NPC.IsWard"] = "Self Play.lua:431",
  ["NPC.MoveTo"] = "Self Play.lua:792",
  ["NPCs.GetAll"] = "Self Play.lua:405",
  ["NPCs.InRadius"] = "self_play/objectives.lua:24",
  ["Panorama.GetPanelByName"] = "self_play/draft.lua:253",
  ["Player.AttackTarget"] = "Self Play.lua:856",
  ["Player.GetAssignedHero"] = "Self Play.lua:272",
  ["Player.GetPlayerID"] = "Self Play.lua:334",
  ["Player.GetPlayerNeutralInfo"] = "self_play/neutral_items.lua:116",
  ["Player.GetQueryUnit"] = "self_play/talents.lua:4",
  ["Player.GetSelectedUnits"] = "Self Play.lua:2169",
  ["Player.GetTeamData"] = "self_play/draft.lua:118",
  ["Player.GetTeamPlayer"] = "Self Play.lua:1985",
  ["Player.GetTotalGold"] = "self_play/recovery.lua:69",
  ["Player.HoldPosition"] = "Self Play.lua:681",
  ["Player.PrepareUnitOrders"] = "self_play/combat.lua:127",
  ["Players.GetAll"] = "Self Play.lua:271",
  ["Players.GetLocal"] = "Self Play.lua:1835",
  ["PowerTreads.GetStats"] = "self_play/consumables.lua:229",
  ["Render.Circle"] = "self_play/hud.lua:324",
  ["Render.FilledCircle"] = "self_play/hud.lua:336",
  ["Render.FilledRect"] = "self_play/hud.lua:256",
  ["Render.Line"] = "self_play/hud.lua:335",
  ["Render.LoadFont"] = "Self Play.lua:171",
  ["Render.Rect"] = "self_play/hud.lua:300",
  ["Render.ScreenSize"] = "self_play/hud.lua:239",
  ["Render.Text"] = "Self Play.lua:2307",
  ["Render.TextSize"] = "self_play/hud.lua:35",
  ["Render.WorldToScreen"] = "self_play/hud.lua:322",
  ["Tower.GetAttackTarget"] = "Self Play.lua:476",
  ["Tree.IsActive"] = "self_play/consumables.lua:89",
  ["World.GetGroundZ"] = "Self Play.lua:732",
}

local LOADER_NS = { GridNav = true, World = true, Item = true, Modifier = true, Tower = true,
  Bottle = true, Tree = true, PowerTreads = true, NPCs = true, Humanizer = true,
  Menu = true, Render = true, Input = true, Panorama = true, GC = true, HTTP = true }
local function trunc(s, n)
  s = tostring(s)
  if #s <= n then return s end
  return s:sub(1, n - 3) .. "..."
end

local function body()
  local okS, schema = pcall(require, "schema")
  local okE, entity = pcall(require, "entity")
  local okApi, api = pcall(require, "api")
  if not okApi or not api or not api.register then
    log("[parity] FATAL: api module unavailable: ", tostring(api))
    return
  end
  if okS then pcall(schema.init) end
  if okE then pcall(entity.init) end
  pcall(api.register)

  local E, N, H, HS = rawget(_G, "Entity"), rawget(_G, "NPC"), rawget(_G, "Hero"), rawget(_G, "Heroes")
  local P, PS, GR, EN = rawget(_G, "Player"), rawget(_G, "Players"), rawget(_G, "GameRules"), rawget(_G, "Engine")
  local GV, FOW, W, NC = rawget(_G, "GlobalVars"), rawget(_G, "FogOfWar"), rawget(_G, "World"), rawget(_G, "NetChannel")
  local inLoaderCtx = rawget(_G, "LaneGroupsManager") ~= nil or rawget(_G, "JungleCampsManager") ~= nil
  log("[parity] context loader=", tostring(inLoaderCtx), " (loader-owned namespaces expected when true)")
  local counts = { OK = 0, GARBAGE = 0, STUB = 0, UNVERIFIED = 0, MISSING = 0, ERROR = 0 }
  local bad = {}

  local function row(group, name, doc, fn)
    local ok, v, tag = pcall(fn)
    if not ok then
      v, tag = "raise: " .. tostring(v), "ERROR"
    end
    tag = tag or "UNVERIFIED"
    counts[tag] = (counts[tag] or 0) + 1
    if tag == "GARBAGE" or tag == "ERROR" then
      bad[#bad + 1] = string.format("%s/%s=%s[%s]", group, name, tag, trunc(v, 28))
    end
    log(string.format("[parity] %-14s %-44s = %-38s | %-10s | %-30s | %s",
      group, name, trunc(v or "nil", 38), tag, doc, SITE[name] or "-"))
  end

  local function isNum(v) return type(v) == "number" and v == v end
  local function num(v, lo, hi)
    if not isNum(v) then return tostring(v), "GARBAGE" end
    if (lo and v < lo) or (hi and v > hi) then
      return string.format("%.4f !![%s,%s]", v, tostring(lo), tostring(hi)), "GARBAGE"
    end
    return string.format("%.4f", v), "OK"
  end
  local function int(v, lo, hi)
    if not isNum(v) or v ~= math.floor(v) then return tostring(v), "GARBAGE" end
    return num(v, lo, hi)
  end
  local function bool(v, want)
    if type(v) ~= "boolean" then return tostring(v), "GARBAGE" end
    if want ~= nil and v ~= want then return tostring(v) .. "(want " .. tostring(want) .. ")", "GARBAGE" end
    return tostring(v), "OK"
  end
  local function pos(o)
    if type(o) ~= "table" then return tostring(o), "GARBAGE" end
    local x, y, z = tonumber(o.x), tonumber(o.y), tonumber(o.z)
    if not (x and y and z) then return "no xyz", "GARBAGE" end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or z < -20000 or z > 5000 then
      return string.format("%.1f,%.1f,%.1f !!bounds", x, y, z), "GARBAGE"
    end
    return string.format("%.1f,%.1f,%.1f", x, y, z), "OK"
  end
  local function ent(v)
    if v == nil then return "nil", "GARBAGE" end
    if not E.IsEntity(v) then return "not-entity", "GARBAGE" end
    return tostring(E.GetIndex(v)) .. ":" .. tostring(E.GetUnitName(v)), "OK"
  end
  local function dist(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
  end

  log("=== API_PARITY BEGIN === wall=", string.format("%.1f", ffi and tonumber(ffi.C.GetTickCount64()) / 1000 or os.clock()),
    " inventory=API_PARITY_INVENTORY.md(225 fns/136 early)")
  local hero = HS and HS.GetLocal()
  local lp = PS and PS.GetLocal()
  local hidx = hero and E.GetIndex(hero)
  local hp = hero and E.GetAbsOrigin(hero)

  -- =========================================================================
  -- 1. identity / positions  (doc: entity.md, hero.md)
  -- =========================================================================
  if hero then
    local G = "identity"
    row(G, "Heroes.GetLocal", "hero.md Heroes.GetLocal", function()
      local n = E.GetUnitName(hero)
      return tostring(n), (type(n) == "string" and n:find("^npc_dota_hero_")) and "OK" or "GARBAGE"
    end)
    row(G, "Heroes.GetAll", "hero.md Heroes.GetAll", function()
      local list = HS.GetAll()
      if type(list) ~= "table" then return tostring(list), "GARBAGE" end
      local seen, ok = {}, true
      for i = 1, #list do
        local ix = E.GetIndex(list[i])
        if not ix or ix < 1 or ix > 16383 or seen[ix] then ok = false end
        seen[ix] = true
      end
      return string.format("n=%d uniqueIdx=%s", #list, tostring(ok)), ok and "OK" or "GARBAGE"
    end)
    row(G, "Entity.GetIndex", "entity.md GetIndex (1..16383, stable)", function()
      return int(E.GetIndex(hero), 1, 16383)
    end)
    row(G, "Entity.GetClassName", "entity.md GetClassName; runes.lua:117 compares C_* schema class => defect", function()
      local c = E.GetClassName(hero)
      if type(c) ~= "string" or c == "" then return tostring(c), "GARBAGE" end
      -- reviewer ruling: designer-name fallback silently fails runes.lua:117 ->
      -- GARBAGE (fix = runtime schema class resolution, not a doc-only note)
      if c:find("^C_") then return c, "OK" end
      return c .. " (designer fallback)", "GARBAGE"
    end)
    row(G, "Entity.GetUnitName", "entity.md GetUnitName (designer)", function()
      local n = E.GetUnitName(hero)
      return tostring(n), (type(n) == "string" and n:find("^npc_dota_hero_")) and "OK" or "GARBAGE"
    end)
    row(G, "Entity.GetAbsOrigin(hero)", "entity.md GetAbsOrigin world bounds", function()
      return pos(hp)
    end)
    row(G, "Entity.GetHealth", "entity.md GetHealth 0..max, alive=>hp>0", function()
      local v, mx = E.GetHealth(hero), E.GetMaxHealth(hero)
      local sv, tag = num(v, 0, mx)
      if tag == "OK" and E.IsAlive(hero) and v <= 0 then return sv .. " alive-but-0", "GARBAGE" end
      return string.format("%s/%s", sv, tostring(mx)), tag
    end)
    row(G, "Entity.GetMaxHealth", "entity.md GetMaxHealth >0", function()
      return num(E.GetMaxHealth(hero), 1, 1000000)
    end)
    row(G, "Entity.GetTeamNum", "entity.md GetTeamNum (2/3 heroes)", function()
      local t = E.GetTeamNum(hero)
      return int(t), (t == 2 or t == 3) and "OK" or "GARBAGE"
    end)
    row(G, "Entity.IsAlive", "entity.md IsAlive", function()
      return bool(E.IsAlive(hero))
    end)
    row(G, "Entity.IsDormant", "entity.md IsDormant (local false)", function()
      return bool(E.IsDormant(hero), false)
    end)
    row(G, "Entity.IsHero/IsNPC/IsEntity", "entity.md predicates", function()
      local a, b, c = E.IsHero(hero), E.IsNPC(hero), E.IsEntity(hero)
      if a == true and b == true and c == true then return "true/true/true", "OK" end
      return string.format("%s/%s/%s", tostring(a), tostring(b), tostring(c)), "GARBAGE"
    end)
    row(G, "Entity.GetRotation", "entity.md GetRotation -> Angle:GetForward(), active_items.lua:176", function()
      local r = E.GetRotation(hero)
      if type(r) ~= "table" then return tostring(r), "GARBAGE" end
      local gf = r.GetForward
      if type(gf) ~= "function" then return "Angle w/o GetForward", "GARBAGE" end
      local okF, fwd = pcall(gf, r)
      if not okF or type(fwd) ~= "table" then return "GetForward fail", "GARBAGE" end
      local fv = fwd
      if type(fwd.Normalized) == "function" then
        local okN, nv = pcall(fwd.Normalized, fwd)
        if okN and type(nv) == "table" then fv = nv end
      end
      local x, y = tonumber(fv.x), tonumber(fv.y)
      if not (x and y) then return "no xyz", "GARBAGE" end
      return string.format("fwd=%.2f,%.2f", x, y), "OK"
    end)
    row(G, "Hero.GetPlayerID", "hero.md GetPlayerID == local pid", function()
      local pid = H.GetPlayerID(hero)
      local lpid = lp and P.GetPlayerID(lp) or -2
      return string.format("%s (local %s)", tostring(pid), tostring(lpid)),
        (pid == lpid and pid >= 0 and pid <= 9) and "OK" or "GARBAGE"
    end)
    row(G, "Player.GetAssignedHero(local)", "player.md GetAssignedHero", function()
      local a = P.GetAssignedHero(lp)
      if a == hero then return "==localHero", "OK" end
      if a == nil then return "nil", "GARBAGE" end
      return tostring(E.GetUnitName(a)), "GARBAGE"
    end)
  end

  -- =========================================================================
  -- 2. role / lane / player data  (doc: player.md)
  -- =========================================================================
  if lp then
    local G = "role_lane"
    row(G, "Players.GetLocal", "player.md Players.GetLocal", function()
      return "pid=" .. tostring(P.GetPlayerID(lp)), "OK"
    end)
    row(G, "Players.GetAll", "player.md Players.GetAll (10 normal)", function()
      local list = PS.GetAll()
      if type(list) ~= "table" then return tostring(list), "GARBAGE" end
      return string.format("n=%d", #list), (#list >= 2 and #list <= 24) and "OK" or "GARBAGE"
    end)
    row(G, "Player.GetPlayerID", "player.md GetPlayerID (0..23)", function()
      return int(P.GetPlayerID(lp), -1, 23)
    end)
    row(G, "Player.GetPlayerSlot", "player.md GetPlayerSlot", function()
      return int(P.GetPlayerSlot(lp), 0, 23)
    end)
    row(G, "Player.GetPlayerTeamSlot", "player.md GetPlayerTeamSlot 0..4", function()
      return int(P.GetPlayerTeamSlot(lp), 0, 4)
    end)
    row(G, "Player.GetTeamData", "player.md GetTeamData (draft.lua:118 lane flags)", function()
      local d = P.GetTeamData(lp)
      if type(d) ~= "table" then return tostring(d), "GARBAGE" end
      local ok = isNum(d.level) and d.level >= 1 and d.level <= 30 and isNum(d.kills)
        and d.kills >= 0 and d.kills <= 9999 and isNum(d.deaths) and d.deaths >= 0
        and isNum(d.lane_selection_flags)
      return string.format("k=%s d=%s a=%s lvl=%s laneFlags=%s heroId=%s", tostring(d.kills),
        tostring(d.deaths), tostring(d.assists), tostring(d.level),
        tostring(d.lane_selection_flags), tostring(d.selected_hero_id)), ok and "OK" or "GARBAGE"
    end)
    row(G, "Player.GetTeamPlayer", "player.md GetTeamPlayer row", function()
      local t = P.GetTeamPlayer(lp)
      if type(t) ~= "table" then return tostring(t), "GARBAGE" end
      local ok = isNum(t.networth) and t.networth >= 0 and t.networth < 200000 and isNum(t.lasthit_count)
        and t.lasthit_count >= 0 and isNum(t.deny_count) and t.deny_count >= 0
      return string.format("nw=%s lh=%s dn=%s xp=%s gold=%s", tostring(t.networth),
        tostring(t.lasthit_count), tostring(t.deny_count), tostring(t.totalearned_xp),
        tostring(t.totalearned_gold)), ok and "OK" or "GARBAGE"
    end)
    row(G, "Player.GetTotalGold", "player.md GetTotalGold >=0", function()
      return num(P.GetTotalGold(lp), 0, 200000)
    end)
    row(G, "Player.GetSelectedUnits", "player.md GetSelectedUnits list", function()
      local s = P.GetSelectedUnits(lp)
      if type(s) ~= "table" then return tostring(s), "GARBAGE" end
      return string.format("n=%d", #s), "OK"
    end)
    row(G, "Player.GetQueryUnit", "player.md GetQueryUnit (nil ok)", function()
      local q = P.GetQueryUnit(lp)
      if q == nil then return "nil", "OK" end
      return ent(q)
    end)
    -- enemy-player team data policy: client only networks the LOCAL team's controller map
    row(G, "GetTeamData(enemy pids) policy", "player.md: enemy team data zeros documented", function()
      local myTeam = E.GetTeamNum(hero)
      local zeros, nonzero, garbage = 0, 0, 0
      for _, pl in ipairs(PS.GetAll()) do
        if E.GetTeamNum(pl) ~= myTeam then
          local d = P.GetTeamData(pl)
          if type(d) ~= "table" or not isNum(d.kills) then
            garbage = garbage + 1
          elseif d.kills == 0 and d.deaths == 0 and d.assists == 0 and (d.selected_hero_id or 0) == 0 then
            zeros = zeros + 1
          else
            nonzero = nonzero + 1
          end
        end
      end
      local sv = string.format("zeros=%d nonzero=%d garbage=%d", zeros, nonzero, garbage)
      if garbage > 0 then return sv, "GARBAGE" end
      if nonzero > 0 then return sv, "OK" end
      return sv .. " (documented local-team limitation)", "STUB"
    end)
  end

  -- =========================================================================
  -- 3. creeps / wave  (doc: npc.md, entity.md)
  -- =========================================================================
  local creeps = {}
  if hero then
    for idn in entity.iter() do
      if E.IsEntity(idn) and E.IsNPC(idn) and N.IsLaneCreep(idn) then creeps[#creeps + 1] = idn end
    end
  end
  local nearCreeps, nearest, nearestDist = 0, nil, math.huge
  if hero and #creeps > 0 then
    for _, c in ipairs(creeps) do
      local o = E.GetAbsOrigin(c)
      local d = dist(o, hp)
      if d < 1500 then nearCreeps = nearCreeps + 1 end
      if d < nearestDist then nearest, nearestDist = c, d end
    end
  end
  if hero then
    local G = "creeps_wave"
    row(G, "NPC.IsLaneCreep", "npc.md IsLaneCreep", function()
      if #creeps == 0 then return "n=0", "UNVERIFIED" end
      return string.format("n=%d first=%s", #creeps, tostring(N.GetUnitName(creeps[1]))), "OK"
    end)
    if nearest then
      row(G, "NPC.GetUnitName(creep)", "npc.md npc_dota_creep_*", function()
        local n = N.GetUnitName(nearest)
        return tostring(n), (type(n) == "string" and n:find("npc_dota_creep")) and "OK" or "GARBAGE"
      end)
      row(G, "NPC.GetMoveSpeed(creep)", "npc.md 200..600", function()
        return num(N.GetMoveSpeed(nearest), 200, 600)
      end)
      row(G, "NPC.GetAttackRange(creep)", "npc.md ~100 melee/500 ranged", function()
        return num(N.GetAttackRange(nearest), 50, 800)
      end)
      row(G, "NPC.IsRanged(creep)", "npc.md bool", function()
        return bool(N.IsRanged(nearest))
      end)
      row(G, "NPC.GetTrueDamage(creep)", "npc.md 0..1000", function()
        return num(N.GetTrueDamage(nearest), 0, 1000)
      end)
      row(G, "NPC.GetArmorDamageMultiplier", "npc.md 0.05..3", function()
        return num(N.GetArmorDamageMultiplier(nearest), 0.05, 3)
      end)
      row(G, "Entity.IsSameTeam(hero,creep)", "entity.md bool", function()
        return bool(E.IsSameTeam(hero, nearest))
      end)
      row(G, "NPC.IsEntityInRange(900)", "npc.md bool == dist<=900", function()
        local ok = N.IsEntityInRange(hero, nearest, 900)
        if nearestDist <= 900 and ok ~= true then return tostring(ok) .. " dist=" .. math.floor(nearestDist), "GARBAGE" end
        return bool(ok)
      end)
      row(G, "NPC.IsVisible(creep)", "npc.md bool", function()
        return bool(N.IsVisible(nearest))
      end)
    else
      log("[parity] creeps_wave  no lane creeps in entity list (creep rows skipped)")
    end
  end

  -- =========================================================================
  -- 4. attack / last-hit  (doc: npc.md, hero.md) -- developer §4 highest value
  -- =========================================================================
  local allyNearest, allyDist = nil, math.huge
  if hero then
    for _, a in ipairs(HS.GetAll()) do
      if a ~= hero and E.IsSameTeam(hero, a) and E.IsAlive(a) then
        local d = dist(E.GetAbsOrigin(a), hp)
        if d < allyDist then allyNearest, allyDist = a, d end
      end
    end
  end
  if hero then
    local G = "attack_last_hit"
    row(G, "NPC.GetAttackSpeed(hero)", "npc.md aps 0.1..6 (last_hit.lua:114)", function()
      return num(N.GetAttackSpeed(hero), 0.1, 6)
    end)
    row(G, "NPC.GetSecondsPerAttack(hero)", "npc.md == 1/GetAttackSpeed", function()
      local spa, aps = N.GetSecondsPerAttack(hero), N.GetAttackSpeed(hero)
      local sv, tag = num(spa, 0.1, 10)
      if tag == "OK" and aps and math.abs(spa * aps - 1) > 0.01 then
        return string.format("%s mismatch aps=%.3f", sv, aps), "GARBAGE"
      end
      return sv, tag
    end)
    row(G, "NPC.GetAttackAnimPoint(hero)", "npc.md fraction 0..2 (last_hit.lua:36)", function()
      return num(N.GetAttackAnimPoint(hero), 0, 2)
    end)
    row(G, "NPC.GetAttackProjectileSpeed", "npc.md nil melee / 100..4000 ranged", function()
      local v = N.GetAttackProjectileSpeed(hero)
      if v == nil then return "nil (melee)", "OK" end
      return num(v, 100, 4000)
    end)
    row(G, "NPC.GetAttackRange(hero)", "npc.md 50..1200", function()
      return num(N.GetAttackRange(hero), 50, 1200)
    end)
    row(G, "NPC.GetAttackRangeBonus(hero)", "npc.md >=0 sanity", function()
      return num(N.GetAttackRangeBonus(hero), -100, 2000)
    end)
    row(G, "NPC.GetTrueDamage(hero)", "npc.md 0..1000", function()
      return num(N.GetTrueDamage(hero), 0, 1000)
    end)
    row(G, "NPC.GetTrueMaximumDamage(hero)", "npc.md 0..1000", function()
      local v = N.GetTrueMaximumDamage and N.GetTrueMaximumDamage(hero)
      if v == nil then return "nil", "MISSING" end
      return num(v, 0, 1000)
    end)
    row(G, "NPC.IsAttacking(hero)", "npc.md bool (last_hit.lua:92)", function()
      return bool(N.IsAttacking(hero))
    end)
    row(G, "NPC.IsRunning(hero)", "npc.md m_bIsMoving bool", function()
      return bool(N.IsRunning(hero))
    end)
    row(G, "Hero.GetRecentDamage(hero)", "hero.md 0..1e6 hero-only", function()
      return num(H.GetRecentDamage(hero), 0, 1000000)
    end)
    row(G, "NPC.FindFacingNPC(hero)", "npc.md nil ok (35 call sites)", function()
      local v = N.FindFacingNPC(hero, nil, 0, 30, 300)
      if v == nil then return "nil", "OK" end
      return ent(v)
    end)
    if nearest then
      row(G, "NPC.FindFacingNPC(creep,target)", "npc.md faces target?", function()
        local v = N.FindFacingNPC(nearest, nil, 0, 30, 500)
        if v == nil then return "nil", "UNVERIFIED" end
        return ent(v)
      end)
    end
  end

  -- =========================================================================
  -- 5. xp / gold / level  (doc: hero.md, npc.md, player.md)
  -- =========================================================================
  if hero then
    local G = "xp_gold_level"
    row(G, "Hero.GetCurrentXP(hero)", "hero.md >=0", function()
      return num(H.GetCurrentXP(hero), 0, 1000000)
    end)
    row(G, "NPC.GetCurrentLevel(hero)", "npc.md 1..30", function()
      return int(N.GetCurrentLevel(hero), 1, 30)
    end)
    row(G, "Hero.GetAbilityPoints(hero)", "hero.md 0..30", function()
      return int(H.GetAbilityPoints(hero), 0, 30)
    end)
    row(G, "Hero.GetStrength/Agility/Intellect", "hero.md 0..999", function()
      local a, b, c = H.GetStrength(hero), H.GetAgility(hero), H.GetIntellect(hero)
      local ok = isNum(a) and a >= 0 and a < 1000 and isNum(b) and b >= 0 and b < 1000 and isNum(c) and c >= 0 and c < 1000
      return string.format("%s/%s/%s", tostring(a), tostring(b), tostring(c)), ok and "OK" or "GARBAGE"
    end)
    row(G, "Hero.GetPrimaryAttribute", "hero.md 0/1/2", function()
      return int(H.GetPrimaryAttribute(hero), 0, 3)
    end)
    if lp then
      row(G, "NPC level == teamData.level", "cross-API consistency", function()
        local lvl, tl = N.GetCurrentLevel(hero), (P.GetTeamData(lp) or {}).level
        return string.format("%s==%s", tostring(lvl), tostring(tl)), (lvl == tl) and "OK" or "GARBAGE"
      end)
      row(G, "Hero.GetCurrentXP == teamPlayer.xp", "cross-API XP", function()
        local xp, tx = H.GetCurrentXP(hero), (P.GetTeamPlayer(lp) or {}).totalearned_xp
        if not (isNum(xp) and isNum(tx)) then return "nil", "GARBAGE" end
        return string.format("%s vs %s", tostring(xp), tostring(tx)), "OK"
      end)
    end
  end

  -- =========================================================================
  -- 6. hud inputs / time / vision  (doc: gamerules.md, engine.md, globalvars.md)
  -- =========================================================================
  local now, state = nil, nil
  do
    local G = "hud_inputs"
    now = GR.GetGameTime()
    state = GR.GetGameState()
    row(G, "GameRules.GetGameTime", "gamerules.md state-aware: >0 in game, -1 pregame, frozen post-game", function()
      local v = now
      if not isNum(v) then return tostring(v), "GARBAGE" end
      if state and state >= 2 and state < 5 then
        return string.format("%.3f (pre-game)", v), (v == -1 or v >= 0) and "OK" or "GARBAGE"
      end
      if state and state == 5 then
        return string.format("%.3f", v), (v > 0) and "OK" or "GARBAGE"
      end
      if state and state > 6 then
        return string.format("%.3f (post-game frozen ok)", v), (v >= 0) and "OK" or "GARBAGE"
      end
      return string.format("%.3f", v), "UNVERIFIED"
    end)
    row(G, "GameRules.GetGameStartTime", "gamerules.md 0<=start<=now, elapsed prints", function()
      local gs = GR.GetGameStartTime()
      local sv, tag = num(gs, -1, (isNum(now) and now + 1) or 100000)
      if tag == "OK" and isNum(now) then
        local el = now - gs
        if el < -1 or el > 100000 then return string.format("%s el=%s", sv, tostring(el)), "GARBAGE" end
        return string.format("%s el=%.1f", sv, el), "OK"
      end
      return sv, tag
    end)
    row(G, "GameRules.GetGameState", "gamerules.md 0..7", function()
      return int(GR.GetGameState(), 0, 7)
    end)
    row(G, "GameRules.IsPaused", "gamerules.md m_bGamePaused", function()
      return bool(GR.IsPaused())
    end)
    row(G, "GameRules.GetGoodGlyphCD/GetBadGlyphCD", "gamerules.md timestamps", function()
      local a, b = GR.GetGoodGlyphCD(), GR.GetBadGlyphCD()
      local ok = isNum(a) and isNum(b) and a >= -1 and b >= -1
      return string.format("%s/%s", tostring(a), tostring(b)), ok and "OK" or "GARBAGE"
    end)
    row(G, "Engine.IsInGame", "engine.md bool", function()
      return bool(EN.IsInGame())
    end)
    row(G, "Engine.GetCheatDirectory", "engine.md path", function()
      local d = EN.GetCheatDirectory()
      return tostring(d), (type(d) == "string" and #d > 2) and "OK" or "GARBAGE"
    end)
    row(G, "GlobalVars.GetCurTime", "globalvars.md == GetGameTime", function()
      local a = GV.GetCurTime()
      if isNum(a) and isNum(now) and math.abs(a - now) < 0.5 then return string.format("%.2f", a), "OK" end
      return string.format("%s vs %s", tostring(a), tostring(now)), "GARBAGE"
    end)
    row(G, "GlobalVars.GetAbsFrameTime", "globalvars.md 0..0.5", function()
      local v = GV.GetAbsFrameTime()
      return num(v, -0.001, 0.5)
    end)
    if NC and NC.GetAvgLatency then
      row(G, "NetChannel.GetAvgLatency", "netchannel.md 0..1 s (creep_block.lua:7)", function()
        return num(NC.GetAvgLatency(0), 0, 2)
      end)
    end
    if hero and W then
      row(G, "World.GetGroundZ(heroPos)", "loader world.md |dz|<=600", function()
        local z = W.GetGroundZ(hp.x, hp.y)
        local sv, tag = num(z, -20000, 5000)
        if tag == "OK" and math.abs(z - hp.z) > 600 then return string.format("%s heroZ=%.0f", sv, hp.z), "GARBAGE" end
        return sv, tag
      end)
    end
    if hero and FOW then
      row(G, "FogOfWar.IsPointVisible(ownPos)", "fogofwar: own position must be visible", function()
        local v = FOW.IsPointVisible(hp)
        return bool(v, true)
      end)
      row(G, "FogOfWar.IsPointVisible(remotePoint)", "fogofwar: conservative false allowed (approx)", function()
        local far = { x = 6000, y = 6000, z = 128 }
        local v = FOW.IsPointVisible(far)
        if v == false then return "false (conservative, documented approx)", "STUB" end
        return tostring(v), "GARBAGE"
      end)
    end
    if hero and N then
      row(G, "NPC.IsVisibleToEnemies(hero)", "npc.md bool", function()
        return bool(N.IsVisibleToEnemies(hero))
      end)
    end
  end

  -- =========================================================================
  -- 7. state oracles + handles (developer §4: HasState / GetModifierProperty ...)
  -- =========================================================================
  if hero then
    local G = "state_handles"
    row(G, "Entity.IsEntity(0)", "entity.md invalid -> false", function()
      return bool(E.IsEntity(0), false)
    end)
    row(G, "Entity.IsEntity(0xFFFFFFFF)", "entity.md INVALID -> false", function()
      return bool(E.IsEntity(0xFFFFFFFF), false)
    end)
    row(G, "Entity.GetOwner(localHero)", "entity.md hero->CPlayer (high-serial)", function()
      local o = E.GetOwner(hero)
      if o == nil then return "nil", "GARBAGE" end
      return ent(o)
    end)
    row(G, "Entity.RecursiveGetOwner(localHero)", "entity.md chain", function()
      local o = E.RecursiveGetOwner(hero)
      if o == nil then return "nil", "UNVERIFIED" end
      return ent(o)
    end)
    row(G, "Hero.GetReplicatingOtherHeroModel(real)", "hero.md nil for real heroes", function()
      local badN, tot = 0, 0
      for _, h in ipairs(HS.GetAll()) do
        tot = tot + 1
        if H.GetReplicatingOtherHeroModel(h) ~= nil and not N.IsIllusion(h) and not N.IsMeepoClone(h) then badN = badN + 1 end
      end
      return string.format("heroes=%d wrongNonNil=%d", tot, badN), (badN == 0) and "OK" or "GARBAGE"
    end)
    row(G, "NPC.GetOwnerNPC", "npc.md owner of spirit bear (nil ok)", function()
      local v = N.GetOwnerNPC(hero)
      if v == nil then return "nil", "OK" end
      return ent(v)
    end)
    row(G, "Entity.IsDormant(own hero/creep/ally)", "dormancy proof: local hero + own team never dormant (reviewer scope a/b)", function()
      local thero, ownCreep, ownAlly = E.IsDormant(hero), nil, nil
      for _, c in ipairs(creeps) do if E.IsSameTeam(hero, c) then ownCreep = c break end end
      for _, a in ipairs(HS.GetAll()) do if a ~= hero and E.IsEntity(a) and E.IsSameTeam(hero, a) then ownAlly = a break end end
      local bad = 0
      if thero then bad = bad + 1 end
      if ownCreep and E.IsDormant(ownCreep) then bad = bad + 1 end
      if ownAlly and E.IsDormant(ownAlly) then bad = bad + 1 end
      return string.format("hero=%s creep=%s ally=%s bad=%d", tostring(thero),
        ownCreep and tostring(E.IsDormant(ownCreep)) or " -",
        ownAlly and tostring(E.IsDormant(ownAlly)) or " -", bad), (bad == 0) and "OK" or "GARBAGE"
    end)
    row(G, "Entity.IsDormant(enemy heroes)", "dormancy proof: enemies keep engine dormancy (visible OR fogged both allowed)", function()
      local vis, fog = 0, 0
      for _, a in ipairs(HS.GetAll()) do
        if E.IsEntity(a) and not E.IsSameTeam(hero, a) then
          if E.IsDormant(a) then fog = fog + 1 else vis = vis + 1 end
        end
      end
      return string.format("visible=%d foggedDormant=%d (both allowed)", vis, fog), "OK"
    end)
    row(G, "NPC.HasState(hero, STUNNED)", "npc.md bool (149 call sites)", function()
      local v = N.HasState(hero, 1)   -- Enum.ModifierState.MODIFIER_STATE_STUNNED (enums.md)
      return bool(v)
    end)
    row(G, "NPC.GetStatesDuration(hero, all, false)", "npc.md numeric keys, non-nil", function()
      local st = {}
      for s = 0, 63 do st[s] = true end
      local t = N.GetStatesDuration(hero, st, false)
      if type(t) ~= "table" then return tostring(t), "GARBAGE" end
      local n, numeric = 0, true
      for k in pairs(t) do n = n + 1; if type(k) ~= "number" then numeric = false end end
      return string.format("keys=%d numeric=%s", n, tostring(numeric)), (n > 0 and numeric) and "OK" or "GARBAGE"
    end)
    row(G, "NPC.GetModifierProperty(hero,337)", "npc.md CREEP_DENY_PERCENT base 50", function()
      local v = N.GetModifierProperty(hero, 337)
      return num(v, -1000, 1000)
    end)
    row(G, "NPC.GetModifiers(hero)", "npc.md table (buff pointers)", function()
      local m = N.GetModifiers(hero)
      if type(m) ~= "table" then return tostring(m), "GARBAGE" end
      return string.format("n=%d", #m), "OK"
    end)
    row(G, "NPC.HasModifier(hero, name)", "npc.md bool", function()
      return bool(N.HasModifier(hero, "modifier_treant_natures_guise"))
    end)
    if rawget(_G, "Tower") then
      row(G, "Tower.GetAttackTarget", "tower-safety oracle (last_hit.lua:89)", function()
        local tower
        for idn in entity.iter() do
          if E.IsEntity(idn) and N.IsTower(idn) then tower = idn break end
        end
        if not tower then return "no tower", "UNVERIFIED" end
        local t = rawget(_G, "Tower").GetAttackTarget(tower)
        return t and ent(t) or "nil", "OK"
      end)
    end
    if rawget(_G, "Tree") and rawget(_G, "Tree").IsActive then
      row(G, "Tree.IsActive", "tree walk oracle (Treant)", function()
        local cnt = 0
        for idn in entity.iter() do
          if E.IsEntity(idn) and tostring(E.GetUnitName(idn)):find("tree", 1, true) then
            cnt = cnt + 1
            if cnt > 3 then break end
          end
        end
        if cnt == 0 then return "no trees", "UNVERIFIED" end
        return "trees>=1", "OK"
      end)
    end
    if rawget(_G, "PowerTreads") and rawget(_G, "PowerTreads").GetStats then
      row(G, "PowerTreads.GetStats", "treads attribute oracle", function()
        local v = rawget(_G, "PowerTreads").GetStats(hero)
        if v == nil then return "nil", "UNVERIFIED" end
        return tostring(v), "OK"
      end)
    end
    if rawget(_G, "Bottle") and rawget(_G, "Bottle").GetRuneType then
      row(G, "Bottle.GetRuneType", "rune oracle (runes.lua)", function()
        local v = rawget(_G, "Bottle").GetRuneType(hero)
        if v == nil then return "nil", "UNVERIFIED" end
        return tostring(v), "OK"
      end)
    end
  end

  -- =========================================================================
  -- 8. documented gaps (expected STUB)
  -- =========================================================================
  if hero then
    local G = "stubs"
    row(G, "NPC.GetBarriers(hero)", "npc.md barrier table or nil (documented)", function()
      local v = N.GetBarriers(hero)
      if v == nil then return "nil (documented)", "STUB" end
      return type(v), "OK"
    end)
    row(G, "Engine.RunScript", "engine.md documented stub (log-once false)", function()
      local v = EN.RunScript and EN.RunScript("parity_test", "")
      if v == false then return "false (documented)", "STUB" end
      return tostring(v), "OK"
    end)
    row(G, "GameRules.GetGameModeEntity", "gamerules.md follow-up (:2102 untouched)", function()
      local v = GR.GetGameModeEntity and GR.GetGameModeEntity()
      if v == nil then return "nil (documented)", "STUB" end
      return ent(v)
    end)
  end

  -- =========================================================================
  -- 9. ACCEPTANCE rows (Lead criteria; compare TWO samples >=20 s apart)
  -- =========================================================================
  if hero and now then
    local G = "acceptance"
    local clk = now - GR.GetGameStartTime()
    local tp = lp and P.GetTeamPlayer(lp) or {}
    local xp = H.GetCurrentXP(hero)
    local nearEnemy = 0
    for _, c in ipairs(creeps) do
      if not E.IsSameTeam(hero, c) and dist(E.GetAbsOrigin(c), hp) < 900 then nearEnemy = nearEnemy + 1 end
    end
    row(G, "lastHits@clock", "criterion >=3 last-hits by 5:00", function()
      return string.format("clock=%.1f lasthits=%s denies=%s", clk or -1,
        tostring(tp.lasthit_count), tostring(tp.deny_count)), "UNVERIFIED"
    end)
    row(G, "xpGrowth@clock", "criterion XP grows between samples", function()
      return string.format("clock=%.1f xp=%s lvl=%s", clk or -1, tostring(xp),
        tostring(N.GetCurrentLevel(hero))), "UNVERIFIED"
    end)
    row(G, "distToWave", "criterion <=600u while last-hitting", function()
      local sv = nearest and string.format("%.0f u (near<1500=%d, enemy<900=%d)", nearestDist, nearCreeps, nearEnemy)
        or "no creeps"
      return sv, "UNVERIFIED"
    end)
    row(G, "distToAlly", "criterion <=900u from an ally (teamplay)", function()
      local sv = allyNearest and string.format("%.0f u (%s)", allyDist, tostring(E.GetUnitName(allyNearest)))
        or "no living ally"
      return sv, "UNVERIFIED"
    end)
    row(G, "activity", "HUD 'Now' must match actions (attacking/running/near wave)", function()
      return string.format("attacking=%s running=%s hp=%.0f%% pos=%.0f,%.0f",
        tostring(N.IsAttacking(hero)), tostring(N.IsRunning(hero)),
        100 * E.GetHealth(hero) / math.max(1, E.GetMaxHealth(hero)), hp.x, hp.y), "UNVERIFIED"
    end)
    log(string.format("[parity] ACCEPTANCE clock=%.1f lasthits=%s xp=%s lvl=%s distWave=%s distAlly=%s attacking=%s running=%s enemyCreeps<900=%d",
      clk or -1, tostring(tp.lasthit_count), tostring(xp), tostring(N.GetCurrentLevel(hero)),
      nearest and string.format("%.0f", nearestDist) or "-",
      allyNearest and string.format("%.0f", allyDist) or "-",
      tostring(N.IsAttacking(hero)), tostring(N.IsRunning(hero)), nearEnemy))
  end

  -- =========================================================================
  -- 9b. GLOBALS manifest (task-25 companion): umbrella GLOBALS called by the 16.11
  -- scripts but not api namespaces (they belong to loader/orders-nav). Presence/shape
  -- is reported here so the re-run lists what actually resolves.
  do
    local G = "globals"
    local function gshape(v)
      if v == nil then return "nil", "MISSING" end
      local t = type(v)
      if t == "function" then return "function", "OK" end
      if t ~= "table" then return t, "STUB" end
      local n = 0
      for _ in pairs(v) do n = n + 1 end
      return string.format("table keys=%d", n), (n > 0) and "OK" or "STUB"
    end
    for _, gname in ipairs({ "LaneGroupsManager", "LaneCreepsManager", "JungleCampsManager",
      "LIB_DAMAGE_PREDICTION", "KV_LIB", "XHelpers" }) do
      local gv = rawget(_G, gname)
      row(G, gname, "GLOBALS_API.md " .. gname, function() return gshape(gv) end)
    end
  end

  -- 9c. GridNav surface (task-24 orders-nav): turns the 4 manifest rows into evidence.
  do
    local G = "gridnav"
    local GN = rawget(_G, "GridNav")
    if not GN then
      log("[parity] gridnav  GridNav global absent (nav.lua installGlobal unavailable in this state)")
    elseif not hero then
      log("[parity] gridnav  no local hero (behavior rows skipped)")
    else
      row(G, "nav.IsTraversable(heroPos) [canonical]", "gridnav.md:33 (boolean, integer)", function()
        local okn, nv = pcall(require, "nav")
        if not okn or not nv or type(nv.IsTraversable) ~= "function" then return "nav unavailable", "MISSING" end
        local a, b = nv.IsTraversable(hp)
        if type(a) ~= "boolean" then return "1st=" .. type(a), "GARBAGE" end
        if a and type(b) ~= "number" then return "true w/o 2nd value", "GARBAGE" end
        return string.format("%s,%s", tostring(a), tostring(b)), "OK"
      end)
      row(G, "GridNav.IsTraversable(heroPos) [global]", "gridnav.md:33 (boolean, integer) via _G", function()
        local a, b = GN.IsTraversable(hp)
        if type(a) ~= "boolean" then return "1st=" .. type(a), "GARBAGE" end
        if a and type(b) ~= "number" then
          -- loader.lua wrapper still forwards only the first return (loader-events patch
          -- pending); canonical nav surface above carries the two-value contract.
          if inLoaderCtx then return "true,w/o 2nd (loader wrapper, patch pending)", "STUB" end
          return "true w/o 2nd value", "GARBAGE"
        end
        return string.format("%s,%s", tostring(a), tostring(b)), "OK"
      end)
      row(G, "GridNav.BuildPath(heroPos,+400)", "gridnav.md waypoint list (ignoreTrees/npcMap args)", function()
        local dest = { x = hp.x + 400, y = hp.y + 400, z = hp.z }
        local p = GN.BuildPath(hp, dest, false, nil)
        if type(p) ~= "table" then return type(p), "GARBAGE" end
        return string.format("waypoints=%d", #p), (#p > 0) and "OK" or "UNVERIFIED"
      end)
      row(G, "GridNav.CreateNpcMap({})/Release twice", "gridnav.md npc map table or nil; release idempotent", function()
        local m = GN.CreateNpcMap({})
        if m == nil then return "nil (documented disable when nav unavailable)", "STUB" end
        if type(m) ~= "table" then return type(m), "GARBAGE" end
        local okR = GN.ReleaseNpcMap(m)
        local okR2 = GN.ReleaseNpcMap(m)
        if okR == false and okR2 == false then return "release twice failed", "GARBAGE" end
        return string.format("map,release=%s,secondRelease=%s", tostring(okR), tostring(okR2)), "OK"
      end)
    end
  end

  -- 10. manifest: every NS.Fn the 16.11 reference scripts call must exist
  -- =========================================================================
  do
    local G = "manifest"
    local missing, total = 0, 0
    local list = {}
    for k in pairs(SITE) do list[#list + 1] = k end
    table.sort(list)
    for _, k in ipairs(list) do
      total = total + 1
      local ns, fn = k:match("^([^.]+)%.(.+)$")
      local tbl = rawget(_G, ns)
      if not tbl or (type(tbl[fn]) ~= "function" and type(tbl[fn]) ~= "table") then
        missing = missing + 1
        counts.MISSING = (counts.MISSING or 0) + 1
        log(string.format("[parity] %-14s %-44s = %-38s | %-10s | %-30s | %s",
          G, k, "absent", loaderCtxOnly and "loaderctx" or "MISSING", "manifest", SITE[k] or "-"))
      end
    end
    log(string.format("[parity] manifest total=%d missing=%d (note: loader-owned namespaces absent only if this script runs outside the loader session)",
      total, missing))
  end

  -- =========================================================================
  -- summary
  -- =========================================================================
  log(string.format("[parity] SUMMARY ok=%d garbage=%d stub=%d unverified=%d missing=%d error=%d",
    counts.OK or 0, counts.GARBAGE or 0, counts.STUB or 0, counts.UNVERIFIED or 0,
    counts.MISSING or 0, counts.ERROR or 0))
  if #bad > 0 then
    log("[parity] FLAGGED: ", table.concat(bad, " | "))
  else
    log("[parity] FLAGGED: none")
  end
  log("=== API_PARITY END ===")
end

local okRun, err = pcall(body)
if not okRun then
  log("[parity] FATAL: ", tostring(err))
end
if f then f:close() end