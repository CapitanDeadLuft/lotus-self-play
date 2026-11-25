-- bot_loop.lua — keep Self Play ticking until D:\hake\lotus\stop.txt appears.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local loader = require("loader")
local entity = require("entity")
local menu = require("menu")
local orders = require("orders")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== BOT LOOP ===")
local script, err = loader.load()
if not script then log("LOAD FAIL", err); return end
for _, w in ipairs(menu.widgets) do
  if w.kind == "switch" and w.name then
    local n = w.name
    if n:find("Turn the bot on") or n:find("Enable Self Play") then
      w.value = true
    elseif n:find("Show what it's doing") or n:find("Show what the bot") or n:find("Show status") then
      w.value = true
    elseif n:find("Show win chance") or n:find("Show winchance") then
      w.value = true
    elseif n:find("Show where it goes") or n:find("Show where the bot is going") then
      w.value = true
    elseif n:find("Download builds") or n:find("Download item builds") or n:find("Загружать сборки") then
      -- online stats need real HTTP; keep off so the HUD shows no provider error
      w.value = false
    end
  end
end
local overlay = require("overlay")
local n = 0
while true do
  local stop = io.open("D:\\hake\\lotus\\stop.txt", "r")
  if stop then stop:close(); log("stop.txt"); break end
  n = n + 1
  local t0 = os.clock()
  -- per-tick entity snapshot (entity.lua task-17): one identity-list walk and
  -- one handle-map build per loop instead of a rebuild every 50 ms
  pcall(entity.beginTick)
  loader.tick()
  local h = entity.getLocalHero()
  local x, y = nil, nil
  if h then x, y = orders.heroPosition(h.instance) end
  local gt = 0
  if _G.GameRules and _G.GameRules.GetGameTime then local ok, v = pcall(_G.GameRules.GetGameTime); if ok and type(v) == "number" then gt = v end end
  log(string.format("loop %d %.1fs %s hp=%s %.0f %.0f gt=%.1f", n, os.clock() - t0, h and h.name or "nil", h and tostring(h.health) or "-", x or 0, y or 0, gt))
  -- keep GUI input responsive between ticks
  for _ = 1, 4 do pcall(overlay.pump); pcall(loader.drawOnly); ffi.C.Sleep(10) end
end
log("=== BOT LOOP done ===")
