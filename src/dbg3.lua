io.stdout:setvbuf("no")
local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
  typedef unsigned long DWORD; typedef void* HANDLE; typedef int BOOL;
  typedef unsigned long long ULONG_PTR; typedef wchar_t WCHAR;
  HANDLE CreateToolhelp32Snapshot(DWORD, DWORD);
  BOOL CloseHandle(HANDLE);
  typedef struct {
    DWORD dwSize; DWORD cntUsage; DWORD th32ProcessID;
    ULONG_PTR th32DefaultHeapID; DWORD th32ModuleID; DWORD cntThreads;
    DWORD th32ParentProcessID; long pcPriClassBase; DWORD dwFlags;
    WCHAR szExeFile[260];
  } PE32W;
  BOOL Process32FirstW(HANDLE, PE32W*);
  BOOL Process32NextW(HANDLE, PE32W*);
  int WideCharToMultiByte(unsigned int, DWORD, const WCHAR*, int, char*, int, const char*, BOOL*);
]]
print("sizeof PE32W = " .. ffi.sizeof("PE32W"))
local snap = C.CreateToolhelp32Snapshot(2, 0)
print("snap ok")
local e = ffi.new("PE32W")
e.dwSize = ffi.sizeof(e)
local ok = C.Process32FirstW(snap, e)
print("FirstW = " .. tostring(ok) .. " pid=" .. tonumber(e.th32ProcessID))
local n = 0
while ok and n < 2000 do
  n = n + 1
  if n % 200 == 0 then print("  iter " .. n .. " pid=" .. tonumber(e.th32ProcessID)) end
  ok = C.Process32NextW(snap, e)
end
print("loop done, iterations=" .. n .. " lastOK=" .. tostring(ok))
C.CloseHandle(snap)
print("ALL OK")