-- diag_qa_inventory.lua — QA one-shot: hero inventory + team data + fog + clock (read-only).
-- Run: Set-Content run.txt this path; call_elevated.bat <dota pid>  (RunHost, runs alongside live loop).
-- Output: host.log lines prefixed "QA_INV".
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local mathx = require("mathx")
local unpack = table.unpack or unpack
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. "QA_INV\t" .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function ok(fn, ...)
  local r = { pcall(fn, ...) }
  if not r[1] then return nil, tostring(r[2]) end
  return unpack(r, 2)
end

log("BEGIN")
local okReg, err = pcall(function() require("api").register() end)
log("api.register", tostring(okReg), tostring(err))
if not okReg then log("END"); return end

local hero = Heroes.GetLocal()
if not hero then log("no local hero"); log("END"); return end
log("hero", NPC.GetUnitName(hero), "level", tostring(NPC.GetCurrentLevel(hero)),
    "hp", tostring(Entity.GetHealth(hero)), "/", tostring(Entity.GetMaxHealth(hero)))

-- inventory slots (0..5 main, 6..8 backpack, 9..15 stash/other as returned)
local count = 0
for slot = 0, 16 do
  local item = ok(NPC.GetItemByIndex, hero, slot)
  if item then
    count = count + 1
    local nm = ok(Ability.GetName, item)
    local ch = _G.Item and ok(Item.GetCurrentCharges, item) or nil
    local co = _G.Item and ok(Item.GetCost, item) or nil
    log("slot", slot, "item", tostring(nm), "charges", tostring(ch), "cost", tostring(co))
  end
end
log("items", count)

-- team data (scoreboard/networth/lasthits proof for api-core)
local okP, data = ok(Player.GetTeamPlayer, Players.GetLocal())
log("GetTeamPlayer ok", tostring(okP), "data", type(data) == "table" and "table" or tostring(data))
if type(data) == "table" then
  local keys = {}
  for k in pairs(data) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  for _, k in ipairs(keys) do log("teamPlayer." .. k, tostring(data[k])) end
end
local okD, tdata = ok(Player.GetTeamData, Players.GetLocal())
log("GetTeamData ok", tostring(okD), "data", type(tdata) == "table" and "table" or tostring(tdata))
if type(tdata) == "table" then
  for _, k in ipairs({ "kills", "deaths", "assists", "level", "networth", "lasthit_count",
                       "deny_count", "reliable_gold", "unreliable_gold", "total_earned_gold",
                       "lane_selection_flags" }) do
    log("teamData." .. k, tostring(tdata[k]))
  end
end
for _, p in ipairs(Players.GetAll()) do
  local ok2, d = ok(Player.GetTeamData, p)
  if type(d) == "table" then
    log("player", tostring(ok(Entity.GetPlayerID, p) or "?"), "team", tostring(ok(Entity.GetTeamNum, p)),
        "nw", tostring(d.networth), "lh", tostring(d.lasthit_count), "dn", tostring(d.deny_count),
        "k", tostring(d.kills), "d", tostring(d.deaths), "a", tostring(d.assists), "lvl", tostring(d.level))
  else
    log("player row missing", tostring(ok2))
  end
end

-- clock
log("gt", tostring(ok(GameRules.GetGameTime)), "matchid", tostring(ok(GameRules.GetMatchID)),
    "state", tostring(ok(GameRules.GetGameState)), "paused", tostring(ok(GameRules.IsPaused)))

-- fog: expect BOTH true and false across the map; all-true => stub
local p = Entity.GetAbsOrigin(hero)
local pts = {}
if p then pts[#pts + 1] = { "hero", p.x, p.y, p.z } end
pts[#pts + 1] = { "ourFountain", -6700, -6700, 384 }
pts[#pts + 1] = { "enemyFountain", 7000, 7000, 384 }
pts[#pts + 1] = { "midRiver", 0, 0, 128 }
pts[#pts + 1] = { "enemyT2top", -1600, 5800, 128 }
pts[#pts + 1] = { "enemyT2bot", 5800, -1600, 128 }
local FoW = _G.FogOfWar
if FoW then
  for _, q in ipairs(pts) do
    local pos = mathx.Vector(q[2], q[3], q[4])
    log("fow", q[1], "IsPointVisible", tostring(ok(FoW.IsPointVisible, pos)),
        "IsVisible", tostring(ok(FoW.IsVisible, pos)))
  end
else
  log("fow namespace missing")
end

-- purchase / courier state
local courier = ok(Couriers.GetLocal)
log("courier", tostring(courier))
log("END")



