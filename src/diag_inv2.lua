require("loader")
local entity = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[inv2] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local inst = entity.instance(hero)
local inv = entity.debugReadQ(inst, 0x1238)
L("inv=0x%X", tonumber(inv) or 0)
for i = 0, 9 do
  local p = entity.debugReadQ(inv, 0x20 + i * 8)
  local name
  if p and p > 0x10000 then
    local ok, nm = pcall(entity.designerName, p)
    name = ok and nm or nil
  end
  L("  [8b] slot %d ptr=0x%s name=%s", i, p and string.format("%X", p) or "nil", tostring(name))
end
-- also 4-byte view for comparison
for i = 0, 5 do
  local h = entity.debugReadQ(inv, 0x20 + i * 4)
  L("  [4b] slot %d raw=0x%s", i, h and string.format("%X", h % 0x100000000) or "nil")
end
L("done")
