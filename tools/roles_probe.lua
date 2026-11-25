package.path = [[C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\?.lua;C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\?\init.lua;]] .. package.path
local catalog = require("self_play.catalog")
local planner = require("self_play.planner")
local function roles(list)
  local entries = {}
  for i, name in ipairs(list) do
    local h = catalog.heroes["npc_dota_hero_"..name]
    if not h then print("MISSING", name); return end
    entries[i] = {id = i, scores = planner.roleScores(h)}
  end
  local r = planner.assignRoles(entries)
  for i, name in ipairs(list) do
    local s = planner.roleScores(catalog.heroes["npc_dota_hero_"..name])
    print(string.format("%-20s role=%d scores=(%s)", name, r[i], table.concat(s, ",")))
  end
end
print("=== match1 comp (Treant, Drow, Warlock, DK, Sniper) ===")
roles({"treant","drow_ranger","warlock","dragon_knight","sniper"})
print("=== match3 comp (Treant, Necrolyte, SK, Sven, Warlock) ===")
roles({"treant","necrolyte","skeleton_king","sven","warlock"})
print("=== ref S1 enemy comp ===")
roles({"axe","silencer","zuus","skeleton_king","sniper"})
