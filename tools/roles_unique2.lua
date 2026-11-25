package.path = [[C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\?.lua;]] .. package.path
local catalog = require("self_play.catalog")
local planner = require("self_play.planner")
local list={"treant","necrolyte","skeleton_king","sven","warlock"}
local n=#list; local scores={}
for i,name in ipairs(list) do scores[i]=planner.roleScores(catalog.heroes["npc_dota_hero_"..name]) end
local best=-math.huge; local perms={}
local perm={}; local used={}
local function rec(i,sum)
  if i>n then
    if sum>best then best=sum; perms={{unpack(perm)}} elseif sum==best then perms[#perms+1]={unpack(perm)} end
    return
  end
  for r=1,5 do if not used[r] then used[r]=true; perm[i]=r; rec(i+1,sum+scores[i][r]); used[r]=nil end end
end
rec(1,0)
print("best", best, "#perms", #perms)
for _,p in ipairs(perms) do
  local parts={}
  for i,name in ipairs(list) do parts[#parts+1]=name.."="..p[i] end
  print(table.concat(parts, " "))
end
