-- diag_clock.lua — dump gamerules time-ish fields to correlate with HUD clock
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local api = require("api")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
ffi.cdef[[ unsigned long long GetTickCount64(void); void Sleep(unsigned long ms); ]]
local gr = api.rawGamerules and api.rawGamerules()
log("DIAG clock start; gamerules=", tostring(gr))
local offs = { gold = 0x578, xp = 0x57C, spawn = 0x580, announce = 0x584,
               pregame = 0x590, gamestart = 0x594, gameend = 0x598, load = 0x59C,
               state = 0x7C }
for i = 1, 6 do
  local wall = tonumber(ffi.C.GetTickCount64()) / 1000.0
  local parts = {}
  for name, off in pairs(offs) do
    local v = 0
    if gr then
      local ok = pcall(function()
        if name == "state" then v = tonumber(ffi.cast("int32_t*", gr + off)[0])
        else v = tonumber(ffi.cast("float*", gr + off)[0]) end
      end)
      if not ok then v = -999 end
    end
    parts[#parts + 1] = string.format("%s=%.2f", name, v)
  end
  local ok, gt = pcall(api.GameRules.GetGameTime)
  log(string.format("DIAG wall=%.1f gt=%s %s", wall, tostring(gt), table.concat(parts, " ")))
  ffi.C.Sleep(5000)
end
log("DIAG clock done")