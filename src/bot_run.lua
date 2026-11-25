-- bot_run.lua — load Self Play and run bot ticks in-game (OnUpdate/OnUpdateEx/OnDraw).
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local loader = require("loader")
local entity = require("entity")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}; for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== BOT RUN ===")
local script, err = loader.load()
if not script then log("LOAD FAILED:", err); return end
log("loaded; running 40 ticks ...")
for i = 1, 40 do
  loader.tick()
  if i % 10 == 0 then
    local ok, h = pcall(entity.getLocalHero)
    if ok and h then log(string.format("tick %d: hero=%s hp=%s team=%s", i, h.name, tostring(h.health), tostring(h.team)))
    else log("tick " .. i .. ": no local hero (not in-game?)") end
  end
  ffi.C.Sleep(100)
end
log("=== BOT RUN done ===")