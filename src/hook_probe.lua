package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ int InitOrders(void); ]]
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== HOOK PROBE ===")
local ok, lib = pcall(ffi.load, "D:\\hake\\lotus\\src\\host6.dll")
log("ffi.load", ok)
if ok then
  local ok2, r = pcall(function() return lib.InitOrders() end)
  log("InitOrders", ok2, r)
end
log("=== HOOK PROBE done ===")
