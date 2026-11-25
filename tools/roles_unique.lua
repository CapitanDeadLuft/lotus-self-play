package.path = [[C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\?.lua;]] .. package.path
local catalog = require("self_play.catalog")
local planner = require("self_play.planner")
local function test(list)
  local n=#list
  local scores={}
  for i,name in ipairs(list) do
    scores[i]=planner.roleScores(catalog.heroes["npc_dota_hero_"..name])
    print(string.format("%-16s scores: %s", name, table.concat(scores[i], ",")))
  end
  local best, bestCount, bestPerm = -math.huge, 0, nil
  local perm={}
  local used={}
  local function rec(i, sum)
    if i>n then
      if sum>best then best, bestCount, bestPerm = sum, 1, {unpack(perm)} elseif sum==best then bestCount=bestCount+1 end
      return
    end
    for r=1,5 do
      if not used[r] then used[r]=true; perm[i]=r; rec(i+1, sum+scores[i][r]); used[r]=nil end
    end
  end
  rec(1,0)
  print("best total:", best, "optimal permutations:", bestCount)
  if bestCount==1 then
    for i,name in ipairs(list) do print("  ", name, "role", bestPerm[i]) end
  end
end
print("=== match1 comp ===")
test({"treant","drow_ranger","warlock","dragon_knight","sniper"})
print("=== match3 comp ===")
test({"treant","necrolyte","skeleton_king","sven","warlock"})

