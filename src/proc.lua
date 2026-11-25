-- proc.lua — process/module discovery via WinAPI Toolhelp32 (LuaJIT FFI).
-- Used by the reader to locate dota2.exe and the bases of client/engine2/schemasystem.
local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
  typedef unsigned long DWORD;
  typedef void* HANDLE;
  typedef int BOOL;
  typedef unsigned long long ULONG_PTR;
  typedef wchar_t WCHAR;
  HANDLE CreateToolhelp32Snapshot(DWORD flags, DWORD pid);
  BOOL CloseHandle(HANDLE h);
  typedef struct {
    DWORD dwSize; DWORD cntUsage; DWORD th32ProcessID;
    ULONG_PTR th32DefaultHeapID; DWORD th32ModuleID; DWORD cntThreads;
    DWORD th32ParentProcessID; int pcPriClassBase; DWORD dwFlags;
    WCHAR szExeFile[260];
  } PROCESSENTRY32W;
  BOOL Process32FirstW(HANDLE h, PROCESSENTRY32W* e);
  BOOL Process32NextW(HANDLE h, PROCESSENTRY32W* e);
  typedef struct {
    DWORD dwSize; DWORD th32ModuleID; DWORD th32ProcessID;
    DWORD GlblcntUsage; DWORD ProccntUsage;
    unsigned char* modBaseAddr; DWORD modBaseSize; void* hModule;
    WCHAR szModule[256]; WCHAR szExePath[260];
  } MODULEENTRY32W;
  BOOL Module32FirstW(HANDLE h, MODULEENTRY32W* e);
  BOOL Module32NextW(HANDLE h, MODULEENTRY32W* e);
]]

local TH32CS_SNAPPROCESS = 0x2
local TH32CS_SNAPMODULE  = 0x8
local TH32CS_SNAPMODULE32 = 0x10
local INVALID = ffi.cast("HANDLE", ffi.cast("intptr_t", -1))

local M = {}

-- convert WCHAR[] to lua string
local function w2s(arr)
  local len = 0
  while arr[len] ~= 0 do len = len + 1 end
  if len == 0 then return "" end
  local buf = ffi.new("char[?]", len * 4 + 4)
  local n = C.WideCharToMultiByte(65001, 0, arr, len, buf, len * 4, nil, nil)
  return ffi.string(buf, n)
end

ffi.cdef[[ int WideCharToMultiByte(unsigned int cp, DWORD flags, const WCHAR* src, int srcLen, char* dst, int dstLen, const char* def, BOOL* used); ]]

function M.list()
  local out = {}
  local snap = C.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
  if snap == INVALID then return out end
  local e = ffi.new("PROCESSENTRY32W")
  e.dwSize = ffi.sizeof(e)
  if M.debug then print("sizeof PROCESSENTRY32W = " .. ffi.sizeof(e)) end
  if C.Process32FirstW(snap, e) ~= 0 then
    local n = 0
    repeat
      n = n + 1
      if M.debug and n % 200 == 0 then print("  iter " .. n .. " pid=" .. tonumber(e.th32ProcessID)) end
      if n > 8192 then break end
      out[#out+1] = { pid = tonumber(e.th32ProcessID), name = w2s(e.szExeFile) }
    until C.Process32NextW(snap, e) == 0
  end
  C.CloseHandle(snap)
  return out
end

function M.find(name)
  name = name:lower()
  for _, p in ipairs(M.list()) do
    if p.name:lower() == name then return p.pid end
  end
  return nil
end

function M.modules(pid)
  local out = {}
  local snap = C.CreateToolhelp32Snapshot(bit.bor(TH32CS_SNAPMODULE, TH32CS_SNAPMODULE32), pid)
  if snap == INVALID then return out, "snapshot failed (err=" .. ffi.errno() .. ")" end
  local e = ffi.new("MODULEENTRY32W")
  e.dwSize = ffi.sizeof(e)
  if C.Module32FirstW(snap, e) ~= 0 then
    repeat
      out[#out+1] = {
        name = w2s(e.szModule):lower(),
        base = ffi.cast("uintptr_t", e.modBaseAddr),
        size = tonumber(e.modBaseSize),
        path = w2s(e.szExePath),
      }
    until C.Module32NextW(snap, e) == 0
  end
  C.CloseHandle(snap)
  return out
end

function M.findModule(pid, name)
  name = name:lower()
  for _, m in ipairs(M.modules(pid)) do
    if m.name == name then return m end
  end
  return nil
end

return M