require("loader")
local entity = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[inv7] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local items = NPC.GetItems(hero) or {}
L("GetItems count=%d", #items)
for i, it in ipairs(items) do L("   %d = %s", i, tostring(NPC.GetUnitName(it))) end
for _, nm in ipairs({ "item_tpscroll", "item_tango", "item_clarity", "item_magic_stick", "item_ward_observer" }) do
  L("GetItem(%s)=%s", nm, tostring(NPC.GetItem(hero, nm) ~= nil))
end
L("done")
