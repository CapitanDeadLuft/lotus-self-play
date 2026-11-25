local ffi = require("ffi")
local loader = require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[prof] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local ok, script, err = pcall(loader.load)
L("load ok=%s err=%s", tostring(ok), tostring(err))
if not ok then return end
-- warm one tick so load-time work is not sampled
local t0 = os.clock()
pcall(loader.tick)
L("warm tick %.2fs", os.clock() - t0)
-- sampling hook: record the Lua function that is executing
local counts, samples, stopAt = {}, 0, os.clock() + 4.0
local getinfo = debug.getinfo
local function hook()
  samples = samples + 1
  local info = getinfo(2, "Sl")
  local key = "?"
  if info then
    key = (info.short_src or "?") .. ":" .. tostring(info.currentline) .. " " .. (info.name or "?")
  end
  counts[key] = (counts[key] or 0) + 1
  if samples % 64 == 0 and os.clock() >= stopAt then debug.sethook() end
end
debug.sethook(hook, "", 2000)
local t1 = os.clock()
pcall(loader.tick)
debug.sethook()
local elapsed = os.clock() - t1
L("sampled tick %.2fs samples=%d", elapsed, samples)
local arr = {}
for k, v in pairs(counts) do arr[#arr + 1] = { k, v } end
table.sort(arr, function(a, b) return a[2] > b[2] end)
for i = 1, math.min(#arr, 20) do
  L("  %6d  %5.1f%%  %s", arr[i][2], 100.0 * arr[i][2] / math.max(1, samples), arr[i][1])
end
L("done")
