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
entity.init(); orders.init()
local function snap(tag)
  local h = entity.getLocalHero()
  local x, y = orders.heroPosition(h and h.instance)
  log(string.format("%s %s hp=%s %.0f %.0f", tag, h and h.name or "nil", h and tostring(h.health) or "-", x or 0, y or 0))
  return x, y
end
local x0, y0 = snap("now")
ffi.C.Sleep(1500)
local x1, y1 = snap("later")
log(string.format("delta %.0f", (x0 and x1) and math.sqrt((x1-x0)^2+(y1-y0)^2) or -1))
