-- order_sig.lua — scan client.dll .text for PrepareUnitOrders pattern "E8 ? ? ? ? F3 44 0F 11 53".
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local C = ffi.C
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function hex(v) return string.format("0x%X", tonumber(ffi.cast("uintptr_t", v))) end
ffi.cdef[[ void* GetModuleHandleA(const char* name); ]]
local client = C.GetModuleHandleA("client.dll")
local cb = ffi.cast("uintptr_t", client)
local dos = ffi.cast("uint8_t*", client)
local peOff = ffi.cast("uint32_t*", dos + 0x3C)[0]
local pe = dos + peOff
local nsec = ffi.cast("uint16_t*", pe + 6)[0]
local optSize = ffi.cast("uint16_t*", pe + 20)[0]
local secOff = peOff + 24 + optSize
local text
for i = 0, nsec - 1 do
  local s = dos + secOff + i * 40
  if ffi.string(s, 8):gsub("%z", "") == ".text" then
    text = { va = ffi.cast("uint32_t*", s + 12)[0], rs = ffi.cast("uint32_t*", s + 16)[0] }
  end
end
log("=== order SIG === client =", hex(client))
if not text then log("no .text"); return end
local tbase = cb + text.va
-- pattern: E8 ?? ?? ?? ?? F3 44 0F 11 53
local function matchAt(i)
  local b = ffi.cast("uint8_t*", tbase + i)
  return b[0] == 0xE8 and b[5] == 0xF3 and b[6] == 0x44 and b[7] == 0x0F and b[8] == 0x11 and b[9] == 0x53
end
local hits = {}
local i = 0
while i < text.rs - 10 do
  if matchAt(i) then
    local disp = ffi.cast("int32_t*", tbase + i + 1)[0]
    local callRVA = text.va + i
    local targetRVA = callRVA + 5 + disp
    hits[#hits+1] = { call = callRVA, target = targetRVA }
  end
  i = i + 1
end
log("pattern hits =", #hits)
for k = 1, math.min(#hits, 8) do
  log(string.format("  call RVA=%s -> PrepareUnitOrders RVA=%s", hex(hits[k].call), hex(hits[k].target)))
end
-- save first target to a file for the order module
if #hits > 0 then
  local f = io.open("D:\\hake\\lotus\\order_rva.txt", "w")
  f:write(string.format("0x%X", hits[1].target)); f:close()
  log("saved order_rva.txt =", hex(hits[1].target))
end
log("=== order SIG done ===")