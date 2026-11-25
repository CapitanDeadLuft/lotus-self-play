-- test_nav.lua — offline unit tests for nav.lua (no Dota needed)
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local nav = require("nav")

local fails, checks = 0, 0
local function check(name, cond, extra)
  checks = checks + 1
  if not cond then fails = fails + 1; print(string.format("FAIL %s %s", name, extra or "")) end
end

-- 1. empty map: straight walkable
nav.setObstacles({})
check("open isTraversable", nav.isTraversable(0, 0))
check("outside map blocked", not nav.isTraversable(20000, 0))
local p = nav.buildPath(0, 0, 1000, 0)
check("open path exists", #p > 0, "n=" .. #p)
check("open path ends at destination", math.abs(p[#p].x - 1000) < 1 and math.abs(p[#p].y) < 1)

-- 2. wall of obstacles with a gap: path must go through the gap
nav.setObstacles((function()
  local list = {}
  -- vertical wall at x = 500, gap at y in [-120, 120]
  for y = -2000, 2000, 64 do
    if math.abs(y) > 120 then list[#list + 1] = { x = 500, y = y, r = 48, hard = true } end
  end
  return list
end)())
check("wall blocks center", not nav.isTraversable(500, 600))
check("gap is walkable", nav.isTraversable(500, 0))
local path = nav.buildPath(0, 800, 1200, 800)
check("wall path exists", #path > 0, "n=" .. #path)
local maxAbsY, crossedAtX = 0, nil
for _, w in ipairs(path) do
  if math.abs(w.y) > maxAbsY then maxAbsY = math.abs(w.y) end
  if crossedAtX == nil and w.x > 500 then crossedAtX = w.y end
end
check("path uses the gap", crossedAtX ~= nil and math.abs(crossedAtX) < 200, "crossY=" .. tostring(crossedAtX))
-- every waypoint must be traversable
local allWalkable = true
for _, w in ipairs(path) do
  if not nav.isTraversable(w.x, w.y) then allWalkable = false end
end
check("all waypoints walkable", allWalkable)

-- 3. full wall: no path
nav.setObstacles((function()
  local list = {}
  for y = -8400, 8400, 32 do list[#list + 1] = { x = 0, y = y, r = 48, hard = true } end
  return list
end)())
local none = nav.buildPath(-1000, 0, 1000, 0)
check("full wall returns no path", #none == 0, "n=" .. #none)

-- 4. tree mask vs ignoreTrees
nav.setObstacles({ { x = 0, y = 0, r = 200, hard = false } })
check("tree blocks traversable", not nav.isTraversable(0, 0))
local around = nav.buildPath(-600, 0, 600, 0, false)
check("path around trees exists", #around > 0, "n=" .. #around)
local through = nav.buildPath(-600, 0, 600, 0, true)
check("ignoreTrees allows short path", #through > 0 and #through <= #around, "#through=" .. #through .. " #around=" .. #around)

-- 5. performance
nav.setObstacles((function()
  local list = {}
  local rng = 12345
  local function rnd() rng = (rng * 1103515245 + 12345) % 2147483648; return rng / 2147483648 end
  for i = 1, 1500 do
    list[#list + 1] = { x = (rnd() - 0.5) * 7000, y = (rnd() - 0.5) * 7000, r = 34, hard = false }
  end
  return list
end)())
local t0 = os.clock()
local okCount = 0
for i = 1, 20000 do
  if nav.isTraversable((i % 400) * 20 - 4000, math.floor(i / 400) * 20 - 4000) then okCount = okCount + 1 end
end
local tIs = os.clock() - t0
t0 = os.clock()
local n1 = #nav.buildPath(-6000, -6000, 6000, 6000)
local tFar = os.clock() - t0
t0 = os.clock()
for i = 1, 10 do nav.buildPath(-2000 + i * 50, -1500, 1500, 1800) end
local tMid = (os.clock() - t0) / 10
print(string.format("perf: 20k isTraversable=%.1fms (%.2fus/call) longPath=%.1fms n=%d midPath=%.2fms",
  tIs * 1000, tIs * 1e6 / 20000, tFar * 1000, n1, tMid * 1000))
check("isTraversable fast enough", tIs < 1.0, string.format("%.3fs", tIs))
check("mid path fast enough", tMid < 0.05, string.format("%.3fs", tMid))

print(string.format("nav tests: %d checks, %d failed", checks, fails))
os.exit(fails == 0 and 0 or 1)