local loader = require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[micro] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local okL, err = pcall(loader.tick)
L("tick ok=%s", tostring(okL))
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local N = 2000
local function bench(name, fn)
  local ok, err2 = pcall(fn)  -- warm
  if not ok then L("%s ERROR %s", name, tostring(err2)); return end
  local t0 = os.clock()
  local ok2, err3 = pcall(function() for _ = 1, N do fn() end end)
  local dt = os.clock() - t0
  if not ok2 then L("%s ERROR %s", name, tostring(err3)); return end
  L("%s: %.2f us/call", name, dt / N * 1e6)
end
bench("Entity.IsEntity", function() return Entity.IsEntity(hero) end)
bench("Entity.IsAlive", function() return Entity.IsAlive(hero) end)
bench("Entity.GetTeamNum", function() return Entity.GetTeamNum(hero) end)
bench("Entity.GetAbsOrigin", function() return Entity.GetAbsOrigin(hero) end)
bench("Entity.GetHealth", function() return Entity.GetHealth(hero) end)
bench("Entity.GetIndex", function() return Entity.GetIndex(hero) end)
bench("Entity.IsSameTeam", function() return Entity.IsSameTeam(hero, hero) end)
bench("NPC.GetUnitName", function() return NPC.GetUnitName(hero) end)
bench("Heroes.GetLocal", function() return Heroes.GetLocal() end)
bench("Players.GetLocal", function() return Players.GetLocal() end)
bench("GameRules.GetGameTime", function() return GameRules.GetGameTime() end)
bench("NPC.HasModifier", function() return NPC.HasModifier(hero, "modifier_treant_living_armor") end)
bench("Entity.GetOwner", function() return Entity.GetOwner(hero) end)
L("done")
