require("loader")
local ent = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[des] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local hero = Heroes.GetLocal()
L("hero=%s", tostring(hero))
if hero then
  L("unitNameOf/GetUnitName = %s", tostring(NPC.GetUnitName(hero)))
  L("entity.designerName     = %s", tostring(ent.designerName(hero)))
  local hits = ent.debugStrings(hero, 0x300, 8)
  L("identity npc_ strings: %d", #hits)
  for i = 1, math.min(#hits, 8) do
    L("   identity+0x%X -> %s", hits[i].off, hits[i].s)
  end
  -- also scan the entity instance (not identity) in case the name lives there
  local inst = ent.instance(hero)
  if inst then
    local ih = ent.debugStrings and ent.debugStrings(inst, 0x400, 8) or {}
    L("instance npc_ strings: %d", #ih)
    for i = 1, math.min(#ih, 8) do L("   inst+0x%X -> %s", ih[i].off, ih[i].s) end
  end
end
-- how many entities expose a designer name at all
local dn = ent.debugNames(5)
L("names total=%d named=%d npc=%d", dn.total, dn.named, dn.npc)
for _, s in ipairs(dn.sample) do L("   sample=%s", tostring(s.name)) end
L("done")
