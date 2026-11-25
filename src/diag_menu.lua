package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local loader = require("loader")
local menu = require("menu")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("DIAG menu start")
local script, err = loader.load()
log("DIAG load=", tostring(script ~= nil), tostring(err))
local n = 0
for _, w in ipairs(menu.widgets) do
  n = n + 1
  if n <= 80 then log(string.format("W %d kind=%s name=%s value=%s", n, tostring(w.kind), tostring(w.name), tostring(w.value))) end
end
log("DIAG menu total=", n)
-- check the main enable switch state
for _, w in ipairs(menu.widgets) do
  if w.kind == "switch" and w.name and (w.name:find("Enable") or w.name:find("Self Play")) then
    log("DIAG switch:", w.name, "value=", tostring(w.value))
    if w.name:find("Self Play") and w.name:find("Enable") then w.value = true end
  end
end
log("DIAG menu done")