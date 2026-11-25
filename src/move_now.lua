package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local entity = require("entity")
local orders = require("orders")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== MOVE NOW ===")
entity.init(); orders.init()
local h = entity.getLocalHero()
if not h then log("no hero"); return end
local x, y, z = orders.heroPosition(h.instance)
log(string.format("hero %s hp=%s at %.0f %.0f %.0f", h.name, tostring(h.health), x or 0, y or 0, z or 0))
local ok, err = orders.prepare(1, 0, { (x or 0) + 900, (y or 0) + 500, z or 128 }, 0, h.instance, false, true)
log("move ret", tostring(ok), tostring(err))
ffi.C.Sleep(700)
local h2 = entity.getLocalHero()
local x2, y2 = orders.heroPosition(h2 and h2.instance)
log(string.format("after %.0f %.0f delta %.0f", x2 or 0, y2 or 0, (x and x2) and math.sqrt((x2-x)^2+(y2-y)^2) or -1))
log("=== MOVE NOW done ===")
