require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[inv3] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local items = NPC.GetItems(hero) or {}
L("NPC.GetItems count=%d", #items)
for i, it in ipairs(items) do L("   item %d = %s", i, tostring(NPC.GetUnitName(it))) end
for i = 0, 8 do
  local it = NPC.GetItemByIndex(hero, i)
  L("   slot %d -> %s", i, it and tostring(NPC.GetUnitName(it)) or "nil")
end
L("GetItem(tpscroll)=%s", tostring(NPC.GetItem(hero, "item_tpscroll") ~= nil))
L("GetItem(tango)=%s", tostring(NPC.GetItem(hero, "item_tango") ~= nil))
L("done")
