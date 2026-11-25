-- diag_perf2.lua — replicate exactly what bot_loop does, timing each step
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ unsigned long long GetTickCount64(void); ]]
local loader = require("loader")
local render = require("render")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function now() return tonumber(ffi.C.GetTickCount64()) / 1000.0 end
local function step(tag, fn)
  local a = now()
  local ok, err = pcall(fn)
  local dt = now() - a
  log(string.format("[perfd2] %s = %.3fs ok=%s %s", tag, dt, tostring(ok), ok and "" or tostring(err)))
  return dt
end

log("[perfd2] === start ===")
local t0 = now()
local script = loader.load()
log(string.format("[perfd2] load = %.2fs ok=%s", now() - t0, tostring(script ~= nil)))
if not script then return end

local overlay = require("overlay")
for i = 1, 3 do
  local total = now()
  step(i .. ".beginFrame", function() render.beginFrame() end)
  step(i .. ".pump", function() overlay.pump() end)
  step(i .. ".OnUpdateEx", function() if script.OnUpdateEx then script.OnUpdateEx() end end)
  step(i .. ".OnUpdate", function() if script.OnUpdate then script.OnUpdate() end end)
  step(i .. ".OnDraw", function() if script.OnDraw then script.OnDraw() end end)
  step(i .. ".present", function() overlay.present(render.frame) end)
  log(string.format("[perfd2] tick%d TOTAL = %.3fs", i, now() - total))
end
log("[perfd2] === done ===")