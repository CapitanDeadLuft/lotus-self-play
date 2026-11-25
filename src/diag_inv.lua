require("loader")
local entity = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[inv] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
L("hero=%s", tostring(NPC.GetUnitName(hero)))
local inst = entity.instance(hero)
L("instance=0x%X", tonumber(inst) or 0)
-- inventory object: C_DOTA_BaseNPC::m_pInventory? try schema names
local schema = require("schema")
local cands = { "m_pInventory", "m_hInventory", "m_Inventory" }
local invOff
for _, n in ipairs(cands) do
  local ok, off = pcall(schema.offsetOf, "C_DOTA_BaseNPC", n)
  if ok and off then L("C_DOTA_BaseNPC.%s = 0x%X", n, off); invOff = invOff or off end
end
if not invOff then L("no inventory field found in schema") end
-- read handles from several candidate bases
local function dump(tag, base, slotsOff)
  if not base or base < 0x10000 then L("%s: bad base", tag); return end
  local parts = {}
  for i = 0, 8 do
    local h = entity.debugReadQ and nil or nil
    parts[#parts + 1] = "?"
  end
end
-- direct: try reading handle u32 at instance + inventoryOffset + 0x20 + i*4
if invOff then
  local inv = entity.debugReadQ(inst, invOff)
  L("inventory ptr=0x%X", tonumber(inv) or 0)
  if inv and inv > 0x10000 then
    for i = 0, 8 do
      local h = entity.debugReadQ(inv, 0x20 + i * 4)
      local lo = h and (h % 0x100000000) or nil
      local ent
      if lo and lo ~= 0 and lo ~= 0xFFFFFFFF then
        local ok, e = pcall(Entity.GetEntityByHandle, lo)
        ent = ok and e or nil
      end
      L("  slot %d raw64=0x%s lo=0x%s entity=%s", i, h and string.format("%X", h) or "nil",
        lo and string.format("%X", lo) or "nil", ent and (NPC.GetUnitName(ent) or "?") or "nil")
    end
  end
end
L("done")
