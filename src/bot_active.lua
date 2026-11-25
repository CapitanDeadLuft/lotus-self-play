-- bot_active.lua — load Self Play, enable the bot, run ticks, watch hero position for activity.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local loader = require("loader")
local entity = require("entity")
local menu = require("menu")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}; for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== BOT ACTIVE ===")
local script, err = loader.load()
if not script then log("LOAD FAILED:", err); return end
-- enable the bot: find the Enabled switch
local enabledCount = 0
for _, w in ipairs(menu.widgets) do
  if w.kind == "switch" and w.name:find("Enable Self Play") then
    w.value = true; enabledCount = enabledCount + 1
    log("enabled widget:", w.name)
  end
end
log("enabled switches:", enabledCount)
local function heroPos()
  local ok, h = pcall(entity.getLocalHero)
  if ok and h then
    local ok2, x, y, z = pcall(entity.heroPosition or function() return nil end)
    return h
  end
  return nil
end
local orders = require("orders")
for i = 1, 80 do
  loader.tick()
  if i % 20 == 0 then
    local ok, h = pcall(entity.getLocalHero)
    if ok and h then
      local x, y, z = orders.heroPosition(h.instance)
      log(string.format("tick %d: %s hp=%s pos=%.0f,%.0f,%.0f", i, h.name, tostring(h.health), x or 0, y or 0, z or 0))
    else log("tick " .. i .. ": no hero: " .. tostring(h)) end
  end
  ffi.C.Sleep(100)
end
log("=== BOT ACTIVE done ===")