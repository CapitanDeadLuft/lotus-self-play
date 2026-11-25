-- diag_r11_mode.lua — QA live control + evidence dump for v4c.
-- Run by pointing run.txt at this file (host runs it in a fresh Lua state INSIDE
-- the injected process, so the host16.dll module handle is already present).
-- Reads desired settings from D:\hake\lotus\r11_mode.txt (all optional):
--     mode=0..7      -- R11_SetDrawMode bits (0 hook-only, 1 state-only, 2 HUD, 3 HUD+MENU, 7 all)
--     guard=2000     -- R11_SetDrawGuard(ms), 0 disables
--     modules=1      -- R11_LogModules() (default 1): logs host16 md5 + overlay/GameBar/nv/d3d module
--                       base/version (or NOT LOADED) + drawmode/mask/guard/cachedRtv/mtProtect/
--                       stageTrace/restoreRt1 flags — paste these lines as per-run evidence.
--     dump=1         -- R11_DiagDump() after applying (default 1)
-- Prints one "[qa-r11] …" line per action so host.log carries the evidence.
-- If an export cannot be resolved it logs and exits without side effects.

local ffi = require("ffi")

ffi.cdef[[
  void* GetModuleHandleA(const char* name);
  void* GetProcAddress(void* mod, const char* name);
  int  GetLastError(void);
]]

local function resolve(name)
  local h = ffi.C.GetModuleHandleA("host16.dll")
  if h == nil or ffi.cast("uintptr_t", h) == 0 then
    print("[qa-r11] ERROR host16.dll module not found err=" .. ffi.C.GetLastError())
    return nil
  end
  local p = ffi.C.GetProcAddress(h, name)
  if p == nil or ffi.cast("uintptr_t", p) == 0 then
    print("[qa-r11] ERROR export not found: " .. name)
    return nil
  end
  return p
end

-- defaults: always log modules + diag dump (reviewer requirement each run)
local mode, guard, modules, dump = nil, nil, 1, 1
local f = io.open("D:\\hake\\lotus\\r11_mode.txt", "r")
if f then
  for line in f:lines() do
    local k, v = line:match("^%s*([%w_]+)%s*=%s*(%-?%d+)%s*$")
    if k == "mode" then mode = tonumber(v)
    elseif k == "guard" then guard = tonumber(v)
    elseif k == "modules" then modules = tonumber(v)
    elseif k == "dump" then dump = tonumber(v) end
  end
  f:close()
  print(string.format("[qa-r11] config mode=%s guard=%s modules=%s dump=%s",
    tostring(mode), tostring(guard), tostring(modules), tostring(dump)))
else
  print("[qa-r11] config file absent (D:\\hake\\lotus\\r11_mode.txt) — defaults modules+dump only")
end

if mode ~= nil then
  local p = resolve("R11_SetDrawMode")
  if p then
    ffi.cast("void (*)(int)", p)(mode)
    print(string.format("[qa-r11] R11_SetDrawMode(%d) called", mode))
  end
end

if guard ~= nil then
  local p = resolve("R11_SetDrawGuard")
  if p then
    ffi.cast("void (*)(int)", p)(guard)
    print(string.format("[qa-r11] R11_SetDrawGuard(%d) called", guard))
  end
end

if modules ~= nil and modules ~= 0 then
  local p = resolve("R11_LogModules")
  if p then
    ffi.cast("void (*)(void)", p)()
    print("[qa-r11] R11_LogModules() called")
  end
end

if dump ~= nil and dump ~= 0 then
  local p = resolve("R11_DiagDump")
  if p then
    ffi.cast("void (*)(void)", p)()
    print("[qa-r11] R11_DiagDump() called")
  end
end

print("[qa-r11] done")