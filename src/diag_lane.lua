require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[lane] " .. tostring(s or fmt) .. "\n"); f:flush() end end
-- build the same state the live loop has (fresh Lua state has an empty scan)
local loader = package.loaded["loader"] or require("loader")
pcall(loader.tick)
pcall(loader.updateGlobals)
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local hp = Entity.GetAbsOrigin(hero)
L("hero=%s team=%s pos=%.0f,%.0f", tostring(NPC.GetUnitName(hero)), tostring(Entity.GetTeamNum(hero)), hp.x, hp.y)
local LGM = _G.LaneGroupsManager
if type(LGM) ~= "table" then L("LaneGroupsManager missing"); return end
local function dump(tag, list)
  local n = 0
  for k, g in pairs(type(list) == "table" and list or {}) do
    n = n + 1
    if n <= 8 then
      local p = g.position_ or g.position
      local creeps, names = 0, {}
      for _, c in pairs(type(g.creeps) == "table" and g.creeps or {}) do
        creeps = creeps + 1
        if #names < 3 then names[#names + 1] = tostring(c.ref and NPC.GetUnitName(c.ref) or "?") end
      end
      local path = type(g.lane_path) == "table" and g.lane_path or nil
      local pa = path and path[1]
      local pb = path and path[#path]
      L("%s[%s] lane=%s pos=%s creeps=%d %s path=%s %s->%s", tag, tostring(k), tostring(g.lane),
        p and string.format("%.0f,%.0f", p.x or 0, p.y or 0) or "nil", creeps, table.concat(names, ","),
        path and tostring(#path) or "nil",
        pa and string.format("%.0f,%.0f", pa.x or 0, pa.y or 0) or "?", pb and string.format("%.0f,%.0f", pb.x or 0, pb.y or 0) or "?")
    end
  end
  L("%s total=%d", tag, n)
end
dump("ally_visible", LGM.visible_ally)
dump("ally_invisible", LGM.invisible_ally)
dump("enemy_visible", LGM.visible_enemy)
dump("enemy_invisible", LGM.invisible_enemy)
-- nav lane paths for our team
local nav = package.loaded["nav"] or require("nav")
if nav and nav.lanePath then
  for lane = 1, 3 do
    local ok, pts = pcall(nav.lanePath, lane, Entity.GetTeamNum(hero))
    if ok and type(pts) == "table" and #pts >= 2 then
      L("nav.lanePath lane=%d n=%d first=%.0f,%.0f last=%.0f,%.0f", lane, #pts,
        pts[1].x, pts[1].y, pts[#pts].x, pts[#pts].y)
    else
      L("nav.lanePath lane=%d FAILED %s", lane, tostring(pts))
    end
  end
end
L("done")

