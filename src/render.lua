-- render.lua — Render API (Umbrella-compatible). Drawing calls are collected into
-- M.frame and replayed per-frame by the native D3D11 Present hook (overlay.lua).
--
-- API contract: D:\hake\lotus\umbrella_api\render.md
--   FilledRect(start, end_, color, [rounding], [flags])
--   Rect(start, end_, color, [rounding], [flags], [thickness])   <-- 4th arg is ROUNDING
--   Circle(pos, radius, color, [thickness], [startDeg], [percentage], [rounded], [segments])
--   Line(start, end_, color, [thickness])
--   Text(font, size, text, pos, color)
--   TextSize(font, size, text) -> Vec2
--   WorldToScreen(pos) -> Vec2, bool
--   PushClip(start, end_, [intersect]) / PopClip()
-- Screen coordinates are top-left pixels of the D3D backbuffer.
local ffi = require("ffi")
local C = ffi.C
local mathx = require("mathx")
local M = {}
M.frame = {}   -- collected draw commands per frame

-- Render.Rect legacy mode: the pre-16.11 bridge treated the 4th argument as a
-- line thickness. Kept behind a flag so a bad change can be reverted without a
-- code edit (set _G.RENDER_LEGACY_RECT=true before loading the script).
local LEGACY_RECT = (_G.RENDER_LEGACY_RECT == true)

ffi.cdef[[
  void* GetModuleHandleA(const char* name);
  int GetSystemMetrics(int index);
  void* FindWindowA(const char* cls, const char* title);
  typedef struct { long left, top, right, bottom; } R_RECT;
  int GetWindowRect(void* h, R_RECT* r);
  int GetClientRect(void* h, R_RECT* r);
  typedef int (__stdcall *R_EnumProc)(void* h, long l);
  int EnumWindows(R_EnumProc cb, long l);
  unsigned long GetWindowThreadProcessId(void* h, unsigned long* pid);
  unsigned long GetCurrentProcessId(void);
  int IsWindowVisible(void* h);
]]
-- Steam creates many hidden "SDL_app" windows; FindWindowA picks the wrong one.
-- Resolve the real visible Dota window by own PID via EnumWindows (cached).
local _dotaH
local function dotaWindow()
  if _dotaH ~= nil then return _dotaH end
  local self = C.GetCurrentProcessId()
  local found = nil
  local cb = ffi.cast("R_EnumProc", function(h, l)
    local pid = ffi.new("unsigned long[1]")
    C.GetWindowThreadProcessId(h, pid)
    if pid[0] == self and C.IsWindowVisible(h) ~= 0 then
      local r = ffi.new("R_RECT")
      if C.GetWindowRect(h, r) ~= 0 and (r.right - r.left) > 400 then found = h; return 0 end
    end
    return 1
  end)
  C.EnumWindows(cb, 0)
  _dotaH = found or false
  return _dotaH
end
local clientBase = ffi.cast("uintptr_t", C.GetModuleHandleA("client.dll"))
local VIEWMATRIX_RVA = 0x6221CB0  -- build-specific (dumper)
-- the view matrix address is fixed for the process lifetime: cache the cast
local viewMatrix = ffi.cast("float*", clientBase + VIEWMATRIX_RVA)

-- authoritative draw-space size = D3D backbuffer (matches NDC mapping)
local _r11
local function backbufferSize()
  if _r11 == nil then
    local ok, lib = pcall(ffi.load, "D:\\hake\\lotus\\src\\host16.dll")
    if ok and lib then pcall(ffi.cdef, "void R11_Size(int*, int*);"); _r11 = lib else _r11 = false end
  end
  if _r11 then
    local w, h = ffi.new("int[1]"), ffi.new("int[1]")
    local ok = pcall(_r11.R11_Size, w, h)
    if ok and w[0] > 100 and h[0] > 100 then return w[0], h[0] end
  end
  return nil
end
local function screenSize()
  local bw, bh = backbufferSize()
  if bw then return bw, bh end
  local h = dotaWindow()
  if h then
    local r = ffi.new("R_RECT")
    if C.GetClientRect(h, r) ~= 0 then
      local w, hh = r.right - r.left, r.bottom - r.top
      if w > 100 and hh > 100 then return w, hh end
    end
  end
  local w = C.GetSystemMetrics(0); local h2 = C.GetSystemMetrics(1)
  if w == 0 then w = 1920 end; if h2 == 0 then h2 = 1080 end
  return w, h2
end
function M.dotaOrigin()
  local h = dotaWindow()
  if h then
    local r = ffi.new("R_RECT")
    if C.GetWindowRect(h, r) ~= 0 then return r.left, r.top end
  end
  return 0, 0
end

local Render = {}
-- Project with row-major layout; fall back to transposed; reject garbage so
-- stale/wrong matrices never draw stray lines across the screen.
local function project(m, x, y, z, transposed)
  local w, sx, sy
  if transposed then
    w = m[3] * x + m[7] * y + m[11] * z + m[15]
    if w < 0.001 then return nil end
    sx = (m[0] * x + m[4] * y + m[8] * z + m[12]) / w
    sy = (m[1] * x + m[5] * y + m[9] * z + m[13]) / w
  else
    w = m[12] * x + m[13] * y + m[14] * z + m[15]
    if w < 0.001 then return nil end
    sx = (m[0] * x + m[1] * y + m[2] * z + m[3]) / w
    sy = (m[4] * x + m[5] * y + m[6] * z + m[7]) / w
  end
  if sx ~= sx or sy ~= sy then return nil end
  if sx < -1.35 or sx > 1.35 or sy < -1.35 or sy > 1.35 then return nil end
  return sx, sy
end
-- WorldToScreen returns a Vec2 carrying the world position (wx/wy/wz) so that
-- world-space line/circle calls are projected per-frame by the native renderer
-- (no 1-frame lag / jitter while the camera moves).
function Render.WorldToScreen(pos)
  if type(pos) ~= "table" then return mathx.Vec2(0, 0), false end
  local x, y, z = pos.x or 0, pos.y or 0, pos.z or 0
  local m = viewMatrix
  local sx, sy = project(m, x, y, z, false)
  if not sx then sx, sy = project(m, x, y, z, true) end
  if not sx then return mathx.Vec2(0, 0), false end
  local sw, sh = screenSize()
  return { x = sw * 0.5 * (1 + sx), y = sh * 0.5 * (1 - sy), wx = x, wy = y, wz = z }, true
end
mathx.WorldToScreen = Render.WorldToScreen

function Render.ScreenSize() local w, h = screenSize(); return mathx.Vec2(w, h) end
function Render.LoadFont(name, flags, weight) return { name = name, flags = flags, weight = weight } end
function Render.LoadImage(path) return { path = path } end
function Render.LoadSvg(path) return Render.LoadImage(path) end
function Render.LoadSvgString(str) return { data = str } end
function Render.ImageSize(img) return mathx.Vec2(0, 0) end
-- TextSize MUST return exactly the advance width the native renderer uses for
-- the same (font, size, text), because hud.lua right/center-aligns everything
-- from it. Both sides share the same glyph table (R11_TextWidthW), so routing
-- through it is exact by construction; the old #text*size*0.5 heuristic is a
-- last resort and logs [ui] textwidth-fallback once so QA can spot it.
local uiFallbackLogged = false
local function logUiOnce(msg)
  uiFallbackLogged = true
  -- offline harnesses set this so tests can never write the live host.log
  if _G.HAKE_TEST_SILENT_MENU_LOG then return end
  local f = io.open("D:\\hake\\lotus\\host.log", "a")
  if f then f:write(string.format("%s %s\n", os.date("%H:%M:%S"), msg)); f:close() end
end
function Render.TextSize(font, size, text)
  local s = tostring(text or "")
  size = size or 14
  if s == "" then return mathx.Vec2(0, size) end
  local ok, w, exact = pcall(function() return require("overlay").textWidth(s, size, font) end)
  if ok and type(w) == "number" and w == w and w >= 0 then
    if not exact and not uiFallbackLogged then
      logUiOnce("[ui] textwidth-fallback: R11_TextWidthW unavailable, using estimate")
    end
    return mathx.Vec2(w, size)
  end
  if not uiFallbackLogged then
    logUiOnce("[ui] textwidth-fallback: overlay.textWidth failed, using estimate")
  end
  return mathx.Vec2(#s * size * 0.5, size)
end

-- helpers ----------------------------------------------------------------
local function xy(v)
  if type(v) == "table" then return tonumber(v.x or v[1]) or 0, tonumber(v.y or v[2]) or 0 end
  return 0, 0
end
local function num(v, d) v = tonumber(v); if v == nil or v ~= v then return d end; return v end
local function push(kind, data) M.frame[#M.frame + 1] = { kind = kind, data = data } end

-- clip stack: emitted as commands so the native renderer can apply scissor
-- rects (kinds 10/11). Until the native side supports them the commands are
-- harmless no-ops; the stack is still tracked for renderer parity.
local clipStack = {}
local function clipDepth() return #clipStack end

function Render.Text(font, size, text, pos, color)
  if text == nil then return end
  local x, y = xy(pos)
  push("text", { font = font, size = size or 14, text = text, pos = { x = x, y = y }, color = color })
end
-- Umbrella: Line(start, end_, color, [thickness])
function Render.Line(a, b, color, thickness)
  if type(a) ~= "table" or type(b) ~= "table" then return end
  local t = num(thickness, 1)
  if a.wx and b.wx then
    push("wline", { a = a, b = b, color = color, thickness = t })
  else
    local ax, ay = xy(a); local bx, by = xy(b)
    push("line", { a = { x = ax, y = ay }, b = { x = bx, y = by }, color = color, thickness = t })
  end
end
-- Umbrella: Circle(pos, radius, color, [thickness], [startDeg], [percentage],
--                   [rounded], [segments])
local function arcSegments(startDeg, pct, segments)
  local n = tonumber(segments)
  if not n or n < 2 then n = math.floor(96 * math.min(1, math.max(0.05, pct))) + 2 end
  if n > 180 then n = 180 end
  return n
end
function Render.Circle(pos, radius, color, thickness, startDeg, percentage, rounded, segments)
  local r = num(radius, 0); if r <= 0 then return end
  local t = num(thickness, 1.5)
  local pct = tonumber(percentage)
  local start = math.rad(num(startDeg, 0))
  if pct and pct < 0.999 then
    -- arc: emit line segments (screen space; arcs are never used as world cmds
    -- by the scripts, so the Lua-projected position is fine)
    local cx, cy = xy(pos)
    local n = arcSegments(startDeg, pct, segments)
    local span = math.rad(360) * math.max(0, pct)
    local px, py = cx + math.cos(start) * r, cy + math.sin(start) * r
    for i = 1, n do
      local a = start + span * i / n
      local nx, ny = cx + math.cos(a) * r, cy + math.sin(a) * r
      push("line", { a = { x = px, y = py }, b = { x = nx, y = ny }, color = color, thickness = t })
      px, py = nx, ny
    end
    return
  end
  if type(pos) == "table" and pos.wx then
    push("wcircle", { pos = pos, radius = r, color = color, thickness = t })
  else
    local cx, cy = xy(pos)
    push("circle", { pos = { x = cx, y = cy }, radius = r, color = color, thickness = t })
  end
end
-- Umbrella: CircleGradient(pos, radius, colorOuter, colorInner, [startDeg], [percentage])
function Render.CircleGradient(pos, radius, colorOuter, colorInner, startDeg, percentage)
  Render.FilledCircle(pos, radius, colorInner or colorOuter)
  if colorOuter then Render.Circle(pos, radius, colorOuter, 1.5) end
end
function Render.FilledCircle(pos, radius, color)
  local r = num(radius, 0); if r <= 0 then return end
  if type(pos) == "table" and pos.wx then
    push("wfcircle", { pos = pos, radius = r, color = color })
  else
    local cx, cy = xy(pos)
    push("fcircle", { pos = { x = cx, y = cy }, radius = r, color = color })
  end
end
-- Umbrella: FilledRect(start, end_, color, [rounding], [flags])
function Render.FilledRect(a, b, color, rounding, flags)
  local ax, ay = xy(a); local bx, by = xy(b)
  push("frect", { a = { x = ax, y = ay }, b = { x = bx, y = by }, color = color, rounding = num(rounding, 0) })
end
-- quarter arc helper for rounded frames: line segments from a0 to a1 (radians)
local function arcLines(cx, cy, r, a0, a1, color, thickness, segs)
  segs = math.max(3, math.floor(segs or 5))
  local px, py = cx + math.cos(a0) * r, cy + math.sin(a0) * r
  for i = 1, segs do
    local a = a0 + (a1 - a0) * i / segs
    local nx, ny = cx + math.cos(a) * r, cy + math.sin(a) * r
    push("line", { a = { x = px, y = py }, b = { x = nx, y = ny }, color = color, thickness = thickness })
    px, py = nx, ny
  end
end
-- Umbrella: Rect(start, end_, color, [rounding], [flags], [thickness])
-- NOTE: before 16.11 the 4th argument was mis-read as thickness; LEGACY_RECT
-- restores that (wrong) behaviour for a fast rollback.
function Render.Rect(a, b, color, rounding, flags, thickness)
  local ax, ay = xy(a); local bx, by = xy(b)
  local t = num(thickness, 1)
  local r = num(rounding, 0)
  if LEGACY_RECT then
    t = num(rounding, 1); r = 0
  end
  local x0, x1 = math.min(ax, bx), math.max(ax, bx)
  local y0, y1 = math.min(ay, by), math.max(ay, by)
  if r <= 0.01 or (x1 - x0) < 2 or (y1 - y0) < 2 then
    push("line", { a = { x = x0, y = y0 }, b = { x = x1, y = y0 }, color = color, thickness = t })
    push("line", { a = { x = x1, y = y0 }, b = { x = x1, y = y1 }, color = color, thickness = t })
    push("line", { a = { x = x1, y = y1 }, b = { x = x0, y = y1 }, color = color, thickness = t })
    push("line", { a = { x = x0, y = y1 }, b = { x = x0, y = y0 }, color = color, thickness = t })
    return
  end
  r = math.min(r, (x1 - x0) * 0.5, (y1 - y0) * 0.5)
  local segs = math.max(3, math.min(8, math.ceil(r)))
  -- straight edges
  push("line", { a = { x = x0 + r, y = y0 }, b = { x = x1 - r, y = y0 }, color = color, thickness = t })
  push("line", { a = { x = x0 + r, y = y1 }, b = { x = x1 - r, y = y1 }, color = color, thickness = t })
  push("line", { a = { x = x0, y = y0 + r }, b = { x = x0, y = y1 - r }, color = color, thickness = t })
  push("line", { a = { x = x1, y = y0 + r }, b = { x = x1, y = y1 - r }, color = color, thickness = t })
  -- corners (screen y grows downwards; angles measured with y down)
  local PI = math.pi
  arcLines(x0 + r, y0 + r, r, PI, PI * 1.5, color, t, segs)      -- top-left
  arcLines(x1 - r, y0 + r, r, PI * 1.5, PI * 2, color, t, segs)  -- top-right
  arcLines(x1 - r, y1 - r, r, 0, PI * 0.5, color, t, segs)        -- bottom-right
  arcLines(x0 + r, y1 - r, r, PI * 0.5, PI, color, t, segs)       -- bottom-left
end
function Render.Image(img, pos, size, color) push("image", { img = img, pos = pos, size = size }) end
function Render.ImageCentered(img, pos, size, color)
  local cx, cy = xy(pos); local w, h = xy(size)
  push("image", { img = img, pos = { x = cx - w * 0.5, y = cy - h * 0.5 }, size = size })
end
-- Umbrella: PushClip(start, end_, [intersect]) / PopClip()
function Render.PushClip(a, b, intersect)
  local ax, ay = xy(a); local bx, by = xy(b)
  local rect = { x0 = math.min(ax, bx), y0 = math.min(ay, by), x1 = math.max(ax, bx), y1 = math.max(ay, by) }
  if intersect and clipStack[#clipStack] then
    local p = clipStack[#clipStack]
    rect.x0 = math.max(rect.x0, p.x0); rect.y0 = math.max(rect.y0, p.y0)
    rect.x1 = math.min(rect.x1, p.x1); rect.y1 = math.min(rect.y1, p.y1)
  end
  clipStack[#clipStack + 1] = rect
  push("clip", { a = { x = rect.x0, y = rect.y0 }, b = { x = rect.x1, y = rect.y1 } })
end
function Render.PopClip()
  if #clipStack == 0 then return end
  clipStack[#clipStack] = nil
  push("unclip", {})
end
function Render.clipRect() local c = clipStack[#clipStack]; return c and { x0 = c.x0, y0 = c.y0, x1 = c.x1, y1 = c.y1 } or nil end

-- remaining Umbrella render helpers: safe no-ops (not used by Self Play 16.11,
-- present so other scripts never hit "attempt to call a nil value")
function Render.Shadow(...) end
function Render.ShadowCircle(...) end
function Render.ShadowNGon(...) end
function Render.ShadowConvexPoly(...) end
function Render.Blur(...) end
function Render.Gradient(...) end
function Render.OutlineGradient(...) end
function Render.StartRotation(...) end
function Render.StopRotation(...) end
function Render.ResetGlobalAlpha(...) end
function Render.MarkDirtyRT(...) end
function Render.FindOrCreateRT(...) return nil end
function Render.ResizeRT(...) end
function Render.RenderRT(...) end
function Render.Triangle(...) end
function Render.FilledTriangle(...) end
function Render.PolyLine(...) end
function Render.TexturedPoly(...) end
function Render.DonutChart(...) end
function Render.Logo(...) end
function Render.RoundedProgressRect(...) end
function Render.CenteredNotification(...) end

function M.beginFrame() M.frame = {}; clipStack = {} end
M.Render = Render
M.ScreenSize = Render.ScreenSize
M.legacyRect = LEGACY_RECT
return M