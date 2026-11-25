require("loader")
local entity = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(s) if f then f:write(os.date("%H:%M:%S ") .. "[inv6] " .. s .. "\n"); f:flush() end end
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local inst = entity.instance(hero)
local inv = entity.debugReadQ(inst, 0x1238)
L("inv=0x" .. string.format("%X", tonumber(inv) or 0))
-- hexdump 0x60 bytes at inv+0x20
for row = 0, 5 do
  local parts = {}
  for col = 0, 15 do
    local q = entity.debugReadQ(inv, 0x20 + row * 16 + col * 1)
    -- read single bytes instead: use q of 8-byte reads offset? simpler: read 8 bytes and take low
    parts[#parts + 1] = string.format("%02X", (q or 0) % 256)
  end
  L(string.format("  +0x%02X: %s", 0x20 + row * 16, table.concat(parts, " ")))
end
-- try: items as 8-byte entries where first 4 bytes = handle, second 4 = 0x8000
L("8-byte entries:")
for i = 0, 8 do
  local v = entity.debugReadQ(inv, 0x20 + i * 8)
  L(string.format("  [%d] raw=%s", i, v and string.format("0x%X", v) or "nil"))
end
L("done")
