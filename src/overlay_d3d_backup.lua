-- overlay.lua — publishes HUD + ClickGUI draw commands to the in-game D3D11
-- renderer (render11). Drawn inside Dota by the Present hook => instant Del,
-- no external window, never covers other apps.
local ffi = require("ffi")
local M = {}
local menu = require("menu")

pcall(ffi.cdef, [[
  typedef struct { int kind; float x, y, z, w; unsigned int color; int size; char text[64]; } RCmd;
  typedef struct { float x, y, w, h; int id; } RHit;
  void R11_PublishHud(const RCmd*, int);
  void R11_PublishMenu(const RCmd*, int);
  void R11_PublishHits(const RHit*, int);
  void R11_SetMenuOpen(int);
  int R11_IsMenuOpen(void);
  int R11_DrainClicks(int*, int);
  float R11_TextWidth(const char*, int);
  int InitUI(void);
  int InitOrders(void);
  int DrainInput(unsigned int*, unsigned long long*, long long*, int);
]])

local hostlib
pcall(function()
  hostlib = ffi.load("D:\\hake\\lotus\\src\\host14.dll")
  hostlib.InitUI()
  hostlib.InitOrders()
end)

local menuOpen, activeTab = false, 1
local hitsLua, dropdown, bindCapture = {}, nil, nil

local C_BG = { r = 18, g = 20, b = 24 }; local C_PANEL = { r = 27, g = 30, b = 36 }
local C_ROW = { r = 35, g = 39, b = 47 }; local C_TEXT = { r = 232, g = 232, b = 236 }
local C_LABEL = { r = 154, g = 160, b = 168 }; local C_ACCENT = { r = 232, g = 70, b = 90 }
local C_OFF = { r = 58, g = 63, b = 72 }; local C_BORDER = { r = 42, g = 46, b = 54 }

local function argb(c)
  if type(c) ~= "table" then return 0xFFFFFFFF end
  return (c.a or 255) * 16777216 + (c.r or 255) * 65536 + (c.g or 255) * 256 + (c.b or 255)
end
function M.textWidth(t, s)
  if hostlib then return hostlib.R11_TextWidth(tostring(t or ""), s or 14) end
  return #tostring(t or "") * (s or 14) * 0.5
end

local menuCmds, hitArr = {}, {}
local function emit(k, x, y, z, w, c, s, t)
  menuCmds[#menuCmds + 1] = { kind = k, x = x, y = y, z = z or 0, w = w or 0, color = argb(c), size = s or 0, text = t or "" }
end
local function fill(x, y, w, h, c) emit(1, x, y, w, h, c) end
local function drawText(x, y, t, c, s) emit(0, x, y, 0, 0, c, s, tostring(t or "")) end
local function frameRect(x, y, w, h, c) fill(x, y, w, 1, c); fill(x, y + h - 1, w, 1, c); fill(x, y, 1, h, c); fill(x + w - 1, y, 1, h, c) end
local function addHit(x, y, w, h, rec) hitArr[#hitArr + 1] = { x = x, y = y, w = w, h = h }; hitsLua[#hitArr] = rec end
local function fitText(t, s, mw)
  t = tostring(t or ""); if M.textWidth(t, s) <= mw then return t end
  while #t > 1 and M.textWidth(t .. "...", s) > mw do t = t:sub(1, #t - 1) end
  return t .. "..."
end
local function comboLabel(w)
  local o = w.extra and w.extra.options or {}
  if w.kind == "multicombo" or w.kind == "multiselect" then
    local n = 0; if type(w.value) == "table" then for _ in pairs(w.value) do n = n + 1 end end; return n .. " selected"
  end
  local v = o[(tonumber(w.value) or 0) + 1]; if type(v) == "table" then v = v[1] end; return tostring(v or "")
end
local function keyName(v)
  v = tonumber(v) or 0; if v == 0 then return "None" end
  if v >= 0x70 and v <= 0x7B then return "F" .. (v - 0x6F) end
  if v >= 65 and v <= 90 then return string.char(v) end
  if v >= 48 and v <= 57 then return string.char(v) end
  return tostring(v)
end
local function scriptNode()
  local r = menu.tree[1]; if not r then return nil end
  local n = r.children[1] or r
  while n.children and #n.children == 1 do n = n.children[1] end
  return n
end
local function drawMenu(sw, sh)
  menuCmds, hitArr, hitsLua = {}, {}, {}
  local node = scriptNode(); if not node then return end
  local tabs = node.children or {}
  local W, H = 1000, 640
  local x0 = math.floor((sw - W) / 2); local y0 = math.floor((sh - H) / 2)
  fill(x0, y0, W, H, C_BG); frameRect(x0, y0, W, H, C_BORDER)
  drawText(x0 + 16, y0 + 12, "Self Play", C_LABEL, 14)
  local tab = tabs[activeTab]
  drawText(x0 + 86, y0 + 12, "/  " .. tostring(tab and tab.name or ""), C_ACCENT, 14)
  local tx, ty = x0 + 16, y0 + 40
  for i, t in ipairs(tabs) do
    local l = tostring(t.name or ""); local tw = M.textWidth(l, 13) + 24
    if i == activeTab then fill(tx, ty, tw, 26, C_ROW) end
    drawText(tx + 12, ty + 6, l, i == activeTab and C_ACCENT or C_LABEL, 13)
    addHit(tx, ty, tw, 26, { kind = "tab", idx = i }); tx = tx + tw + 6
  end
  local bodyY = ty + 34; local colW = math.floor((W - 48) / 2)
  local groups = (tab and tab.children) or {}; local colY = { bodyY, bodyY }
  for gi, g in ipairs(groups) do
    local col = ((gi - 1) % 2) + 1
    local gx = x0 + 16 + (col - 1) * (colW + 16); local gy = colY[col]
    local rows = g.widgets or {}; local gh = 30 + #rows * 30 + 8
    if gy + gh > y0 + H - 12 then gh = math.max(30, y0 + H - 12 - gy) end
    fill(gx, gy, colW, gh, C_PANEL); drawText(gx + 12, gy + 8, tostring(g.name or ""), C_LABEL, 12)
    local ry = gy + 30
    for _, w in ipairs(rows) do
      if ry + 30 > gy + gh then break end
      drawText(gx + 12, ry + 8, fitText(w.name, 13, colW - 190), w.disabled and C_OFF or C_TEXT, 13)
      local cx = gx + colW - 160
      if w.kind == "switch" then
        local on = w.value and true or false; local px = gx + colW - 46
        fill(px, ry + 8, 34, 16, on and C_ACCENT or C_OFF); fill(on and px + 18 or px + 2, ry + 10, 12, 12, C_TEXT)
        addHit(px, ry + 4, 40, 24, { kind = "switch", widget = w })
      elseif w.kind == "combo" or w.kind == "multicombo" or w.kind == "multiselect" then
        fill(cx, ry + 4, 150, 22, C_ROW); drawText(cx + 8, ry + 8, fitText(comboLabel(w), 12, 120), C_TEXT, 12)
        drawText(cx + 134, ry + 8, "v", C_LABEL, 12); addHit(cx, ry + 4, 150, 22, { kind = "combo", widget = w, x = cx, y = ry + 4 })
      elseif w.kind == "slider" then
        local mn, mx = w.extra.min or 0, w.extra.max or 100
        local t = math.max(0, math.min(1, ((tonumber(w.value) or mn) - mn) / math.max(1e-6, mx - mn)))
        fill(cx, ry + 14, 150, 4, C_OFF); fill(cx, ry + 14, math.floor(150 * t), 4, C_ACCENT)
        fill(cx + math.floor(150 * t) - 4, ry + 10, 8, 12, C_TEXT)
        drawText(cx - 40, ry + 8, tostring(math.floor((tonumber(w.value) or 0) + 0.5)), C_LABEL, 12)
        addHit(cx, ry + 4, 150, 24, { kind = "slider", widget = w, barX = cx, barW = 150 })
      elseif w.kind == "bind" then
        fill(gx + colW - 80, ry + 4, 70, 22, C_ROW)
        drawText(gx + colW - 72, ry + 8, bindCapture == w and "..." or keyName(w.value), C_TEXT, 12)
        addHit(gx + colW - 80, ry + 4, 70, 22, { kind = "bind", widget = w })
      elseif w.kind == "button" then
        fill(gx + colW - 100, ry + 4, 90, 22, C_ROW); drawText(gx + colW - 92, ry + 8, "Click", C_TEXT, 12)
        addHit(gx + colW - 100, ry + 4, 90, 22, { kind = "button", widget = w })
      elseif w.kind == "color" then
        fill(gx + colW - 40, ry + 6, 28, 18, type(w.value) == "table" and w.value or C_ACCENT)
      end
      ry = ry + 30
    end
    colY[col] = gy + gh + 12
  end
  if dropdown then
    local d = dropdown; local dh = #d.options * 24 + 8
    fill(d.x, d.y, d.w, dh, C_PANEL); frameRect(d.x, d.y, d.w, dh, C_BORDER)
    for i, o in ipairs(d.options) do
      local oy = d.y + 4 + (i - 1) * 24; local l = type(o) == "table" and o[1] or o
      local sel = d.multi and (type(d.widget.value) == "table" and d.widget.value[i] and true or false) or ((tonumber(d.widget.value) or 0) == (i - 1))
      if sel then fill(d.x + 2, oy, d.w - 4, 24, C_ROW) end
      drawText(d.x + 10, oy + 5, fitText(l, 12, d.w - 20), sel and C_ACCENT or C_TEXT, 12)
      addHit(d.x, oy, d.w, 24, { kind = "opt", idx = i, drop = d })
    end
  end
  if bindCapture then drawText(x0 + 16, y0 + H - 24, "Press a key for: " .. tostring(bindCapture.name), C_ACCENT, 12) end
end

local function publishCmds(fn, cmds)
  local n = #cmds
  if n == 0 then fn(nil, 0); return end
  local a = ffi.new("RCmd[?]", n)
  for i, c in ipairs(cmds) do
    a[i - 1].kind = c.kind; a[i - 1].x, a[i - 1].y, a[i - 1].z, a[i - 1].w = c.x, c.y, c.z, c.w
    a[i - 1].color = c.color; a[i - 1].size = c.size
    local t = c.text or ""; if #t > 63 then t = t:sub(1, 63) end
    ffi.copy(a[i - 1].text, t, #t)
  end
  fn(a, n)
end
local function publishHits()
  local n = #hitArr
  if n == 0 then hostlib.R11_PublishHits(nil, 0); return end
  local a = ffi.new("RHit[?]", n)
  for i, h in ipairs(hitArr) do a[i - 1].x, a[i - 1].y, a[i - 1].w, a[i - 1].h = h.x, h.y, h.w, h.h; a[i - 1].id = i end
  hostlib.R11_PublishHits(a, n)
end
local function hudFromFrame(frame)
  local c = {}
  for _, cmd in ipairs(frame or {}) do
    local d = cmd.data or {}
    if cmd.kind == "text" and d.text and d.text ~= "" then
      c[#c + 1] = { kind = 0, x = d.pos.x, y = d.pos.y, z = 0, w = 0, color = argb(d.color), size = d.size or 14, text = tostring(d.text) }
    elseif cmd.kind == "frect" then
      c[#c + 1] = { kind = 1, x = d.a.x, y = d.a.y, z = d.b.x - d.a.x, w = d.b.y - d.a.y, color = argb(d.color), size = 0, text = "" }
    elseif cmd.kind == "line" then
      c[#c + 1] = { kind = 2, x = d.a.x, y = d.a.y, z = d.b.x, w = d.b.y, color = argb(d.color), size = 0, text = "" }
    elseif cmd.kind == "circle" or cmd.kind == "fcircle" then
      c[#c + 1] = { kind = cmd.kind == "circle" and 3 or 4, x = d.pos.x, y = d.pos.y, z = d.radius or 4, w = 0, color = argb(d.color), size = 0, text = "" }
    end
  end
  return c
end

function M.present(frame)
  if not hostlib then return false end
  local sw, sh = 1920, 1080
  local ok, r = pcall(require, "render")
  if ok and r.ScreenSize then local s = r.ScreenSize(); sw, sh = s.x, s.y end
  menuOpen = hostlib.R11_IsMenuOpen() == 1
  publishCmds(hostlib.R11_PublishHud, hudFromFrame(frame))
  if menuOpen then
    drawMenu(sw, sh)
    publishCmds(hostlib.R11_PublishMenu, menuCmds)
    publishHits()
  else
    hostlib.R11_PublishMenu(nil, 0); hostlib.R11_PublishHits(nil, 0)
  end
  return true
end

local function applyClick(id)
  local h = hitsLua[id]; if not h then return end
  if h.kind == "tab" then activeTab = h.idx; dropdown = nil
  elseif h.kind == "switch" then h.widget:Set(not h.widget:Get())
  elseif h.kind == "combo" then dropdown = { widget = h.widget, x = h.x or 0, y = (h.y or 0) + 26, w = 150, options = h.widget.extra.options or {}, multi = (h.widget.kind ~= "combo") }
  elseif h.kind == "bind" then bindCapture = h.widget
  elseif h.kind == "button" then if h.widget.callback then pcall(h.widget.callback) end
  elseif h.kind == "opt" then
    local d = h.drop
    if d.multi then if type(d.widget.value) ~= "table" then d.widget.value = {} end; d.widget.value[h.idx] = not d.widget.value[h.idx]; if d.widget.callback then pcall(d.widget.callback) end
    else d.widget:Set(h.idx - 1) end
    dropdown = nil
  end
end
local lastPump = 0
function M.pump()
  local now = os.clock(); if now - lastPump < 0.03 then return end; lastPump = now
  if not hostlib then return end
  local ids = ffi.new("int[64]"); local n = hostlib.R11_DrainClicks(ids, 64)
  for i = 0, n - 1 do applyClick(ids[i]) end
  local msgs = ffi.new("unsigned int[64]"); local wps = ffi.new("unsigned long long[64]"); local lps = ffi.new("long long[64]")
  local kn = hostlib.DrainInput(msgs, wps, lps, 64)
  for i = 0, kn - 1 do
    if msgs[i] == 0x0100 then
      if bindCapture then bindCapture:Set(tonumber(wps[i])); bindCapture = nil
      elseif tonumber(wps[i]) == 27 then if dropdown then dropdown = nil else hostlib.R11_SetMenuOpen(0) end end
    end
  end
  if menuOpen then local ok, r = pcall(require, "render"); if ok then M.present(r.frame) end end
end
function M.isMenuOpen() return menuOpen end
function M.setMenuOpen(v) if hostlib then hostlib.R11_SetMenuOpen(v and 1 or 0) end end
return M
