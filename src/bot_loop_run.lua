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
-- auto-mode harness: Self Play Role = Auto (0) for umbrella parity.
-- helpers.role() (Self Play.lua:300-318) returns the widget value only when it
-- is > 0; with 0 it falls back to planner.assignRoles(Heroes.GetAll()) (plus
-- party/draft overrides). Reference [SelfPlay] score lines show role=4 for
-- Treant, i.e. the planner path, not a forced widget.
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
    roleWidget:Set(0)  -- 0 = Auto -> helpers.role() -> planner.assignRoles(allies)
    _G.__roleWidget = roleWidget
    log("SELFPLAY role widget found name=", tostring(roleWidget.name),
      " value=", tostring(roleWidget:Get()), " (0 = Auto -> planner.assignRoles)")
  else
    log("SELFPLAY role widget NOT FOUND in menu.widgets (count=", #menu.widgets, ")")
  end
  -- Lane widget: Auto (0) as in the umbrella reference. helpers.lane()
  -- (Self Play.lua:320-325) returns ui.lane:Get() verbatim only when > 0; with 0
  -- the lane is derived from the role (role 4 -> offlane = 1/Top for Radiant).
  -- IMPORTANT: lane_choice.update() bails out immediately when
  -- (ctx.laneSetting or 0) ~= 0 (lane_choice.lua:91) — forcing lane 1 disabled the
  -- original lane-switch logic, which fires in 8/15 reference games. Self Play
  -- re-inits ctx when a widget changes (Self Play.lua:1797), so keep both at Auto.
  local laneWidget
  for _, w in ipairs(menu.widgets) do
    if w.kind == "combo" and type(w.extra) == "table" and type(w.extra.options) == "table" then
      local opts = w.extra.options
      local function opt(i) local o = opts[i]; return tostring(type(o) == "table" and o[1] or o) end
      local name = tostring(w.name or "")
      local byName = name == "Lane" or name == "Линия"
      local byOptions = #opts == 4 and (opt(2):find("Top") or opt(2):find("Верх"))
      if byName or byOptions then laneWidget = w; break end
    end
  end
  if laneWidget then
    laneWidget:Set(0)  -- 0 = Auto -> role-based lane + original lane_choice enabled
    _G.__laneWidget = laneWidget
    log("SELFPLAY lane widget found name=", tostring(laneWidget.name),
      " value=", tostring(laneWidget:Get()), " (0 = Auto -> role lane + lane_choice)")
  else
    log("SELFPLAY lane widget NOT FOUND in menu.widgets (count=", #menu.widgets, ")")
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
  for _ = 1, 4 do pcall(overlay.pump); pcall(loader.drawOnly); ffi.C.Sleep(10) end
end
log("=== BOT LOOP done ===")



