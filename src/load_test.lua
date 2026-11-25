-- load_test.lua — load Self Play via the loader, report first errors.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local loader = require("loader")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== LOAD TEST ===")
local script, err = loader.load()
if script then
  log("LOAD OK. running one tick ...")
  loader.tick()
  log("tick done")
else
  log("LOAD FAILED:", err)
end
log("=== LOAD TEST done ===")