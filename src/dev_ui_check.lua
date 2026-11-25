-- dev_ui_check.lua — offline checks for the ClickGUI layout + HUD overlap guard
-- (task-13 slice). Runs under plain luajit with a STUBBED ffi, so the native
-- host16.dll is never loaded into the test process and no hooks/game state are
-- touched. Run: luajit -e "dofile('D:/hake/lotus/src/dev_ui_check.lua')"
package.path = "D:/hake/lotus/src/?.lua;" .. package.path
_G.HAKE_TEST_SILENT_MENU_LOG = true  -- keep the live host.log clean during tests

-- stubbed ffi: overlay's `pcall(ffi.load, ...)` fails -> hostlib = nil (offline)
local fakeffi = {
  cdef = function() end,
  load = function() error("offline: no native host") end,
  new = function()  -- opaque stand-in for the pump scratch arrays
    return setmetatable({}, { __index = function() return 0 end, __newindex = function() end })
  end,
  cast = function() return nil end,
  copy = function() end,
  sizeof = function() return 0 end,
  string = function(s) return s end,
}
package.preload["ffi"] = function() return fakeffi end
package.loaded["ffi"] = nil

local menu = require("menu")
local overlay = require("overlay")

local fails, checks = 0, 0
local function check(name, cond, detail)
  checks = checks + 1
  if not cond then fails = fails + 1; print("FAIL " .. name .. (detail and (" :: " .. tostring(detail)) or "")) end
end

-- ---------------------------------------------------------------- menu tree
-- Mirrors the 16.11 Self Play UI shape: Scripts/Self Play/Main -> 3 pages,
-- groups with Enum.GroupSide (Left=1, Right=2), all widget kinds used.
local root = menu.Menu.Create("Scripts", "Self Play", "Main")
local pageMain = root:Create("Main")
local pageQueue = root:Create("Search and pick")
local pageBehaviors = root:Create("What the bot does")

local control = pageMain:Create("Bot", 1)
control:Switch("Turn the bot on", true)
control:Bind("Pause while held", 65)            -- KEY_SPACE ButtonCode
control:Combo("What to do", {"Whole game", "Farm lane"}, 0)
control:Slider("Aggression", 0, 100, 50, "%d%%")
local style = pageMain:Create("Play style", 2)
local preset = style:Combo("Style", {"Careful", "Optimal", "Aggressive"}, 1)
local own = pageMain:Create("Your own style", 2)
local aggr = own:Slider("How eagerly to fight", 0, 100, 50, "%d%%")
local display = pageMain:Create("On screen", 2)
display:Switch("Show status", true)
display:Switch("Show win chance graph", true)
local fight = pageBehaviors:Create("Fighting", 1)
local lane = pageBehaviors:Create("Lane and support play", 2)
for i = 1, 7 do fight:Switch("fight option " .. i, true) end
for i = 1, 9 do lane:Switch("lane option " .. i, true) end
local queue = pageQueue:Create("Match search", 1)
queue:Switch("Auto queue and accept", false)
queue:Combo("Search game mode", {"All pick", "Single draft"}, 0)
queue:MultiCombo("Queue regions", {"US West", "EU West", "SE Asia"}, {})
queue:Label("Match search: disabled")
local pick = pageQueue:Create("Hero pick", 2)
local attributes = pick:MultiSelect("Attributes", {
  { "Strength", nil, true }, { "Agility", nil, true }, { "Intelligence", nil, true }, { "Universal", nil, true },
}, true)
local priorities = {}
for role = 1, 5 do
  priorities[role] = pick:MultiSelect("role " .. role .. " heroes", {
    { "npc_dota_hero_juggernaut", nil, true }, { "npc_dota_hero_axe", nil, false }, { "npc_dota_hero_lion", nil, false },
  }, true)
end
-- draft.lua:97 shows exactly ONE priority list at a time
for role = 2, 5 do priorities[role]:Visible(false) end

-- ------------------------------------------------------------- layout checks
local W, H = 1920, 1080
local cmds, hits, recs = overlay.debugLayout(W, H)
check("layout cmds produced", #cmds > 40, #cmds)
check("layout hits produced", #hits > 10, #hits)

local function hitFor(widget)
  for i = 1, #recs do if recs[i] and recs[i].widget == widget then return hits[i] end end
  return nil
end
-- window is centered, two columns: left starts ~486px, right starts ~968px for
-- W=1920 and window width 980 (PAD 16, GAP 16, col 466)
local leftHit = hitFor(control.widgets[1])
local rightHit = hitFor(preset)
check("left group column x", leftHit and leftHit.x < 940, leftHit and leftHit.x)
check("right group column x", rightHit and rightHit.x > 950, rightHit and rightHit.x)
-- all hit rects inside the screen
local outside = 0
for _, h in ipairs(hits) do
  if h.x < 0 or h.y < 0 or h.x + h.w > W + 1 or h.y + h.h > H + 1 then outside = outside + 1 end
end
check("hit rects on screen", outside == 0, outside)
-- page switching: "What the bot does" is page 3 in the 16.11 tree
overlay.debugNav(1, 1, 1, 3)
local cmdsB, hitsB, recsB = overlay.debugLayout(W, H)
check("behaviors page has hits", #hitsB > 8, #hitsB)
local fightHit = nil
for i = 1, #recsB do if recsB[i] and recsB[i].widget == fight.widgets[1] then fightHit = hitsB[i] end end
check("behaviors page draws fight group", fightHit ~= nil)
-- back to "Search and pick" (page 2): only one priority MultiSelect visible
overlay.debugNav(1, 1, 1, 2)
local cmdsQ, hitsQ, recsQ = overlay.debugLayout(W, H)
local function hitForQ(widget)
  for i = 1, #recsQ do if recsQ[i] and recsQ[i].widget == widget then return hitsQ[i] end end
  return nil
end
-- per-widget Visible(false) must remove the widget's row AND hit rect
local hiddenHit = hitForQ(priorities[2])
local shownHit = hitForQ(priorities[1])
check("hidden widget has no hit rect", hiddenHit == nil)
check("visible widget has hit rect", shownHit ~= nil)
-- attributes MultiSelect (all four checked) renders too
check("multiselect visible", hitForQ(attributes) ~= nil)
overlay.debugNav(1, 1, 1, 1)  -- restore page 1
-- group rows must not overflow the window (bottom-most cmd still on screen)
local maxY = 0
for _, c in ipairs(cmds) do if c.y and c.y > maxY then maxY = c.y end end
check("glass window fits on screen", maxY < H, maxY)

-- page switching just changes group set; verify Behaviors page renders its groups
local function gotoPage(idx) overlay.debugLayout(W, H) end
check("layout stable on redraw", select(1, overlay.debugLayout(W, H)) ~= nil)

-- R1 pause-domain check with a simulated held key (no OS input needed):
-- KEY_SPACE(65) must map to VK 0x20 and IsDown must follow the probe; KEY_A(11)
-- must map to VK 0x41 and stay independent.
local pauseBind = pageMain:Create("Pause probe", 1):Bind("Pause while held", 65)
local probeVK = nil
menu._keyProbeOverride = function(vk) probeVK = vk; return (vk == 0x20) and 0x8000 or 0 end
check("bind IsDown sees held SPACE", pauseBind:IsDown() == true)
check("bind probes converted VK 0x20", probeVK == 0x20, probeVK)
check("bind SPACE label", menu.ButtonCode.Name(65) == "Space", menu.ButtonCode.Name(65))
local aBind = pageMain:Create("Attack probe", 1):Bind("Attack bind test", 11)
check("bind A not held", aBind:IsDown() == false)
check("bind A probes VK 0x41", probeVK == 0x41, probeVK)
check("bind A label", menu.ButtonCode.Name(11) == "A", menu.ButtonCode.Name(11))
menu._keyProbeOverride = nil

-- ---------------------------------------------------------------- HUD stats
local function text(t, x, y, bold)
  return { kind = "text", data = { text = t, size = 13, pos = { x = x, y = y },
                                   color = { r = 255, g = 255, b = 255, a = 255 },
                                   font = { weight = bold and 700 or 400 } } }
end
-- (a) realistic HUD: shadow+main pair per text (1px offset) and 22px rows
local good = {
  text("Treant Protector", 1662, 336, true), text("Treant Protector", 1663, 337, true),
  text("Now", 1662, 361), text("Now", 1663, 362),
  text("Farming the lane", 1736, 360), text("Farming the lane", 1737, 361),
  text("Chance to win", 840, 104), text("Chance to win", 841, 105),
  text("95%", 1036, 103, true), text("95%", 1037, 104, true),
}
local c1, s1 = overlay.debugHud(good, W, H)
check("good HUD text count", s1.text == 10, s1.text)
check("good HUD overlaps == 0", s1.overlaps == 0, s1.overlaps)
check("good HUD offscreen == 0", s1.offscreen == 0, s1.offscreen)
check("good HUD cmd order kept", c1[1].kind == 6 and c1[3].kind == 0, tostring(c1[1].kind) .. "," .. tostring(c1[3].kind))
-- (b) two different texts in the same spot must be detected as a real overlap
local bad = { text("Alpha Beta", 200, 200), text("Gamma Delta", 201, 200) }
local _, s2 = overlay.debugHud(bad, W, H)
check("overlap detection works", s2.overlaps > 0, s2.overlaps)
-- (c) text running off the right edge must be flagged off-screen
local off = { text("a long row that runs past the right screen edge", 1900, 300) }
local _, s3 = overlay.debugHud(off, W, H)
check("offscreen detection works", s3.offscreen > 0, s3.offscreen)
-- (d) world marker kinds keep their publish order (kinds 7/8/9 pass through)
local world = {
  { kind = "wline", data = { a = { wx = -5800, wy = 1400, wz = 128 }, b = { wx = -5600, wy = 1300, wz = 128 },
                             color = { r = 255, g = 255, b = 255, a = 255 }, thickness = 1 } },
  { kind = "wfcircle", data = { pos = { wx = -5800, wy = 1400, wz = 128 }, radius = 26,
                                color = { r = 255, g = 0, b = 0, a = 255 } } },
  { kind = "wcircle", data = { pos = { wx = -5800, wy = 1400, wz = 128 }, radius = 16, thickness = 1.5,
                               color = { r = 0, g = 255, b = 0, a = 255 } } },
}
local c4, s4 = overlay.debugHud(world, W, H)
check("world cmds pass through in order", c4[1].kind == 7 and c4[2].kind == 8 and c4[3].kind == 9,
  tostring(c4[1].kind) .. "," .. tostring(c4[2].kind) .. "," .. tostring(c4[3].kind))
check("world cmd count", s4.world == 3, s4.world)

print(string.format("dev_ui_check: %d checks, %d failed", checks, fails))
os.exit(fails == 0 and 0 or 1)