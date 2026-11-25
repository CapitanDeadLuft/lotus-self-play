package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[ void* GetModuleHandleA(const char*); ]]
local entity = require("entity")
local schema = require("schema")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
entity.init()
local h = entity.getLocalHero()
if not h then log("no hero"); return end
local x, y, z = (function()
  local i = h.instance
  local node = tonumber(ffi.cast("uintptr_t*", i + (schema.offsetOf("C_BaseEntity","m_pGameSceneNode") or 816))[0])
  local o = schema.offsetOf("CGameSceneNode","m_vecAbsOrigin") or 216
  return tonumber(ffi.cast("float*",node+o)[0]), tonumber(ffi.cast("float*",node+o+4)[0]), tonumber(ffi.cast("float*",node+o+8)[0])
end)()
local cb = ffi.cast("uintptr_t", C.GetModuleHandleA("client.dll"))
local m = ffi.cast("float*", cb + 0x6221CB0)
local vals = {}
for i = 0, 15 do vals[#vals+1] = string.format("%.3f", m[i]) end
log("=== VM === hero", string.format("%.0f,%.0f,%.0f", x, y, z))
log("matrix", table.concat(vals, " "))
local function proj(tr)
  local w, sx, sy
  if tr then
    w = m[3]*x + m[7]*y + m[11]*z + m[15]
    if w < 0.001 then return nil end
    sx = (m[0]*x + m[4]*y + m[8]*z + m[12]) / w
    sy = (m[1]*x + m[5]*y + m[9]*z + m[13]) / w
  else
    w = m[12]*x + m[13]*y + m[14]*z + m[15]
    if w < 0.001 then return nil end
    sx = (m[0]*x + m[1]*y + m[2]*z + m[3]) / w
    sy = (m[4]*x + m[5]*y + m[6]*z + m[7]) / w
  end
  return sx, sy, w
end
local a = { proj(false) }
local b = { proj(true) }
log("rowmajor", a[1] and string.format("ndc %.2f,%.2f w %.2f -> px %.0f,%.0f", a[1], a[2], a[3], 960*(1+a[1]), 540*(1-a[2])) or "nil")
log("transposed", b[1] and string.format("ndc %.2f,%.2f w %.2f -> px %.0f,%.0f", b[1], b[2], b[3], 960*(1+b[1]), 540*(1-b[2])) or "nil")
log("=== VM done ===")
