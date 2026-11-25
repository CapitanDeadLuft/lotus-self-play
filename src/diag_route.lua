local loader = require("loader")
local entity = require("entity")
local nav = require("nav")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[route] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local team = Entity.GetTeamNum(Heroes.GetLocal())
L("heroTeam=%s", tostring(team))
local suffix = { "top", "mid", "bot" }
local found = {}
for idn in entity.iter() do
  local un = NPC.GetUnitName(idn) or ""
  if un:find("tower%d_", 1) and Entity.IsSameTeam(Heroes.GetLocal(), idn) then
    local lane = un:find("_top$") and 1 or (un:find("_mid$") and 2 or (un:find("_bot$") and 3 or nil))
    local tier = tonumber(un:match("tower(%d)"))
    if lane and tier then found[lane] = found[lane] or {}; found[lane][tier] = Entity.GetAbsOrigin(idn) end
  end
end
for lane = 1, 3 do
  local t1, t2 = found[lane] and found[lane][1], found[lane] and found[lane][2]
  L("lane %s(%s): t1=%s t2=%s", lane, suffix[lane],
    t1 and string.format("%.0f,%.0f", t1.x, t1.y) or "nil", t2 and string.format("%.0f,%.0f", t2.x, t2.y) or "nil")
  if t1 and t2 then
    local a = nav.walkable and nav.walkable(t2) or t2
    local b = nav.walkable and nav.walkable(t1) or t1
    local okp, path = pcall(GridNav.BuildPath, a, b)
    L("   BuildPath ok=%s n=%s first=%s last=%s", tostring(okp), okp and type(path) == "table" and #path or tostring(path),
      okp and type(path) == "table" and path[1] and string.format("%.0f,%.0f", path[1].x, path[1].y) or "-",
      okp and type(path) == "table" and path[#path] and string.format("%.0f,%.0f", path[#path].x, path[#path].y) or "-")
  end
end
L("done")
