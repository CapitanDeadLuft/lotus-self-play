-- orders_test.lua — validate orders.lua module: move hero to a new position.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local orders = require("orders")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== orders MODULE test ===")
local ok, err = orders.init(); log("init:", ok, err)
if not ok then return end
local x, y, z = orders.heroPosition()
log(string.format("current pos: %.1f %.1f %.1f", x, y, z))
local ret = orders.moveTo(x - 250, y, z)
log("moveTo(x-250) returned:", ret)
log("=== orders MODULE test done ===")