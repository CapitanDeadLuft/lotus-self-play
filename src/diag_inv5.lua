require("loader")
local entity = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[inv5] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local inst = entity.instance(hero)
L("instance=0x%X", tonumber(inst) or 0)
local function showHandle(tag, h)
  local ent
  if h and h ~= 0 and h ~= 0xFFFFFFFF then
    local ok, e = pcall(Entity.GetEntityByHandle, h); ent = ok and e or nil
  end
  L("  %s handle=0x%s -> %s", tag, h and string.format("%X", h) or "nil", ent and (NPC.GetUnitName(ent) or "(noname)") or "nil")
end
-- A) embedded: slots at instance + 0x1238 + 0x20
L("A) embedded m_Inventory at 0x1238")
for i = 0, 9 do
  local h = entity.debugReadQ(inst, 0x1238 + 0x20 + i * 4)
  showHandle("A slot " .. i, h and (h % 0x100000000) or nil)
end
-- B) pointer: deref then slots
local inv = entity.debugReadQ(inst, 0x1238)
L("B) pointer path inv=0x%X", tonumber(inv) or 0)
if inv and inv > 0x10000 then
  for i = 0, 9 do
    local h = entity.debugReadQ(inv, 0x20 + i * 4)
    showHandle("B slot " .. i, h and (h % 0x100000000) or nil)
  end
  -- inventory back-pointer check: m_hInventoryParent at +0xA8
  local parent = entity.debugReadQ(inv, 0xA8)
  L("B m_hInventoryParent=0x%s (instance=0x%s)", parent and string.format("%X", parent) or "nil", string.format("%X", tonumber(inst) or 0))
end
L("done")
