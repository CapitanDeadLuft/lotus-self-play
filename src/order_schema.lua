-- order_schema.lua — dump CUnitOrders + order-related controller fields via schema reader.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local schema = require("schema")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== order SCHEMA ===")
local ok, err = schema.init(); log("init:", ok, err)
if not ok then return end
for _, cn in ipairs({ "CUnitOrders", "C_DOTAPlayerController" }) do
  local rec, e = schema.getClass(cn)
  if rec then
    log("class " .. cn .. " size=" .. rec.size)
    -- sort fields by offset
    local arr = {}
    for nm, off in pairs(rec.fields) do arr[#arr+1] = { nm = nm, off = off } end
    table.sort(arr, function(a, b) return a.off < b.off end)
    for _, f in ipairs(arr) do
      if cn == "CUnitOrders" or f.nm:find("Order") or f.nm:find("order") then
        log(string.format("  0x%X %s", f.off, f.nm))
      end
    end
  else
    log("class " .. cn .. " : " .. tostring(e))
  end
end
log("=== order SCHEMA done ===")