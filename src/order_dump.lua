-- order_dump.lua — dump client.dll .text window around PrepareUnitOrders xref to a file for disasm.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local C = ffi.C
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
ffi.cdef[[ void* GetModuleHandleA(const char* name); ]]
local client = C.GetModuleHandleA("client.dll")
local cb = ffi.cast("uintptr_t", client)
-- dump window 0x1FC6E00 .. 0x1FC7800 (RVA), base for rizin = 0x1FC6E00
local startRVA = 0x1FC6E00
local size = 0xA00
local src = ffi.cast("uint8_t*", cb + startRVA)
local f = io.open("D:\\hake\\lotus\\order_code.bin", "wb")
for i = 0, size - 1 do f:write(string.char(src[i])) end
f:close()
log("order_dump: wrote order_code.bin base RVA=" .. string.format("0x%X", startRVA) .. " size=" .. size)
-- also dump the other xref region 0x1F06900
local s2 = 0x1F06800
local src2 = ffi.cast("uint8_t*", cb + s2)
local f2 = io.open("D:\\hake\\lotus\\order_code2.bin", "wb")
for i = 0, 0x400 - 1 do f2:write(string.char(src2[i])) end
f2:close()
log("order_dump: wrote order_code2.bin base RVA=" .. string.format("0x%X", s2))