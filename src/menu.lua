-- menu.lua — Umbrella-compatible ClickGUI data model (menu tree + widgets).
-- The 16.11 Self Play scripts build the UI through Menu.Create(...) and
-- CMenuGroup widget factories; overlay.lua renders this tree and drives input.
-- API reference: D:\hake\lotus\umbrella_api\menu.md, classes\widgets\*.
local M = {}
local ffi = require("ffi")
-- key-state probes: GetAsyncKeyState sees physical + elevated-injected holds in
-- this Dota process; GetKeyState/GetKeyboardState are cheap same-thread fallbacks
local gaks, gks, gkbs
do
  pcall(ffi.cdef, "short GetAsyncKeyState(int vKey);")
  pcall(ffi.cdef, "short GetKeyState(int vKey);")
  pcall(ffi.cdef, "int GetKeyboardState(unsigned char* state);")
  local ok, fn = pcall(function() return ffi.C.GetAsyncKeyState end); gaks = ok and fn or nil
  local ok2, fn2 = pcall(function() return ffi.C.GetKeyState end); gks = ok2 and fn2 or nil
  local ok3, fn3 = pcall(function() return ffi.C.GetKeyboardState end); gkbs = ok3 and fn3 or nil
end
local _logf = io.open("D:\\hake\\lotus\\host.log", "a")
-- offline test harness sets this global so test runs never pollute the live log
if _G.HAKE_TEST_SILENT_MENU_LOG then _logf = nil end
local function wlog(msg)
  if not _logf then return end
  _logf:write(string.format("%s %s\n", os.date("%H:%M:%S"), msg)); _logf:flush()
end
-- Debug logging (R3): only diagnostics that matter reach host.log — callback
-- errors and unknown-method gaps, log-once each. Widget/group creation chatter
-- stays silent (it used to add ~100 flushed lines per script load).
local mlSeen, mlN = {}, 0
local function mlog(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  local msg = table.concat(t, " ")
  if not (msg:find("error") or msg:find("unknown")) then return end
  if mlSeen[msg] then return end
  mlSeen[msg] = true
  mlN = mlN + 1
  if mlN > 40 then return end
  if _logf then _logf:write(string.format("%s [menu] %s\n", os.date("%H:%M:%S"), msg)); _logf:flush() end
end
M.tree = {}        -- root tabs (children: sections -> second tabs -> third tabs -> groups)
M.widgets = {}     -- flat list of all widgets (persistence/render/auto-enable)
local opened = false

-- ---- widget persistence (Umbrella parity) ---------------------------------
-- Original host stores menu values in <cheatdir>/configs/self_play_menu.ini as
-- "Group/Name=value". Without this the Self Play switches (notably
-- Display/Write decision diagnostics, role, lane) reset to defaults on every
-- script load: no decision trace and role always Auto.
local CFG_PATH = "D:\\hake\\lotus\\configs\\self_play_menu.ini"
local savedCfg, savedCfgLoaded = nil, false
local function cfgTable()
  if savedCfgLoaded then return savedCfg end
  savedCfgLoaded = true
  savedCfg = {}
  local f = io.open(CFG_PATH, "r")
  if not f then return savedCfg end
  for line in f:lines() do
    local k, v = line:match("^([^=]+)=(.*)$")
    if k and v then savedCfg[k] = v end
  end
  f:close()
  return savedCfg
end
local function cfgFormat(w)
  if w.kind == "switch" then return w.value and "1" or "0"
  elseif w.kind == "bind" then return tostring(tonumber(w.value) or 0)
  elseif w.kind == "input" then return tostring(w.value or "")
  elseif w.kind == "slider" or w.kind == "combo" then return tostring(w.value)
  end
  return nil
end
local function cfgApply(w)
  if not w.path then return end
  local t = cfgTable()
  local v = t[w.path]
  if v == nil and w.altPath then v = t[w.altPath] end
  if v == nil then return end
  if w.kind == "switch" then
    w.value = (v ~= "0" and v ~= "false" and v ~= "")
  elseif w.kind == "bind" then
    w.value = tonumber(v) or w.value
  elseif w.kind == "slider" then
    local n = tonumber(v)
    if n then
      local mn = tonumber(w.extra and w.extra.min) or 0
      local mx = tonumber(w.extra and w.extra.max) or 100
      if n < mn then n = mn end
      if n > mx then n = mx end
      w.value = n
    end
  elseif w.kind == "combo" then
    local n = tonumber(v)
    if n then
      local count = #(w.extra and w.extra.options or {})
      if count > 0 then n = math.max(0, math.min(count - 1, n)) end
      w.value = n
    end
  elseif w.kind == "input" then
    w.value = v
  end
end
local cfgDirty = false
local function cfgStore(w)
  local v = cfgFormat(w)
  if v == nil or not w.path then return end
  local t = cfgTable()
  if t[w.path] == v then return end
  t[w.path] = v
  cfgDirty = true
end
local function cfgFlush()
  if not cfgDirty then return end
  cfgDirty = false
  local t = cfgTable()
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  local f = io.open(CFG_PATH, "w")
  if not f then return end
  for _, k in ipairs(keys) do f:write(k, "=", t[k], "\n") end
  f:close()
end
M.cfgPath = CFG_PATH

-- Enum.ButtonCode <-> Win32 virtual-key mapping (R1). The scripting API binds
-- Umbrella ButtonCode values (enums.lua): KEY_SPACE=65, KEY_A=11, NOT VK codes.
-- GetAsyncKeyState and the native WM_KEYDOWN hook speak Win32 VK, so every
-- bind value must be converted in both directions or the wrong key is tested.
local BTN2VK, VK2BTN = {}, {}
do
  local function range(btn0, vk0, n) for i = 0, n - 1 do BTN2VK[btn0 + i] = vk0 + i end end
  range(1, 0x30, 10)   -- KEY_0..KEY_9
  range(11, 0x41, 26)  -- KEY_A..KEY_Z
  range(37, 0x60, 10)  -- KEY_PAD_0..9
  local singles = {
    [47] = 0x6F, [48] = 0x6A, [49] = 0x6D, [50] = 0x6B, [51] = 0x0D, [52] = 0x6E,
    [53] = 0xDB, [54] = 0xDD, [55] = 0xBA, [56] = 0xDE, [57] = 0xC0, [58] = 0xBC,
    [59] = 0xBE, [60] = 0xBF, [61] = 0xDC, [62] = 0xBD, [63] = 0xBB,
    [64] = 0x0D, [65] = 0x20, [66] = 0x08, [67] = 0x09, [68] = 0x14, [69] = 0x90,
    [70] = 0x1B, [71] = 0x91, [72] = 0x2D, [73] = 0x2E, [74] = 0x24, [75] = 0x23,
    [76] = 0x21, [77] = 0x22, [78] = 0x03,
    [79] = 0xA0, [80] = 0xA1, [81] = 0xA4, [82] = 0xA5, [83] = 0xA2, [84] = 0xA3,
    [85] = 0x5B, [86] = 0x5C, [87] = 0x5D,
    [88] = 0x26, [89] = 0x25, [90] = 0x28, [91] = 0x27,
    [116] = 0x14, [117] = 0x90, [118] = 0x91,  -- *TOGGLE aliases
    [119] = 0x01, [120] = 0x02, [121] = 0x04, [122] = 0x05, [123] = 0x06,  -- mouse 1..5
    -- 124/125 (wheel up/down) have no held-key VK: IsDown stays false
  }
  for k, v in pairs(singles) do BTN2VK[k] = v end
  range(92, 0x70, 24)  -- KEY_F1..KEY_F24
  for btn, vk in pairs(BTN2VK) do if VK2BTN[vk] == nil then VK2BTN[vk] = btn end end
  -- duplicates: prefer the plain (non keypad / non toggle) ButtonCode
  VK2BTN[0x0D] = 64; VK2BTN[0x14] = 68; VK2BTN[0x90] = 69; VK2BTN[0x91] = 71
  -- KEY_SPACE and KEY_A are the two values the Self Play UI binds by default;
  -- assert the domain mapping right away (R1 offline check).
  if BTN2VK[65] ~= 0x20 or BTN2VK[11] ~= 0x41 then
    if _logf then _logf:write(os.date("%H:%M:%S ") .. "[menu] FATAL ButtonCode->VK map broken\n"); _logf:flush() end
  end
end
local btnName = {
  [0] = "None", [1] = "0", [2] = "1", [3] = "2", [4] = "3", [5] = "4", [6] = "5", [7] = "6",
  [8] = "7", [9] = "8", [10] = "9", [64] = "Enter", [65] = "Space", [66] = "Backspace",
  [67] = "Tab", [68] = "CapsLock", [69] = "NumLock", [70] = "Esc", [71] = "ScrollLock",
  [72] = "Insert", [73] = "Delete", [74] = "Home", [75] = "End", [76] = "PageUp",
  [77] = "PageDown", [78] = "Break", [79] = "LShift", [80] = "RShift", [81] = "LAlt",
  [82] = "RAlt", [83] = "LCtrl", [84] = "RCtrl", [85] = "LWin", [86] = "RWin", [87] = "Menu",
  [88] = "Up", [89] = "Left", [90] = "Down", [91] = "Right",
  [119] = "Mouse1", [120] = "Mouse2", [121] = "Mouse3", [124] = "WheelUp", [125] = "WheelDown",
}
local function keyName(v)
  v = tonumber(v) or 0
  if btnName[v] then return btnName[v] end
  if v >= 11 and v <= 36 then return string.char(0x40 + (v - 10)) end       -- A..Z
  if v >= 37 and v <= 46 then return "Num" .. (v - 37) end
  if v >= 92 and v <= 115 then return "F" .. (v - 91) end
  return "Key" .. tostring(v)
end
M.ButtonCode = { ToVK = BTN2VK, FromVK = VK2BTN, Name = keyName }
-- one-line load evidence (task-4 pause residual): proves the ButtonCode->VK
-- mapping and the live key-state source of the BUILD QA is testing
wlog(string.format("[menu] bind map: KEY_SPACE=%d->VK=0x%02X '%s'; KEY_A=%d->VK=0x%02X '%s'; IsDownSource=%s",
  65, BTN2VK[65] or -1, keyName(65), 11, BTN2VK[11] or -1, keyName(11),
  gaks and "GetAsyncKeyState" or (gks and "GetKeyState" or "none")))

-- Enum.WidgetType values (enums.lua): group=4, switch=5, bind=6, sliderFloat=7,
-- sliderInt=8, color=9, button=11, combo=12, multicombo=13, input=15,
-- multiselect=16, label=19, customBind=22, invalid=32
local widgetTypeMap = {
  switch = 5, bind = 6, slider = 8, sliderfloat = 7, color = 9, button = 11,
  combo = 12, multicombo = 13, input = 15, multiselect = 16, label = 19,
}
local function optionName(o)
  if type(o) == "table" then return o[1], o[3] end
  return o, nil
end
local function optionList(options)
  local out = {}
  if type(options) ~= "table" then return out end
  for _, o in ipairs(options) do out[#out + 1] = optionName(o) end
  return out
end
local function isMulti(w) return w.kind == "multicombo" or w.kind == "multiselect" end

-- Unknown-method policy (P0-B hardening, task-14): the old catch-all returned
-- a function returning `self` (a table => truthy), so any unimplemented query
-- method silently became "true" for the script -- exactly how ui.pause:IsDown()
-- kept the bot paused forever. Never return a table for a query method; log the
-- gap once (rate-limited) instead of hiding it.
local unknownLogged = {}
local function logUnknown(owner, name)
  local key = owner .. "." .. name
  if unknownLogged[key] then return end
  unknownLogged[key] = true
  local f = io.open("D:\\hake\\lotus\\host.log", "a")
  if f then f:write(string.format("%s [menu] unknown %s method '%s' (typed fallback)\n", os.date("%H:%M:%S"), owner, name)); f:close() end
end
local function typedFallback(owner, name)
  logUnknown(owner, name)
  if name:match("^Is") or name:match("^Can") or name:match("^Has") or name:match("^Should") then
    return function() return false end
  end
  if name:match("^List") or name:match("^GetOptions") or name:match("^Options") then
    return function() return {} end
  end
  if name:match("^Get") or name:match("^Find") or name:match("^Build") then
    return function() return nil end
  end
  -- chainable UI helpers (Set*/Update*/Add*/Attach*/Icon/Visible/...) return self
  return function(self, ...) return self end
end
local Widget = {}
Widget.__index = function(t, k)
  local m = Widget[k]
  if m ~= nil then return m end
  if type(k) == "string" and k:match("^[A-Z]") then return typedFallback("Widget", k) end
  return nil
end
local function newWidget(kind, name, value, extra)
  mlog("widget", kind, name)
  local w = setmetatable({ kind = kind, name = name, value = value, extra = extra or {},
                           disabled = false, callback = nil, icon = nil }, Widget)
  M.widgets[#M.widgets + 1] = w
  return w
end
local fireErrSeen = {}
local function fire(w)
  if not w.callback then return end
  local ok, err = pcall(w.callback, w)
  if ok then return end
  -- R3: never swallow callback errors silently (log once per distinct error)
  local key = tostring(w.name) .. "|" .. tostring(err)
  if fireErrSeen[key] then return end
  fireErrSeen[key] = true
  if _logf then
    _logf:write(string.format("%s [menu] callback error widget=%s: %s\n", os.date("%H:%M:%S"), tostring(w.name), tostring(err)))
    _logf:flush()
  end
end
function Widget:Get(name)
  if isMulti(self) then
    if name == nil then return self.value end
    return type(self.value) == "table" and self.value[name] == true or false
  end
  if name ~= nil then
    -- Umbrella combo widgets also accept Get(optionName) -> selected boolean
    local n, _ = optionName(self.extra and self.extra.options and self.extra.options[name] or nil)
    if n ~= nil then return (tonumber(self.value) or -1) == (name - 1) end
    return false
  end
  return self.value
end
function Widget:Set(v, v2)
  local kind = self.kind
  if isMulti(self) then
    if type(v) == "table" then
      local map = {}
      for k, ok in pairs(v) do
        if type(k) == "string" then
          map[k] = (ok == true)
        elseif type(k) == "number" then
          local nm = optionList(self.extra and self.extra.options)[k]
          if nm then map[nm] = (ok == true) end
        end
      end
      self.value = map
    elseif type(v) == "string" then
      if type(self.value) ~= "table" then self.value = {} end
      self.value[v] = (v2 == nil) and not self.value[v] or (v2 == true)
    elseif type(v) == "number" and self.extra and self.extra.options then
      local nm = optionList(self.extra.options)[v]
      if nm then
        if type(self.value) ~= "table" then self.value = {} end
        self.value[nm] = (v2 == nil) and not self.value[nm] or (v2 == true)
      end
    end
  elseif kind == "switch" then
    self.value = v and true or false
  elseif kind == "combo" then
    local count = #optionList(self.extra and self.extra.options or {})
    if type(v) == "string" then
      local opts = optionList(self.extra and self.extra.options or {})
      local found = 0
      for i, nm in ipairs(opts) do if nm == v then found = i - 1; break end end
      self.value = count > 0 and math.max(0, math.min(count - 1, found)) or 0
    else
      local n = tonumber(v) or 0
      if count > 0 then n = math.max(0, math.min(count - 1, n)) end
      self.value = n
    end
  elseif kind == "slider" then
    local n = tonumber(v) or (self.value or 0)
    local mn = tonumber(self.extra and self.extra.min) or 0
    local mx = tonumber(self.extra and self.extra.max) or 100
    if n < mn then n = mn end
    if n > mx then n = mx end
    self.value = n
  elseif kind == "bind" then
    self.value = tonumber(v) or 0
  else
    self.value = v
  end
  cfgStore(self)
  cfgFlush()
  fire(self)
  return self
end
function Widget:SetCallback(fn, fireNow) self.callback = fn; if fireNow and fn then pcall(fn, self) end; return self end
-- Umbrella CMenuBind:IsDown() -> true while the bound key is held. This is a
-- HOT path: Self Play.lua:1860 pauses the bot for as long as it returns true,
-- so a missing implementation makes the bot stand still forever.
-- NOTE the value domain: widget values are Umbrella ButtonCode (KEY_SPACE=65,
-- not VK 0x20) -> convert before asking Win32.
-- Diagnostics: every held/released transition is logged (one line) and a still-held
-- bind logs every 2 s, so QA can prove the pause from host.log alone (screenshot
-- capture is too slow to reliably land inside a 2 s synthetic hold).
local bindLastDown, bindLastLogAt = {}, {}
-- test hook: offline harness can simulate a held key (no OS dependency)
M._keyProbeOverride = nil
function Widget:IsDown()
  if self.kind ~= "bind" then return false end
  local code = tonumber(self.value) or 0
  local vk = BTN2VK[code]
  if not vk then return false end
  local raw = 0
  if M._keyProbeOverride then
    local ok, v = pcall(M._keyProbeOverride, vk)
    if ok and type(v) == "number" then raw = v end
  elseif gaks then
    local ok, st = pcall(gaks, vk)
    if ok and st ~= nil then raw = tonumber(st) or 0 end
  end
  if bit.band(raw, 0x8000) == 0 and gks then
    local ok, st = pcall(gks, vk)
    if ok and st ~= nil and bit.band(tonumber(st) or 0, 0x8000) ~= 0 then raw = raw + 0x8000 end
  end
  local down = bit.band(raw, 0x8000) ~= 0
  local now = os.clock()
  local key = tostring(self.name or "bind") .. ":" .. tostring(code)
  if bindLastDown[key] ~= down then
    bindLastDown[key] = down
    bindLastLogAt[key] = now
    wlog(string.format("[menu] bind '%s' code=%d vk=0x%02X held=%s raw=0x%04X",
      tostring(self.name), code, vk, tostring(down), raw % 0x10000))
  elseif down and now - (bindLastLogAt[key] or 0) > 2 then
    bindLastLogAt[key] = now
    wlog(string.format("[menu] bind '%s' vk=0x%02X held=true raw=0x%04X (still held)",
      tostring(self.name), vk, raw % 0x10000))
  end
  return down
end
-- Alias used by some scripts / widget kinds.
Widget.IsPressed = Widget.IsDown
function Widget:Disabled(state) self.disabled = (state == true or state == 1); return self end
function Widget:Icon(icon) self.icon = icon; return self end
function Widget:GetName() return self.name end
function Widget:Type() return widgetTypeMap[self.kind] or 32 end
function Widget:ForceLocalization(text) self.name = text; return self end
-- Umbrella: Update(options, [selected], [silent]) — replaces the option list;
-- for multi widgets the selection map is rebuilt from each option's 3rd field
-- (draft.lua stores {name, icon, selected}); Update never fires callbacks.
function Widget:Update(options, selected, silent)
  if type(options) == "table" then self.extra = self.extra or {}; self.extra.options = options end
  if isMulti(self) then
    local map = {}
    local opts = self.extra and self.extra.options or {}
    for _, o in ipairs(opts) do
      local nm, sel = optionName(o)
      if nm ~= nil then
        if sel ~= nil then map[nm] = (sel == true)
        elseif selected == true then map[nm] = true end
      end
    end
    if type(selected) == "table" then for k, v in pairs(selected) do if type(k) == "string" then map[k] = (v == true) end end end
    self.value = map
  elseif self.kind == "combo" then
    if selected ~= nil then
      local count = #optionList(self.extra and self.extra.options or {})
      local n = tonumber(selected) or 0
      if count > 0 then n = math.max(0, math.min(count - 1, n)) end
      self.value = n
    end
  end
  return self
end
function Widget:ToolTip(text) self.tooltip = text; return self end
function Widget:SetTooltip(text) self.tooltip = text; return self end
function Widget:List()
  local out = {}
  for _, o in ipairs(self.extra and self.extra.options or {}) do out[#out + 1] = optionName(o) end
  return out
end
-- MultiComboBox/MultiSelect: names of the enabled (checked) options.
-- ComboBox: Umbrella returns the option list here too (no sub-selection).
function Widget:ListEnabled()
  if not isMulti(self) then return self:List() end
  local out = {}
  for _, nm in ipairs(self:List()) do
    if type(self.value) == "table" and self.value[nm] == true then out[#out + 1] = nm end
  end
  return out
end
function Widget:UpdateToolTips(tips) self.tips = tips; return self end
function Widget:SetValidValues(...) return self end

local Group = {}
Group.__index = function(t, k)
  local m = Group[k]
  if m ~= nil then return m end
  if type(k) == "string" and k:match("^[A-Z]") then return typedFallback("Group", k) end
  return nil
end
local function newGroup(name, side, parentPath)
  return setmetatable({ name = name, side = side, children = {}, widgets = {},
                        path = (parentPath and (parentPath .. "/") or "") .. tostring(name),
                        visible = true, kind = "group" }, Group)
end
function Group:Create(name, side)
  mlog("group", name)
  local g = newGroup(name, side, self.path)
  self.children[#self.children + 1] = g
  return g
end
local function addWidget(self, w)
  -- Umbrella stores menu values as "<group>/<widget>" (e.g. "Display/Write decision
  -- diagnostics"); tabs/sections are not part of the key. Keep the bare widget
  -- name as a secondary lookup because a few root-level widgets are stored flat.
  w.path = tostring(self.name) .. "/" .. tostring(w.name)
  w.altPath = tostring(w.name)
  cfgApply(w)
  self.widgets[#self.widgets + 1] = w
  return w
end
function Group:Switch(name, default, icon) return addWidget(self, newWidget("switch", name, default == true)) end
function Group:Slider(name, minv, maxv, default, fmt)
  local d = tonumber(default) or tonumber(minv) or 0
  return addWidget(self, newWidget("slider", name, d, { min = minv, max = maxv, fmt = fmt }))
end
function Group:Combo(name, options, default) return addWidget(self, newWidget("combo", name, tonumber(default) or 0, { options = options })) end
function Group:MultiCombo(name, options, default)
  local w = newWidget("multicombo", name, {}, { options = options })
  local map = {}
  if type(default) == "table" then
    for k, v in pairs(default) do
      if type(k) == "string" then map[k] = (v == true)
      elseif type(v) == "string" then map[v] = true end
    end
  end
  w.value = map
  return addWidget(self, w)
end
function Group:MultiSelect(name, options, default)
  local w = newWidget("multiselect", name, {}, { options = options, search = default == true })
  local map = {}
  for _, o in ipairs(type(options) == "table" and options or {}) do
    local nm, sel = optionName(o)
    if nm ~= nil and sel == true then map[nm] = true end
  end
  w.value = map
  return addWidget(self, w)
end
function Group:Bind(name, default) return addWidget(self, newWidget("bind", name, tonumber(default) or 0)) end
function Group:ColorPicker(name, default, icon) return addWidget(self, newWidget("color", name, default)) end
function Group:Button(name, callback) local w = newWidget("button", name, nil); w.callback = callback; return addWidget(self, w) end
function Group:Input(name, default) return addWidget(self, newWidget("input", name, default or "")) end
function Group:Label(name) return addWidget(self, newWidget("label", name, nil)) end
function Group:KeyBind(name, default) return self:Bind(name, default) end
function Group:Icon(icon) self.icon = icon; return self end
function Group:Side() return self.side end
function Group:Type() return 4 end  -- Enum.WidgetType.MenuGroup
function Group:ForceLocalization(text) self.name = text; return self end
function Group:Update(options, selected) end
function Group:ToolTip(text) self.tooltip = text; return self end
function Group:SetTooltip(text) self.tooltip = text; return self end
function Group:Get() return self.value end
function Group:Set(v) self.value = v end
function Group:SetCallback(fn) self.callback = fn end
function Group:Disabled(state) self.disabled = (state == true); return self end
function Group:GetName() return self.name end
function Group:List()
  local out = {}
  for _, w in ipairs(self.widgets or {}) do out[#out + 1] = w.name end
  return out
end

-- shared no-op/simple UI methods (rendering-side; safe stubs for logic)
for _, cls in ipairs({ Widget, Group }) do
  cls.DragAllowed = function(self, v) self.dragAllowed = v; return self end
  cls.Visible = function(self, v)
    if v == nil then return self.visible ~= false end
    self.visible = v and true or false
    return self
  end
  cls.ListEnabled = cls.ListEnabled or function(self, v) return self end
  cls.UpdateToolTips = cls.UpdateToolTips or function(self) return self end
  cls.Gear = function(self) return self end
  cls.Buttons = function(self, ...) return self end
  cls.Attach = function(self, ...) return self end
  cls.AddGear = function(self, ...) return self end
  cls.Search = function(self, ...) return self end
end

-- Menu global -------------------------------------------------------------
local Menu = {}
function Menu.Create(firstTab, section, secondTab, thirdTab, groupTab)
  local root
  for _, t in ipairs(M.tree) do if t.name == firstTab then root = t end end
  if not root then root = newGroup(firstTab); M.tree[#M.tree + 1] = root end
  local node = root
  for _, nm in ipairs({ section, secondTab, thirdTab, groupTab }) do
    if nm then
      local found
      for _, c in ipairs(node.children) do if c.name == nm then found = c end end
      if not found then found = node:Create(nm) end
      node = found
    end
  end
  return node
end
-- Menu.Find(firstTab, section, secondTab, thirdTab, groupTab, widgetName,
--           attachmentName, widgetInGearName) -> widget | group | nil
function Menu.Find(firstTab, section, secondTab, thirdTab, groupTab, widgetName)
  local function findChild(node, name)
    if not node then return nil end
    if name == nil or name == "" then return node end
    for _, c in ipairs(node.children or {}) do if c.name == name then return c end end
    return nil
  end
  local root
  for _, t in ipairs(M.tree) do if t.name == firstTab then root = t end end
  if not root then return nil end
  local node = root
  for _, nm in ipairs({ section, secondTab, thirdTab, groupTab }) do
    if nm and nm ~= "" then
      node = findChild(node, nm)
      if not node then return nil end
    end
  end
  if widgetName == nil or widgetName == "" then return node end
  for _, w in ipairs(node.widgets or {}) do if w.name == widgetName then return w end end
  for _, c in ipairs(node.children or {}) do
    for _, w in ipairs(c.widgets or {}) do if w.name == widgetName then return w end end
  end
  return nil
end
-- expose the menu factory globally for scripts that call Menu.Create/Find
if not _G.Menu then _G.Menu = Menu end
function Menu.Opened() return opened end
function Menu.VisualsIsEnabled() return true end
function Menu.Alpha() return 1 end
function Menu.Scale() return 100 end
function Menu.Pos() return require("mathx").Vec2(100, 100) end
function Menu.Size() return require("mathx").Vec2(1000, 640) end
function Menu.Style() return require("mathx").Color(255, 255, 255, 255) end
function Menu.SetOpened(v) opened = v and true or false end
M.Menu = Menu
M.Group = Group
M.Widget = Widget
return M