require("loader")
local entity = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[inv4] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local inst = entity.instance(hero)
local inv = entity.debugReadQ(inst, 0x1238)
L("inv=0x%X", tonumber(inv) or 0)
if not inv or inv < 0x10000 then L("bad inv"); return end
-- try 8-byte stride, low u32 as CHandle, and also raw 4-byte stride for comparison
for i = 0, 8 do
  local v = entity.debugReadQ(inv, 0x20 + i * 8)
  local h = v and (v % 0x100000000) or nil
  local ent
  if h and h ~= 0 and h ~= 0xFFFFFFFF then
    local ok, e = pcall(Entity.GetEntityByHandle, h); ent = ok and e or nil
  end
  L("  stride8 slot %d low=0x%s ent=%s", i, h and string.format("%X", h) or "nil",
    ent and (NPC.GetUnitName(ent) or "?") or "nil")
end
for i = 0, 10 do
  local h = entity.debugReadQ(inv, 0x20 + i * 4)
  local lo = h and (h % 0x100000000) or nil
  local ent
  if lo and lo ~= 0 and lo ~= 0xFFFFFFFF then
    local ok, e = pcall(Entity.GetEntityByHandle, lo); ent = ok and e or nil
  end
  L("  stride4 slot %d lo=0x%s ent=%s", i, lo and string.format("%X", lo) or "nil",
    ent and (NPC.GetUnitName(ent) or "?") or "nil")
end
L("done")
