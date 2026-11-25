-- overlay.lua — publishes HUD + ClickGUI draw commands to the in-game D3D11
-- renderer (render11) and drives ClickGUI input. Drawn inside Dota by the
-- Present hook => instant Del, per-frame markers, no external window.
--
-- Menu tree model (see menu.lua):
--   root tab (e.g. "Scripts") > section ("Self Play") > second tab ("Main")
--   > third tab ("Main"/"Search and pick"/"What the bot does") > groups > widgets
-- Everything below is plain Lua + RCmd structs so a Lua hot-reload needs no
-- native rebuild.
local ffi = require("ffi")
local M = {}
local menu = require("menu")

pcall(ffi.cdef, [[
  typedef struct { int kind; float x, y, z, w; unsigned int color; int size; char text[64]; float x2, y2, z2; } RCmd;
  typedef struct { float x, y, w, h; int id; } RHit;
  void R11_PublishHud(const RCmd*, int);
  void R11_PublishMenu(const RCmd*, int);
  void R11_PublishHits(const RHit*, int);
  void R11_PublishMenuRect(float, float, float, float);
  int R11_HitTestScreen(float, float);
  void R11_SetMenuOpen(int);
  void SetMenuOpen(int);
  int R11_IsMenuOpen(void);
  int R11_DrainClicks(int*, int);
  void R11_Size(int*, int*);
  float R11_TextWidth(const char*, int);
  float R11_TextWidthW(const char*, int, int);
  int InitUI(void);
  int InitOrders(void);
  int DrainInput(unsigned int*, unsigned long long*, long long*, int);
  unsigned long long GetTickCount64(void);
]])

local hostlib
pcall(function()
  hostlib = ffi.load("D:\\hake\\lotus\\src\\host16.dll")
  hostlib.InitUI()
  hostlib.InitOrders()
end)

-- state -------------------------------------------------------------------
local menuOpen, activeTab = false, 1
local hitsLua, dropdown, bindCapture, dragSlider, hoverRec = {}, nil, nil, nil, nil
local hoverX, hoverY = -1, -1
local menuCmds, hitArr = {}, {}
local menuRect = nil          -- {x, y, w, h} of the drawn ClickGUI (native input gate)
local dirty = true            -- rebuild the published menu next present
local OX, OY = 0, 0

-- palette (Umbrella-ish dark theme, red accent) ---------------------------
local C_SHADOW = { r = 0, g = 0, b = 0, a = 150 }
local C_BG = { r = 18, g = 20, b = 24 }; local C_PANEL = { r = 25, g = 28, b = 34 }
local C_ROW = { r = 35, g = 39, b = 47 }; local C_ROW_HOVER = { r = 43, g = 48, b = 58 }
local C_TEXT = { r = 232, g = 232, b = 236 }; local C_LABEL = { r = 154, g = 160, b = 168 }
local C_DIM = { r = 118, g = 124, b = 134 }
local C_ACCENT = { r = 232, g = 70, b = 90 }; local C_ACCENT_DIM = { r = 150, g = 52, b = 66 }
local C_OFF = { r = 58, g = 63, b = 72 }; local C_BORDER = { r = 42, g = 46, b = 54 }
local C_BOX = { r = 32, g = 36, b = 43 }; local C_WHITE = { r = 245, g = 245, b = 248 }

local function argb(c)
  if type(c) ~= "table" then return 0xFFFFFFFF end
  return (c.a or 255) * 16777216 + (c.r or 255) * 65536 + (c.g or 255) * 256 + (c.b or 255)
end
-- exact text advance width from the native glyph table (same data the renderer
-- draws with); second return = exactness flag so render.TextSize can warn once.
function M.textWidth(t, s, font)
  t = tostring(t or ""); s = s or 14
  local bold = (type(font) == "table" and (font.weight or 400) >= 600) and 1 or 0
  if hostlib then
    local ok, w = pcall(hostlib.R11_TextWidthW, t, s, bold)
    if ok and type(w) == "number" and w == w and w >= 0 then return w, true end
  end
  return #t * s * 0.5, false
end
local function fitText(t, s, mw, bold)
  t = tostring(t or ""); if mw <= 0 then return "" end
  local font = bold and { weight = 700 } or { weight = 400 }
  if M.textWidth(t, s, font) <= mw then return t end
  while #t > 1 and M.textWidth(t .. "...", s, font) > mw do t = t:sub(1, #t - 1) end
  return t .. "..."
end
local function wrapText(t, s, mw)
  local lines, line = {}, ""
  for word in tostring(t or ""):gmatch("%S+") do
    local cand = line == "" and word or (line .. " " .. word)
    if line ~= "" and M.textWidth(cand, s, { weight = 400 }) > mw then
      lines[#lines + 1] = line; line = word
    else line = cand end
  end
  if line ~= "" then lines[#lines + 1] = line end
  return lines
end

-- command helpers ---------------------------------------------------------
local function emit(k, x, y, z, w, c, s, t)
  menuCmds[#menuCmds + 1] = { kind = k, x = x, y = y, z = z or 0, w = w or 0,
                              color = argb(c), size = s or 0, text = t or "" }
end
local function fill(x, y, w, h, c) emit(1, x, y, w, h, c) end
local function fillRound(x, y, w, h, c, r) emit(5, x, y, w, h, c, math.floor((r or 0) + 0.5)) end
local function frameRect(x, y, w, h, c) fill(x, y, w, 1, c); fill(x, y + h - 1, w, 1, c); fill(x, y, 1, h, c); fill(x + w - 1, y, 1, h, c) end
local function drawText(x, y, t, c, s, bold) emit(bold and 6 or 0, x, y, 0, 0, c, s, tostring(t or "")) end
local function rightText(rx, y, t, c, s, bold)
  local w = M.textWidth(t, s, bold and { weight = 700 } or { weight = 400 })
  drawText(rx - w, y, t, c, s, bold)
  return w
end
local function centerText(cx, y, t, c, s, bold)
  local w = M.textWidth(t, s, bold and { weight = 700 } or { weight = 400 })
  drawText(cx - w * 0.5, y, t, c, s, bold)
  return w
end
local function addHit(x, y, w, h, rec)
  hitArr[#hitArr + 1] = { x = tonumber(x) or 0, y = tonumber(y) or 0, w = tonumber(w) or 0, h = tonumber(h) or 0 }
  hitsLua[#hitArr] = rec
end
local function hitAt(x, y)
  if not x or not y then return nil end
  for i = #hitArr, 1, -1 do
    local r = hitArr[i]
    if r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
      local rec = hitsLua[i] or {}
      rec.x, rec.y, rec.w, rec.h = r.x, r.y, r.w, r.h
      return rec
    end
  end
  return nil
end

-- menu navigation ---------------------------------------------------------
local nav = { root = 1, section = 1, second = 1, third = 1 }
local function valueLabel(w)
  local opts = w.extra and w.extra.options or {}
  local function nm(o) if type(o) == "table" then return o[1] end return o end
  if w.kind == "multicombo" or w.kind == "multiselect" then
    local n, total = 0, #opts
    for _, o in ipairs(opts) do if type(w.value) == "table" and w.value[nm(o)] == true then n = n + 1 end end
    if n == total and total > 0 then return "All (" .. n .. ")" end
    return n .. " / " .. total
  end
  local v = opts[(tonumber(w.value) or 0) + 1]
  return tostring(nm(v) or "")
end
-- bind values are Umbrella ButtonCode (menu.lua ButtonCode table), not Win32 VK
local function keyName(v)
  if menu.ButtonCode and menu.ButtonCode.Name then return menu.ButtonCode.Name(v) end
  return tostring(tonumber(v) or 0)
end
local function nodeChain()
  local root = menu.tree[nav.root]
  if not root then return nil end
  local section = root.children and root.children[nav.section]
  if not section then return root, root, root, root end
  local second = section.children and section.children[nav.second]
  if not second then return root, section, section, section end
  local third = second.children and second.children[nav.third]
  if not third then return root, section, second, second end
  return root, section, second, third
end
local function clampNav()
  local root = menu.tree[nav.root]
  if not root then return end
  local section = root.children and root.children[nav.section]
  if not section then nav.section = 1; section = root.children and root.children[1] end
  if not section then return end
  local second = section.children and section.children[nav.second]
  if not second then nav.second = 1; second = section.children and section.children[1] end
  if not second then return end
  local third = second.children and second.children[nav.third]
  if not third then nav.third = 1 end
end
local function tabRow(y, items, selected, onPick)
  local x, h = 0, 26
  local rowW = 0
  local metrics = {}
  for i, node in ipairs(items or {}) do
    local l = tostring(node.name or "")
    local tw = M.textWidth(l, 13, i == selected and { weight = 700 } or { weight = 400 }) + 24
    metrics[i] = tw
    rowW = rowW + tw + 6
  end
  return metrics, rowW
end

-- ClickGUI drawing --------------------------------------------------------
-- Geometry: window W=980, adaptive height. Two columns; group side decides
-- placement (Enum.GroupSide: Left=1, Right=2, FullWidth=3).
local W_DEFAULT = 980
local PAD, GAP, ROWH, TITLEH, GROUP_PAD = 16, 16, 30, 30, 10

local function visibleWidgets(g)
  local out = {}
  for _, w in ipairs((g and g.widgets) or {}) do
    if w.visible ~= false then out[#out + 1] = w end
  end
  return out
end
local function groupHeight(g)
  local h = TITLEH + GROUP_PAD
  for _, w in ipairs(visibleWidgets(g)) do h = h + (w.kind == "label" and 22 or ROWH) end
  return h
end
local function visibleGroups(node)
  local out = {}
  for _, g in ipairs((node and node.children) or {}) do
    if g.visible ~= false then out[#out + 1] = g end
  end
  return out
end

local function drawWidget(g, gx, gy, colW, rowY, w)
  local rowH = (w.kind == "label") and 22 or ROWH
  local isHover = hoverRec and hoverRec.widget == w
  if w.kind ~= "label" then
    if isHover and not w.disabled then fillRound(gx + 6, rowY, colW - 12, rowH - 4, C_ROW_HOVER, 4) end
  end
  local tx, ty = gx + 12, rowY + 5
  local nameCol = (w.disabled and C_OFF) or C_TEXT
  local ctrlW = 0
  if w.kind == "switch" then ctrlW = 40
  elseif w.kind == "combo" or w.kind == "multicombo" or w.kind == "multiselect" then ctrlW = math.min(190, math.floor(colW * 0.42))
  elseif w.kind == "slider" then ctrlW = math.min(200, math.floor(colW * 0.44))
  elseif w.kind == "bind" then ctrlW = 86
  elseif w.kind == "button" then ctrlW = 120
  elseif w.kind == "input" then ctrlW = math.min(190, math.floor(colW * 0.42))
  elseif w.kind == "color" then ctrlW = 40
  end
  if w.kind == "label" then
    drawText(tx, rowY + 3, fitText(w.name, 12, colW - 24), C_LABEL, 12)
    return rowH
  end
  local cx = gx + colW - 10 - ctrlW
  drawText(tx, ty, fitText(w.name, 13, (cx - tx) - 10), nameCol, 13)
  local mid = rowY + (rowH - 4) * 0.5
  if w.kind == "switch" then
    local px, py, pw, ph = cx, mid - 9, 36, 18
    fillRound(px, py, pw, ph, w.value and C_ACCENT or C_OFF, ph * 0.5)
    local kx = w.value and (px + pw - ph + 2) or (px + 2)
    fillRound(kx, py + 2, ph - 4, ph - 4, C_WHITE, (ph - 4) * 0.5)
    addHit(gx + 8, rowY, colW - 16, rowH - 2, { kind = "switch", widget = w })
  elseif w.kind == "combo" or w.kind == "multicombo" or w.kind == "multiselect" then
    local bw, bh = ctrlW, 22
    fillRound(cx, mid - bh * 0.5, bw, bh, (dropdown and dropdown.widget == w) and C_ROW_HOVER or C_ROW, 4)
    drawText(cx + 8, mid - bh * 0.5 + 4, fitText(valueLabel(w), 12, bw - 28), w.disabled and C_DIM or C_TEXT, 12)
    drawText(cx + bw - 14, mid - bh * 0.5 + 4, "v", C_LABEL, 10)
    addHit(cx, mid - bh * 0.5, bw, bh, { kind = "combo", widget = w, boxX = cx, boxY = mid - bh * 0.5, boxW = bw })
  elseif w.kind == "slider" then
    local trackW = ctrlW - 44
    local mn = tonumber(w.extra and w.extra.min) or 0
    local mx = tonumber(w.extra and w.extra.max) or 100
    local v = tonumber(w.value) or mn
    local t = math.max(0, math.min(1, (v - mn) / math.max(1e-6, mx - mn)))
    local valueText = string.format("%s", tostring(math.floor(v + 0.5)))
    local vw = rightText(cx + ctrlW, ty, valueText, w.disabled and C_DIM or C_LABEL, 12)
    local bx = cx
    local by = mid - 2
    fillRound(bx, by, trackW, 4, C_OFF, 2)
    if t > 0 then fillRound(bx, by, math.max(2, trackW * t), 4, w.disabled and C_ACCENT_DIM or C_ACCENT, 2) end
    local kx = bx + trackW * t
    fillRound(kx - 5, mid - 7, 10, 14, C_WHITE, 3)
    addHit(cx, rowY, trackW, rowH - 2, { kind = "slider", widget = w, barX = bx, barW = trackW })
  elseif w.kind == "bind" then
    local bw, bh = ctrlW, 22
    local capturing = bindCapture == w
    fillRound(cx, mid - bh * 0.5, bw, bh, capturing and C_ACCENT_DIM or C_ROW, 4)
    centerText(cx + bw * 0.5, mid - bh * 0.5 + 4, capturing and "..." or keyName(w.value), C_TEXT, 12)
    addHit(cx, mid - bh * 0.5, bw, bh, { kind = "bind", widget = w })
  elseif w.kind == "button" then
    local bw, bh = ctrlW, 22
    fillRound(cx, mid - bh * 0.5, bw, bh, C_ROW, 4)
    centerText(cx + bw * 0.5, mid - bh * 0.5 + 4, fitText(w.name, 12, bw - 12), C_TEXT, 12)
    addHit(cx, mid - bh * 0.5, bw, bh, { kind = "button", widget = w })
  elseif w.kind == "input" then
    local bw, bh = ctrlW, 22
    fillRound(cx, mid - bh * 0.5, bw, bh, C_ROW, 4)
    drawText(cx + 8, mid - bh * 0.5 + 4, fitText(tostring(w.value or ""), 12, bw - 16), C_TEXT, 12)
    addHit(cx, mid - bh * 0.5, bw, bh, { kind = "input", widget = w })
  elseif w.kind == "color" then
    local col = type(w.value) == "table" and w.value or C_ACCENT
    fillRound(cx, mid - 9, 34, 18, col, 3)
    frameRect(cx, mid - 9, 34, 18, C_BORDER)
    addHit(cx, mid - 9, 34, 18, { kind = "color", widget = w })
  end
  return rowH
end

local function drawGroup(g, gx, gy, colW)
  local gh = groupHeight(g)
  fillRound(gx, gy, colW, gh, C_PANEL, 6)
  frameRect(gx, gy, colW, gh, C_BORDER)
  drawText(gx + 12, gy + 8, tostring(g.name or ""), C_LABEL, 12, true)
  fill(gx + 12, gy + TITLEH - 4, colW - 24, 1, C_BORDER)
  local ry = gy + TITLEH
  -- R2: per-widget visibility (draft.lua:97 shows only 1 of 5 priority lists)
  for _, w in ipairs(visibleWidgets(g)) do
    local h = drawWidget(g, gx, gy, colW, ry, w)
    if hoverX >= gx and hoverX < gx + colW and hoverY >= ry and hoverY < ry + h then hoverRec = { widget = w, group = g } end
    ry = ry + h
  end
  return gh
end

local function drawDropdown()
  local d = dropdown
  if not d then return end
  local opts = (d.widget.extra and d.widget.extra.options) or {}
  local visible = d.visible or 8
  local ih = 22
  local listH = math.min(#opts, visible) * ih
  local headH = (#opts > visible) and 18 or 0
  local w = d.w
  local totalH = listH + headH + (headH > 0 and 18 or 0) + 8
  local y = d.y
  d._totalH = totalH
  fillRound(d.x, y, w, totalH, C_PANEL, 5)
  frameRect(d.x, y, w, totalH, C_BORDER)
  local oy = y + 4
  local function nm(o) if type(o) == "table" then return o[1] end return o end
  if headH > 0 then
    if d.scroll > 0 then fill(d.x + 2, oy, w - 4, 16, C_ROW) end
    drawText(d.x + 8, oy + 2, "^", d.scroll > 0 and C_LABEL or C_OFF, 12)
    addHit(d.x, oy, w, 18, { kind = "ddUp" })
    oy = oy + headH
  end
  local n = math.min(#opts, visible)
  for i = 1, n do
    local idx = d.scroll + i
    local o = opts[idx]
    local l = tostring(nm(o) or "")
    local sel
    if d.multi then
      sel = type(d.widget.value) == "table" and d.widget.value[l] == true
    else
      sel = (tonumber(d.widget.value) or 0) == (idx - 1)
    end
    local iy = oy + (i - 1) * ih
    local hover = hoverX >= d.x and hoverX < d.x + w and hoverY >= iy and hoverY < iy + ih
    if hover then fill(d.x + 2, iy, w - 4, ih, C_ROW_HOVER)
    elseif sel then fill(d.x + 2, iy, w - 4, ih, C_ROW) end
    local lx = d.x + 10
    if d.multi then
      local bx, by = d.x + 8, iy + 5
      fillRound(bx, by, 12, 12, sel and C_ACCENT or C_OFF, 2)
      if sel then fillRound(bx + 3, by + 3, 6, 6, C_WHITE, 1) end
      lx = bx + 18
    end
    drawText(lx, iy + 4, fitText(l, 12, d.x + w - 12 - lx), sel and C_ACCENT or C_TEXT, 12)
    addHit(d.x, iy, w, ih, { kind = "opt", idx = idx, drop = d })
  end
  if headH > 0 then
    local by = y + 4 + listH + headH
    if d.scroll + visible < #opts then fill(d.x + 2, by, w - 4, 16, C_ROW) end
    drawText(d.x + 8, by + 2, "v", (d.scroll + visible < #opts) and C_LABEL or C_OFF, 12)
    addHit(d.x, by, w, 18, { kind = "ddDown" })
    d._downY = by
  end
  d._optY = y + 4 + headH
end

local function drawTooltip(sw, sh)
  local rec = hoverRec
  if not rec or not rec.widget then return end
  local tip = rec.widget.tooltip
  if not tip or tip == "" then
    -- Umbrella labels can carry per-option tooltips; fall back to the widget name
    return
  end
  local maxW = 420
  local lines = wrapText(tip, 12, maxW - 20)
  if #lines > 8 then for i = 9, #lines do lines[i] = nil end end
  local h = #lines * 16 + 12
  local x = math.floor(sw * 0.5 - maxW * 0.5)
  local y = math.floor(sh - h - 90)
  fillRound(x, y, maxW, h, C_BG, 5)
  frameRect(x, y, maxW, h, C_BORDER)
  for i, line in ipairs(lines) do drawText(x + 10, y + 6 + (i - 1) * 16, line, C_LABEL, 12) end
end

local function drawMenu(sw, sh)
  menuCmds, hitArr, hitsLua = {}, {}, {}
  if not menu.tree[1] then return end
  clampNav()
  local root, section, second, third = nodeChain()
  if not root then return end

  local groups = visibleGroups(third)
  -- layout metrics ------------------------------------------------------
  local colW = math.floor((W_DEFAULT - PAD * 2 - GAP) / 2)
  local leftH, rightH, fullH = 0, 0, 0
  local placements, order = {}, {}
  for i, g in ipairs(groups) do
    local gh = groupHeight(g)
    local side = g.side
    local col = (side == 1 and 1) or (side == 2 and 2) or nil
    if col == nil and side == 3 then
      fullH = fullH + gh + GAP
      placements[i] = { kind = "full", g = g }
    else
      if col == nil then
        -- Enum.GroupSide.Default: balance the columns while keeping order
        col = (leftH <= rightH) and 1 or 2
      end
      placements[i] = { kind = "col", g = g, col = col, y = (col == 1) and leftH or rightH }
      if col == 1 then leftH = leftH + gh + GAP else rightH = rightH + gh + GAP end
    end
  end
  local bodyH = math.max(leftH, rightH) + fullH
  if bodyH < 60 then bodyH = 60 end
  -- header rows (only levels with more than one entry get a tab row)
  local rows = {}
  local function maybeRow(level, items)
    if items and #items > 1 then rows[#rows + 1] = { level = level, items = items } end
  end
  maybeRow("root", menu.tree)
  maybeRow("section", root.children)
  maybeRow("second", section.children)
  maybeRow("third", second.children)

  local headerH = 46 + #rows * 30 + 8
  local H = headerH + bodyH + PAD
  local maxH = sh - 24
  if H > maxH then H = maxH end
  local x0 = math.floor((sw - W_DEFAULT) * 0.5)
  local y0 = math.floor((sh - H) * 0.5)
  if x0 < 4 then x0 = 4 end
  if y0 < 4 then y0 = 4 end
  menuRect = { x0, y0, W_DEFAULT, H }

  -- window chrome -------------------------------------------------------
  fillRound(x0 + 4, y0 + 6, W_DEFAULT, H, C_SHADOW, 8)
  fillRound(x0, y0, W_DEFAULT, H, C_BG, 8)
  fillRound(x0, y0, W_DEFAULT, 2, C_ACCENT, 1)
  frameRect(x0, y0, W_DEFAULT, H, C_BORDER)
  -- title: section name (e.g. "Self Play") + breadcrumb of the full path
  drawText(x0 + PAD, y0 + 12, tostring(section.name or root.name or ""), C_TEXT, 16, true)
  local crumb = table.concat({ tostring(root.name or ""), tostring(section.name or ""), tostring(second.name or ""), tostring(third.name or "") }, " / ")
  rightText(x0 + W_DEFAULT - PAD, y0 + 16, crumb, C_DIM, 11)
  local y = y0 + 40
  local levelMap = { root = menu.tree, section = root.children, second = section.children, third = second.children }
  local levelNav = { root = "root", section = "section", second = "second", third = "third" }
  for _, row in ipairs(rows) do
    local items = levelMap[row.level] or {}
    local sel = nav[levelNav[row.level]]
    local tx = x0 + PAD
    for i, node in ipairs(items) do
      local l = tostring(node.name or "")
      local tw = M.textWidth(l, 13, (i == sel) and { weight = 700 } or { weight = 400 }) + 22
      if i == sel then
        fillRound(tx, y, tw, 24, C_ROW, 4)
        fill(tx, y + 22, tw, 2, C_ACCENT)
      end
      drawText(tx + 11, y + 6, l, (i == sel) and C_ACCENT or C_LABEL, 13, i == sel)
      addHit(tx, y, tw, 24, { kind = "nav", row = levelNav[row.level], idx = i })
      tx = tx + tw + 6
    end
    y = y + 30
  end
  local bodyY = y + 8

  -- groups --------------------------------------------------------------
  local colY = { bodyY, bodyY }
  local fullY = bodyY + math.max(leftH, rightH)
  for i, g in ipairs(groups) do
    local p = placements[i]
    if p then
      if p.kind == "full" then
        drawGroup(g, x0 + PAD, fullY, W_DEFAULT - PAD * 2)
        fullY = fullY + groupHeight(g) + GAP
      else
        local gx = x0 + PAD + (p.col - 1) * (colW + GAP)
        local gy = colY[p.col]
        drawGroup(g, gx, gy, colW)
        colY[p.col] = gy + groupHeight(g) + GAP
      end
    end
  end
  drawDropdown()
  drawTooltip(sw, sh)
  if bindCapture then
    drawText(x0 + PAD, y0 + H - 22, "Press a key for: " .. tostring(bindCapture.name), C_ACCENT, 12)
  end
end

-- publishing --------------------------------------------------------------
local function publishCmds(fn, cmds)
  local n = #cmds
  if n == 0 then fn(nil, 0); return end
  local a = ffi.new("RCmd[?]", n)
  for i, c in ipairs(cmds) do
    a[i - 1].kind = c.kind; a[i - 1].x, a[i - 1].y, a[i - 1].z, a[i - 1].w = c.x, c.y, c.z, c.w
    a[i - 1].x2, a[i - 1].y2, a[i - 1].z2 = c.x2 or 0, c.y2 or 0, c.z2 or 0
    a[i - 1].color = c.color; a[i - 1].size = c.size
    local t = c.text or ""; if #t > 63 then t = t:sub(1, 63) end
    ffi.copy(a[i - 1].text, t, #t)
  end
  fn(a, n)
end
local function publishHits()
  local n = #hitArr
  if n == 0 then if hostlib then hostlib.R11_PublishHits(nil, 0) end; return end
  local a = ffi.new("RHit[?]", n)
  for i, h in ipairs(hitArr) do a[i - 1].x, a[i - 1].y, a[i - 1].w, a[i - 1].h = h.x, h.y, h.w, h.h; a[i - 1].id = i end
  if hostlib then hostlib.R11_PublishHits(a, n) end
end
-- menu panel rect for the native input hook: it only swallows clicks that land
-- on the GUI (hit boxes or this panel), so game/post-game UI clicks always pass
-- through. Older host16.dll builds lack the export -> feature-detect once.
local rectApiOk = nil
local function publishMenuRect(x, y, w, h)
  if not hostlib or rectApiOk == false then return end
  local ok = pcall(hostlib.R11_PublishMenuRect, x or 0, y or 0, w or 0, h or 0)
  if ok then rectApiOk = true elseif rectApiOk == nil then rectApiOk = false end
end

-- HUD: convert render.frame commands into RCmd kinds.
-- Command ORDER is preserved 1:1 from the frame (publish order == draw order),
-- including world markers (kinds 7/8/9) which the native renderer projects at
-- Present time. Per-frame stats feed the [hud] overlap guard (task-13).
local function hudFromFrame(frame, sw, sh)
  local c = {}
  local stats = { text = 0, world = 0, overlaps = 0, offscreen = 0 }
  local boxes = {}
  for _, cmd in ipairs(frame or {}) do
    local d = cmd.data or {}
    if cmd.kind == "text" and d.text and d.text ~= "" then
      local bold = (type(d.font) == "table" and (d.font.weight or 400) >= 600)
      local size = d.size or 14
      local x, y = d.pos.x or 0, d.pos.y or 0
      c[#c + 1] = { kind = bold and 6 or 0, x = x, y = y, z = 0, w = 0, color = argb(d.color), size = size, text = tostring(d.text) }
      local w = M.textWidth(d.text, size, bold and { weight = 700 } or { weight = 400 })
      boxes[#boxes + 1] = { x = x, y = y, w = w, h = math.ceil(size * 1.2), text = tostring(d.text) }
      stats.text = stats.text + 1
    elseif cmd.kind == "frect" then
      c[#c + 1] = { kind = (d.rounding and d.rounding > 0) and 5 or 1, x = d.a.x, y = d.a.y, z = d.b.x - d.a.x, w = d.b.y - d.a.y, color = argb(d.color), size = math.floor(d.rounding or 0), text = "" }
    elseif cmd.kind == "wline" then
      stats.world = stats.world + 1
      c[#c + 1] = { kind = 7, x = d.a.wx, y = d.a.wy, z = d.a.wz, w = 0, x2 = d.b.wx, y2 = d.b.wy, z2 = d.b.wz, color = argb(d.color), size = math.floor((d.thickness or 1) * 10), text = "" }
    elseif cmd.kind == "wfcircle" then
      stats.world = stats.world + 1
      c[#c + 1] = { kind = 8, x = d.pos.wx, y = d.pos.wy, z = d.pos.wz, w = d.radius or 4, x2 = 0, y2 = 0, z2 = 0, color = argb(d.color), size = 0, text = "" }
    elseif cmd.kind == "wcircle" then
      stats.world = stats.world + 1
      c[#c + 1] = { kind = 9, x = d.pos.wx, y = d.pos.wy, z = d.pos.wz, w = d.radius or 4, x2 = 0, y2 = 0, z2 = 0, color = argb(d.color), size = math.floor((d.thickness or 1.5) * 10), text = "" }
    elseif cmd.kind == "line" then
      c[#c + 1] = { kind = 2, x = d.a.x, y = d.a.y, z = d.b.x, w = d.b.y, color = argb(d.color), size = math.floor((d.thickness or 1) * 10), text = "" }
    elseif cmd.kind == "circle" then
      c[#c + 1] = { kind = 3, x = d.pos.x, y = d.pos.y, z = d.radius or 4, w = d.thickness or 1.5, color = argb(d.color), size = 0, text = "" }
    elseif cmd.kind == "fcircle" then
      c[#c + 1] = { kind = 4, x = d.pos.x, y = d.pos.y, z = d.radius or 4, w = 0, color = argb(d.color), size = 0, text = "" }
    elseif cmd.kind == "image" then
      -- images are not rendered by the native overlay yet; skip silently
    elseif cmd.kind == "clip" then
      c[#c + 1] = { kind = 10, x = d.a.x, y = d.a.y, z = d.b.x, w = d.b.y, color = 0xFFFFFFFF, size = 0, text = "" }
    elseif cmd.kind == "unclip" then
      c[#c + 1] = { kind = 11, x = 0, y = 0, z = 0, w = 0, color = 0xFFFFFFFF, size = 0, text = "" }
    end
  end
  -- overlap guard: any two text boxes intersecting by >2px both axes is a HUD
  -- layout bug. The deliberate 1px drop-shadow pair (same text, offset <=2px)
  -- is excluded. Off-screen text means the HUD row is clipped by the viewport.
  for i = 1, #boxes do
    local a = boxes[i]
    if a.x < -2 or a.y < -2 or (sw and a.x + a.w > sw + 2) or (sh and a.y + a.h > sh + 2) then
      stats.offscreen = stats.offscreen + 1
    end
    for j = 1, i - 1 do
      local b = boxes[j]
      local ix = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
      local iy = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
      if ix > 2 and iy > 2 then
        local shadowPair = (a.text == b.text) and math.abs(a.x - b.x) <= 2 and math.abs(a.y - b.y) <= 2
        if not shadowPair then stats.overlaps = stats.overlaps + 1 end
      end
    end
  end
  return c, stats
end

local hudDumpAt = 0
local function dumpHud(c, stats)
  if #c == 0 then return end
  local f = io.open("D:\\hake\\lotus\\hud_cmds.txt", "w")
  if not f then return end
  stats = stats or { text = 0, world = 0, overlaps = -1, offscreen = -1 }
  f:write(string.format("# cmds=%d text=%d world=%d overlaps=%d offscreen=%d\n",
    #c, stats.text or 0, stats.world or 0, stats.overlaps or -1, stats.offscreen or -1))
  for _, a in ipairs(c) do
    if a.kind == 0 or a.kind == 6 then
      f:write(string.format("text%s x=%.1f y=%.1f size=%d color=%08X %q\n", a.kind == 6 and "(bold)" or "", a.x, a.y, a.size, a.color, a.text))
    elseif a.kind == 1 or a.kind == 5 then
      f:write(string.format("rect%s x=%.1f y=%.1f w=%.1f h=%.1f color=%08X\n", a.kind == 5 and "(round)" or "", a.x, a.y, a.z, a.w, a.color))
    elseif a.kind == 2 then
      f:write(string.format("line x1=%.1f y1=%.1f x2=%.1f y2=%.1f th=%.1f\n", a.x, a.y, a.z, a.w, a.size / 10))
    end
  end
  f:close()
end

local function menuSpace()
  local sw, sh = 1920, 1080
  local bw, bh = ffi.new("int[1]"), ffi.new("int[1]")
  local ok = hostlib and pcall(hostlib.R11_Size, bw, bh)
  if ok and bw[0] > 100 and bh[0] > 100 then return bw[0], bh[0] end
  local r = require("render")
  local ok2, s = pcall(r.ScreenSize)
  if ok2 and s then sw, sh = s.x, s.y end
  return sw, sh
end

-- republish menu immediately so clicks repaint without waiting for bot tick
function M.republishMenu()
  if not hostlib then return end
  local sw, sh = menuSpace()
  drawMenu(sw, sh)
  publishCmds(hostlib.R11_PublishMenu, menuCmds)
  publishHits()
  publishMenuRect(menuRect and menuRect[1], menuRect and menuRect[2], menuRect and menuRect[3], menuRect and menuRect[4])
  dirty = false
end

-- [hud] overlap guard (task-13): log on a WALL-CLOCK cadence (every 5 s) plus
-- immediately on any overlap/off-screen transition. Present() is driven by the
-- bot tick / drawOnly loop (1-2 s per tick in-match), not by rendered frames,
-- so a present-count cadence would delay the evidence line by minutes.
-- QA greps `[hud] ... overlaps=0 offscreen=0` from host.log.
local hudPresent, hudLastSig, hudLastAt = 0, nil, nil
local function wallMs()
  local ok, v = pcall(ffi.C.GetTickCount64)
  if ok and v ~= nil then return tonumber(v) or 0 end
  return os.time() * 1000
end
local function hudLog(hc, stats)
  if #hc == 0 then return end  -- HUD not drawing yet (menu/lobby): no misleading line
  hudPresent = hudPresent + 1
  local sig = tostring(stats.overlaps) .. ":" .. tostring(stats.offscreen)
  local now = wallMs()
  local transition = hudLastSig ~= nil and sig ~= hudLastSig
  local due = transition or hudLastAt == nil or (now - hudLastAt >= 5000)
  if not due then return end
  hudLastAt = now
  hudLastSig = sig
  local f = io.open("D:\\hake\\lotus\\host.log", "a")
  if not f then return end
  f:write(string.format("%s [hud] cmds=%d text=%d world=%d overlaps=%d offscreen=%d\n",
    os.date("%H:%M:%S"), #hc, stats.text, stats.world, stats.overlaps, stats.offscreen))
  f:close()
end

function M.present(frame)
  if not hostlib then return false end
  local sw, sh = menuSpace()
  local r = require("render")
  OX, OY = r.dotaOrigin()
  menuOpen = hostlib.R11_IsMenuOpen() == 1
  local hc, hstats = hudFromFrame(frame, sw, sh)
  publishCmds(hostlib.R11_PublishHud, hc)
  pcall(hudLog, hc, hstats)
  hudDumpAt = hudDumpAt + 1
  if hudDumpAt % 90 == 0 then pcall(dumpHud, hc, hstats) end
  -- menu: rebuild while open (labels/values change every tick) or when dirty
  if menuOpen or dirty then
    drawMenu(sw, sh)
    publishCmds(hostlib.R11_PublishMenu, menuCmds)
    publishHits()
    publishMenuRect(menuRect and menuRect[1], menuRect and menuRect[2], menuRect and menuRect[3], menuRect and menuRect[4])
    dirty = false
  end
  return true
end

-- input -------------------------------------------------------------------
local function clog(msg)
  local f = io.open("D:\\hake\\lotus\\host.log", "a")
  if f then
    f:write(string.format("%s [gui] %s\n", os.date("%H:%M:%S"), msg))
    f:close()
  end
end
local function applySlider(h, x)
  local w = h.widget
  local mn = tonumber(w.extra and w.extra.min) or 0
  local mx = tonumber(w.extra and w.extra.max) or 100
  local t = (x - (h.barX or 0)) / math.max(1, h.barW or 150)
  t = math.max(0, math.min(1, t))
  local v = mn + t * (mx - mn)
  if (w.extra and type(w.extra.fmt) == "string" and w.extra.fmt:find("%d")) then v = math.floor(v + 0.5) end
  w:Set(v)
end
local function toggleMultiOption(d, idx)
  local opts = d.widget.extra and d.widget.extra.options or {}
  local o = opts[idx]
  local nm = (type(o) == "table") and o[1] or o
  if nm == nil then return end
  local w = d.widget
  if type(w.value) ~= "table" then w.value = {} end
  w.value[nm] = not w.value[nm]
  if w.callback then pcall(w.callback, w) end
end
local function openDropdown(h)
  local w = h.widget
  local opts = w.extra and w.extra.options or {}
  local count = #opts
  local visible = math.min(8, math.max(3, count))
  local totalH = visible * 22 + ((count > visible) and 36 or 0) + 8
  local x, y = h.boxX or h.x, h.boxY or h.y
  local sw, sh = menuSpace()  -- R4: single call (was called twice)
  if y + 22 + totalH > sh - 8 then y = math.max(8, (h.boxY or h.y) - totalH - 22) end
  if x + (h.boxW or 150) > sw - 8 then x = sw - 8 - (h.boxW or 150) end
  dropdown = { widget = w, x = x, y = y + 24, w = h.boxW or 150, multi = (w.kind ~= "combo"),
               scroll = 0, visible = visible, options = opts }
end
local function onDown(x, y)
  if dropdown then
    local h = hitAt(x, y)
    if h and h.kind == "opt" then
      if dropdown.multi then toggleMultiOption(dropdown, h.idx)
      else dropdown.widget:Set(h.idx - 1); dropdown = nil end
      dirty = true
      return
    elseif h and h.kind == "ddUp" then
      dropdown.scroll = math.max(0, dropdown.scroll - (dropdown.visible - 1)); dirty = true; return
    elseif h and h.kind == "ddDown" then
      local count = #((dropdown.widget.extra and dropdown.widget.extra.options) or {})
      dropdown.scroll = math.max(0, math.min(count - dropdown.visible, dropdown.scroll + (dropdown.visible - 1))); dirty = true; return
    end
    dropdown = nil; dirty = true
    return
  end
  local h = hitAt(x, y)
  if not h then return end
  if h.kind == "nav" then
    nav[h.row] = h.idx; activeTab = h.idx; dirty = true
  elseif h.kind == "switch" then h.widget:Set(not h.widget:Get()); dirty = true
  elseif h.kind == "combo" then openDropdown(h)
  elseif h.kind == "bind" then bindCapture = h.widget; dirty = true
  elseif h.kind == "button" then if h.widget.callback then pcall(h.widget.callback, h.widget) end; dirty = true
  elseif h.kind == "slider" then dragSlider = h; applySlider(h, x); dirty = true
  elseif h.kind == "color" then
    -- no palette editor yet: cycle alpha as a visible acknowledgement
    local c = h.widget.value
    if type(c) == "table" then c.a = ((tonumber(c.a) or 255) >= 200) and 90 or 255; dirty = true end
  end
end
local function onMove(x, y)
  hoverX, hoverY = x, y
  local rec = hitAt(x, y)
  local newWidget = rec and rec.widget
  if newWidget ~= (hoverRec and hoverRec.widget) then dirty = true end
  if newWidget then hoverRec = { widget = newWidget } else hoverRec = nil end
  if dragSlider then applySlider(dragSlider, x); dirty = true end
end
local function onUp() dragSlider = nil end
local lastPump = 0
local inMsgs = ffi.new("unsigned int[512]")
local inWps = ffi.new("unsigned long long[512]")
local inLps = ffi.new("long long[512]")
function M.pump()
  local now = os.clock(); if now - lastPump < 0.012 then return end; lastPump = now
  if not hostlib then return end
  -- drain the WHOLE queue: mouse-move events otherwise bury pending clicks
  local kn = hostlib.DrainInput(inMsgs, inWps, inLps, 512)
  local changed = false
  local downs, moves = {}, {}
  for i = 0, kn - 1 do
    local m = inMsgs[i]
    local x = tonumber(inLps[i]) % 65536
    local y = math.floor(tonumber(inLps[i]) / 65536) % 65536
    if m == 0x0201 then downs[#downs + 1] = { x, y }
    elseif m == 0x0200 then moves[#moves + 1] = { x, y }
    elseif m == 0x0202 then onUp()
    elseif m == 0x0100 then
      local vk = tonumber(inWps[i]) or 0
      if bindCapture then
        -- R1: widget values live in Umbrella ButtonCode domain; the LL hook
        -- delivers Win32 VK, so convert. Esc cancels capture (never binds Esc).
        if vk == 27 then
          bindCapture = nil
        else
          local code = (menu.ButtonCode and menu.ButtonCode.FromVK[vk]) or 0
          bindCapture:Set(code)
          bindCapture = nil
        end
        changed = true
      elseif vk == 27 then
        if dropdown then dropdown = nil else M.setMenuOpen(false) end
        changed = true
      elseif dropdown then
        local count = #((dropdown.widget.extra and dropdown.widget.extra.options) or {})
        if vk == 38 then dropdown.scroll = math.max(0, dropdown.scroll - 1); changed = true       -- Up
        elseif vk == 40 then dropdown.scroll = math.max(0, math.min(count - dropdown.visible, dropdown.scroll + 1)); changed = true end
      end
    end
  end
  for _, mv in ipairs(moves) do onMove(mv[1], mv[2]) end
  for _, dn in ipairs(downs) do onDown(dn[1], dn[2]); changed = true end
  if changed then pcall(M.republishMenu) end
end
function M.isMenuOpen() return menuOpen end
-- offline test hooks (never called in-game; used by src/dev_ui_check.lua with a
-- stubbed ffi so a test process never loads host16.dll).
function M.debugLayout(sw, sh)
  drawMenu(sw or 1920, sh or 1080)
  return menuCmds, hitArr, hitsLua
end
function M.debugHud(frame, sw, sh)
  return hudFromFrame(frame or {}, sw or 1920, sh or 1080)
end
function M.debugNav(rootIdx, sectionIdx, secondIdx, thirdIdx)
  nav.root = rootIdx or nav.root
  nav.section = sectionIdx or nav.section
  nav.second = secondIdx or nav.second
  nav.third = thirdIdx or nav.third
end
-- keep the LL-hook flag (host.cpp) and the renderer flag (render11.cpp) in sync:
-- Esc must clear BOTH, otherwise the next Del press is swallowed (host flag out
-- of phase with the drawing flag).
function M.setMenuOpen(v)
  if not hostlib then return end
  local ok = pcall(hostlib.SetMenuOpen, v and 1 or 0)
  if not ok then pcall(hostlib.R11_SetMenuOpen, v and 1 or 0) end
  pcall(hostlib.R11_SetMenuOpen, v and 1 or 0)
end
return M