local ffi = require("ffi")
ffi.cdef[[void* OpenProcess(unsigned long,int,unsigned long);int CloseHandle(void*);unsigned long GetLastError(void);]]
local pid = tonumber(arg[1]) or 27156
local masks = { {0x1000,"QUERY_LIMITED"}, {0x0400,"QUERY_INFO"}, {0x0010,"VM_READ"}, {0x043A,"INJECT"}, {0x001F0FFF,"ALL"} }
for _, m in ipairs(masks) do
  local h = ffi.C.OpenProcess(m[1], 0, pid)
  local ok = (h ~= nil and ffi.cast("uintptr_t", h) ~= 0)
  if ok then
    print(string.format("%-14s mask=0x%X -> OK", m[2], m[1]))
    ffi.C.CloseHandle(h)
  else
    print(string.format("%-14s mask=0x%X -> FAIL err=%d", m[2], m[1], ffi.C.GetLastError()))
  end
end