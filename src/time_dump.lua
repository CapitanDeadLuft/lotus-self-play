package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local entity = require("entity")
local schema = require("schema")
local C = ffi.C
ffi.cdef[[ void* GetModuleHandleA(const char* name); ]]
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
entity.init()
local h = entity.getLocalHero()
local off = schema.offsetOf("C_BaseEntity", "m_flSimulationTime") or 952
log("=== TIME ===", h and h.name or "nohero", "simOff", off)
if h and h.instance then
  local sim = tonumber(ffi.cast("float*", h.instance + off)[0])
  local create = tonumber(ffi.cast("float*", h.instance + (schema.offsetOf("C_BaseEntity", "m_flCreateTime") or 992))[0])
  log(string.format("hero sim=%.3f create=%.3f", sim, create))
end
local cb = ffi.cast("uintptr_t", C.GetModuleHandleA("client.dll"))
local slot = tonumber(ffi.cast("uintptr_t*", cb + 0x6219008)[0])
local proxy = tonumber(ffi.cast("uintptr_t*", slot + 0x08)[0])
local real = tonumber(ffi.cast("uintptr_t*", proxy + 0x5f0)[0])
local function f32(p, o) return tonumber(ffi.cast("float*", p + o)[0]) end
log(string.format("proxy sim=%.3f real+0x594 start=%.3f real+952=%.3f proxy+952=%.3f",
  f32(proxy, off), f32(real, 0x594), f32(real, off), f32(proxy, off)))
-- nearby floats on real gamerules around start time, to spot curtime
local base = 0x580
local parts = {}
for o = base, base + 0x40, 4 do
  parts[#parts+1] = string.format("%X:%.2f", o, f32(real, o))
end
log("gamerules", table.concat(parts, " "))
log("=== TIME done ===")
