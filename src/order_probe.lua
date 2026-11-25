-- order_probe.lua — find "PrepareUnitOrders" string in client.dll .rdata (in-process) + xref in .text.
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
local secs = {}
for i = 0, nsec - 1 do
  local s = dos + secOff + i * 40
  local name = ffi.string(s, 8):gsub("%z", "")
  secs[name] = { va = ffi.cast("uint32_t*", s + 12)[0], vs = ffi.cast("uint32_t*", s + 8)[0],
                 raw = ffi.cast("uint32_t*", s + 20)[0], rs = ffi.cast("uint32_t*", s + 16)[0] }
end
log("=== order PROBE === client =", hex(client))
local rdata, text = secs[".rdata"], secs[".text"]
if not rdata or not text then log("no sections"); return end

-- scan .rdata for "PrepareUnitOrders"
local target = "PrepareUnitOrders"
local tlen = #target
local strRVAs = {}
local base = cb + rdata.va
local p = 0
while p < rdata.vs - tlen do
  local ok = true
  for j = 0, tlen - 1 do
    if ffi.cast("uint8_t*", base + p + j)[0] ~= target:byte(j + 1) then ok = false; break end
  end
  if ok then strRVAs[#strRVAs+1] = rdata.va + p end
  p = p + 1
end
log("string hits (RVA):", #strRVAs)
for i = 1, math.min(#strRVAs, 6) do log("  str RVA =", hex(strRVAs[i])) end

-- scan .text for lea reg,[rip+disp] referencing the first string RVA
if #strRVAs > 0 then
  local tgt = strRVAs[1]
  local tbase = cb + text.va
  local xrefs = {}
  local i = 0
  while i < text.rs - 7 do
    local b0 = ffi.cast("uint8_t*", tbase + i)[0]
    local off = i
    local rex = false
    if b0 >= 0x40 and b0 <= 0x4F then rex = true; off = off + 1 end
    if ffi.cast("uint8_t*", tbase + off)[0] == 0x8D then
      local modrm = ffi.cast("uint8_t*", tbase + off + 1)[0]
      if (modrm % 0x100) >= 0 and (modrm & 0xC7) == 0x05 then
        local disp = ffi.cast("int32_t*", tbase + off + 2)[0]
        local instrLen = (rex and 1 or 0) + 2 + 4
        local rip = text.va + i + instrLen
        if rip + disp == tgt then xrefs[#xrefs+1] = text.va + i end
      end
    end
    i = i + 1
  end
  log("xrefs to string (RVA):", #xrefs)
  for k = 1, math.min(#xrefs, 8) do log("  xref RVA =", hex(xrefs[k])) end
end
log("=== order PROBE done ===")