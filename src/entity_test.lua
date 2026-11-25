-- entity_test.lua — validate the clean entity.lua module API.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local entity = require("entity")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== entity MODULE test ===")
local ok, err = entity.init()
log("init:", ok, err)
if not ok then return end
local heroes = entity.getHeroes()
log("heroes count =", #heroes)
for _, h in ipairs(heroes) do
  if not h.name:find("announcer") then
    log(string.format("  %s hp=%s/%s team=%s", h.name, tostring(h.health), tostring(entity.maxHealth(h.identity)), tostring(h.team)))
  end
end
local creeps = entity.findAll("npc_dota_creep")
log("creeps count =", #creeps)
local lh = entity.getLocalHero()
if lh then log(string.format("getLocalHero: %s hp=%s team=%s pid=%s", lh.name, tostring(lh.health), tostring(lh.team), tostring(lh.playerID)))
else log("getLocalHero: nil") end
log("=== entity MODULE test done ===")