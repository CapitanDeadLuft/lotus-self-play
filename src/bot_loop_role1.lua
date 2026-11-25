-- bot_loop_role1.lua — bot_loop.lua + force Self Play Role = 1 (Carry) at load.
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
      w.value = false
    end
  end
end
-- role-acceptance harness: force Self Play Role = 1 (Carry) at load time.
-- Widget identity: Self Play.lua:95 `Combo("Role", {"Auto","1 Carry",...})`,
-- localized to "Position"/"Позиция" (translations.lua:27 + localization.lua:32),
-- stored only in menu.widgets (no Config persistence -> must be set per state).
-- Value is a 0-based option index: 0 = Auto, 1 = "1 Carry" ... 5 = "5 Hard support".
do
  local roleWidget
  for _, w in ipairs(menu.widgets) do
    if w.kind == "combo" and type(w.extra) == "table" and type(w.extra.options) == "table" then
      local opts = w.extra.options
      local function opt(i) local o = opts[i]; return tostring(type(o) == "table" and o[1] or o) end
      local name = tostring(w.name or "")
      local byName = name == "Role" or name == "Position" or name == "Позиция"
      local byOptions = #opts == 6 and (opt(1):find("Auto") or opt(1):find("Авто"))
      if byName or byOptions then roleWidget = w; break end
    end
  end
  if roleWidget then
    roleWidget:Set(1)  -- 1 = "1 Carry" (0 = Auto)
    log("SELFPLAY role widget found name=", tostring(roleWidget.name),
      " value=", tostring(roleWidget:Get()), " (1 = 1 Carry)")
  else
    log("SELFPLAY role widget NOT FOUND in menu.widgets (count=", #menu.widgets, ")")
  end
end
local overlay = require("overlay")
local n = 0
while true do
  local stop = io.open("D:\\hake\\lotus\\stop.txt", "r")
  if stop then stop:close(); log("stop.txt"); break end
  n = n + 1
  local t0 = os.clock()
  pcall(entity.beginTick)
  loader.tick()
  local h = entity.getLocalHero()
  local x, y = 0, 0
  if h then local px, py = orders.heroPosition(h.instance); x = tonumber(px) or 0; y = tonumber(py) or 0 end
  local gt = 0
  if _G.GameRules and _G.GameRules.GetGameTime then local ok, v = pcall(_G.GameRules.GetGameTime); if ok and type(v) == "number" then gt = v end end
  log(string.format("loop %d %.1fs %s hp=%s %.0f %.0f gt=%.1f", n, os.clock() - t0, h and h.name or "nil", h and tostring(h.health) or "-", x or 0, y or 0, gt))
  for _ = 1, 4 do pcall(overlay.pump); pcall(loader.drawOnly); ffi.C.Sleep(10) end
end
log("=== BOT LOOP done ===")
