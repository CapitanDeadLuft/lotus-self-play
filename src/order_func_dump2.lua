-- order_func_dump2.lua — dump full PrepareUnitOrders console handler (0x900 bytes) to find internal call.
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
local startRVA = 0x1FE7330
local size = 0x900
local src = ffi.cast("uint8_t*", cb + startRVA)
local f = io.open("D:\\hake\\lotus\\order_func_full.bin", "wb")
for i = 0, size - 1 do f:write(string.char(src[i])) end
f:close()
log("order_func_dump2: wrote order_func_full.bin base RVA=0x1FE7330 size=" .. size)