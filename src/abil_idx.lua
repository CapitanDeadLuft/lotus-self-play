package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local loader = require("loader")
local entity = require("entity")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
loader.load()
local h = Heroes.GetLocal()
log("=== ABIL IDX === hero", h, Entity.GetClassName(h))
for i = 0, 6 do
  local a = NPC.GetAbilityByIndex(h, i)
  log(string.format("[%d] type=%s val=%s name=%s idx=%s level=%s", i, type(a), tostring(a),
    a and Ability.GetName(a) or "-", a and tostring(Entity.GetIndex(a)) or "-", a and tostring(Ability.GetLevel(a)) or "-"))
end
log("=== ABIL IDX done ===")
